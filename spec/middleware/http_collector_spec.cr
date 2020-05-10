require "http/server/context"
require "../spec_helper"
require "../../src/crometheus/middleware/http_collector"

Crometheus.default_registry(false)

def request(collector, method, resource, body : String? = nil)
  ctx = HTTP::Server::Context.new(
    HTTP::Request.new(method, resource, body: body),
    HTTP::Server::Response.new(IO::MultiWriter.new([] of IO))
  )
  collector.call(ctx)
  return ctx
end

describe Crometheus::Middleware::HttpCollector do
  it "tracks requests" do
    registry = Crometheus::Registry.new(false)
    collector = Crometheus::Middleware::HttpCollector.new(registry)
    request(collector, "GET", "/foo/bar/1")
    request(collector, "GET", "/foo/bar/2")
    request(collector, "POST", "/foo/bar/")
    request(collector, "GET", "/foo/quux")

    metric = registry.metrics.find { |mm|
      mm.name == :http_requests_total
    }.as(Crometheus::Middleware::HttpCollector::RequestCounter)
    metric[code: "404", method: "GET", path: "/foo/bar/:id"].get.should eq 2
    metric[code: "404", method: "POST", path: "/foo/bar/"].get.should eq 1
    metric[code: "404", method: "GET", path: "/foo/quux"].get.should eq 1
    metric.get_labels.size.should eq 3
  end

  it "tracks durations" do
    registry = Crometheus::Registry.new(false)
    collector = Crometheus::Middleware::HttpCollector.new(registry)
    x = 0.001
    collector.next = ->(ctx : HTTP::Server::Context) { sleep x; x += 0.02 }
    request(collector, "GET", "/one")
    request(collector, "GET", "/one")
    request(collector, "OPTIONS", "/two")
    request(collector, "OPTIONS", "/two")
    request(collector, "DELETE", "/123/456/three")
    request(collector, "GET", "/one")

    metric = registry.metrics.find { |mm|
      mm.name == :http_request_duration_seconds
    }.as(Crometheus::Middleware::HttpCollector::DurationHistogram)
    metric[method: "GET", path: "/one"].buckets.values.should eq [
      1.0, 1.0, 2.0, 2.0, 2.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0,
    ]
    metric[method: "OPTIONS", path: "/two"].buckets.values.should eq [
      0.0, 0.0, 0.0, 1.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0,
    ]
    metric[method: "DELETE", path: "/:id/:id/three"].buckets.values.should eq [
      0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
    ]
    metric.get_labels.size.should eq 3
  end

  it "tracks exceptions" do
    registry = Crometheus::Registry.new(false)
    collector = Crometheus::Middleware::HttpCollector.new(registry)
    collector.next = ->(ctx : HTTP::Server::Context) do
      str = ctx.request.body.as(IO).gets_to_end
      str[2]
      str.to_i
    end
    request(collector, "POST", "/", "123")
    request(collector, "POST", "/", "6") rescue IndexError
    request(collector, "POST", "/", "2") rescue IndexError
    request(collector, "POST", "/", "purple") rescue ArgumentError
    request(collector, "PUT", "/", "green") rescue ArgumentError
    request(collector, "PUT", "/", "gray") rescue ArgumentError

    metric = registry.metrics.find { |mm|
      mm.name == :http_request_exceptions_total
    }.as(Crometheus::Middleware::HttpCollector::ExceptionCounter)
    metric[method: "POST", path: "/", exception: "IndexError"].get.should eq 2
    metric[method: "POST", path: "/", exception: "ArgumentError"].get.should eq 1
    metric[method: "PUT", path: "/", exception: "ArgumentError"].get.should eq 2
    metric.get_labels.size.should eq 3
  end

  it "uses the default registry" do
    collector = Crometheus::Middleware::HttpCollector.new
    metrics = Crometheus.default_registry.metrics

    metrics.find { |mm|
      mm.name == :http_requests_total
    }.should be_a(Crometheus::Middleware::HttpCollector::RequestCounter)
    metrics.find { |mm|
      mm.name == :http_request_duration_seconds
    }.should be_a(Crometheus::Middleware::HttpCollector::DurationHistogram)
    metrics.find { |mm|
      mm.name == :http_request_exceptions_total
    }.should be_a(Crometheus::Middleware::HttpCollector::ExceptionCounter)
  end

  it "accepts a custom path cleaner" do
    registry = Crometheus::Registry.new(false)
    collector = Crometheus::Middleware::HttpCollector.new(
      registry,
      ->(path : String) { "~#{path}~" }
    )
    request(collector, "GET", "blah")

    metric = registry.metrics.find { |mm|
      mm.name == :http_requests_total
    }.as(Crometheus::Middleware::HttpCollector::RequestCounter)
    metric[code: "404", method: "GET", path: "~blah~"].get.should eq 1
  end

  it "accepts a nil path cleaner" do
    registry = Crometheus::Registry.new(false)
    collector = Crometheus::Middleware::HttpCollector.new(registry, nil)
    request(collector, "GET", "/blah/12")

    metric = registry.metrics.find { |mm|
      mm.name == :http_requests_total
    }.as(Crometheus::Middleware::HttpCollector::RequestCounter)
    metric[code: "404", method: "GET", path: "/blah/12"].get.should eq 1
  end
end
