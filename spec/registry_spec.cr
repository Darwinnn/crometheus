require "./spec_helper"
require "../src/crometheus/registry"
require "../src/crometheus/collector"

describe Crometheus::Registry do
  registry = Crometheus::Registry.new
  collector1 = Crometheus::Collector(Crometheus::Metric).new(:metric1, "docstring1", nil)
  collector2 = Crometheus::Collector(Crometheus::Metric).new(:metric2, "docstring2", nil)

  describe "#register" do
    it "ingests collectors passed to it" do
      registry.register(collector1)
      registry.register(collector2)
      registry.collectors.should eq [collector1, collector2]
    end

    it "enforces unique collector names" do
      collector_dupe = Crometheus::Collector(Crometheus::Metric).new(:metric2, "docstring3", nil)
      expect_raises {registry.register(collector_dupe)}
    end
  end

  describe "#forget" do
    it "deletes collectors from the registry" do
      registry.forget(collector1)
      registry.collectors.should eq [collector2]
    end
  end

  registry.register(collector1)

  describe "#start_server and #stop_server" do
    it "serves metrics on the specified port" do
      registry.start_server
      sleep 1
      response = HTTP::Client.get "http://localhost:9027/metrics"
      response.status_code.should eq 200
      response.body.should eq %<\
# HELP metric1 docstring1
# TYPE metric1 untyped
metric1 0.0
# HELP metric2 docstring2
# TYPE metric2 untyped
metric2 0.0
>
    end

    it "stops serving" do
      registry.stop_server
      expect_raises(Errno) do
        HTTP::Client.get "http://localhost:9027/metrics"
      end
    end

    it "allows host/port configuration" do
      registry.host = "127.0.0.55"
      registry.port = 99009
      registry.start_server
      sleep 1
      response = HTTP::Client.get "http://127.0.0.55:99009/metrics"
      response.status_code.should eq 200
      response.body.should eq %<\
# HELP metric1 docstring1
# TYPE metric1 untyped
metric1 0.0
# HELP metric2 docstring2
# TYPE metric2 untyped
metric2 0.0
>
    end
    registry.stop_server
  end
end
