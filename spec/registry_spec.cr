require "./spec_helper"
require "../src/crometheus/registry"
require "../src/crometheus/gauge"
require "../src/crometheus/counter"
require "../src/crometheus/histogram"
require "../src/crometheus/summary"

describe Crometheus::Registry do
  describe "#initialize" do
    it "adds standard exports by default" do
      {% if flag?(:linux) %}
        Crometheus::Registry.new.metrics.map { |mm| {mm.class, mm.name} }.should eq([
          {Crometheus::StandardExports::ProcFSExports, :process},
        ])
      {% else %}
        Crometheus::Registry.new.metrics.map { |mm| {mm.class, mm.name} }.should eq([
          {Crometheus::StandardExports, :process},
        ])
      {% end %}
    end

    it "can be created without standard exports" do
      Crometheus::Registry.new(false).metrics.should eq [] of Crometheus::Metric
    end
  end

  describe "#register" do
    it "ingests metrics passed to it" do
      registry = Crometheus::Registry.new(false)
      gauge1 = Crometheus::Gauge.new(:a, "", nil)
      gauge2 = Crometheus::Gauge.new(:b, "", nil)
      registry.register gauge1
      registry.register gauge2
      registry.metrics.should eq [gauge1, gauge2]
    end

    it "enforces unique metric names" do
      registry = Crometheus::Registry.new(false)
      gauge1 = Crometheus::Gauge.new(:a, "", nil)
      gauge2 = Crometheus::Gauge.new(:a, "", nil)
      registry.register gauge1
      expect_raises(ArgumentError) { registry.register gauge2 }
    end
  end

  describe "#unregister" do
    it "deletes metrics from the registry" do
      registry = Crometheus::Registry.new(false)
      gauge1 = Crometheus::Gauge.new(:a, "", nil)
      gauge2 = Crometheus::Gauge.new(:b, "", nil)
      registry.register gauge1
      registry.register gauge2
      registry.unregister gauge1
      registry.metrics.should eq [gauge2]
    end
  end

  describe "#start_server and #stop_server" do
    registry = Crometheus::Registry.new(false)
    registry.namespace = "spec"

    gauge1 = Crometheus::Gauge[:test].new(:gauge1, "docstring1", registry)
    gauge2 = Crometheus::Gauge.new(:gauge2, "docstring2", registry)

    counter = Crometheus::Counter[:test,
      :label1, :label2, :label3, :label4, :label5, :label6, :label7,
      :label8, :label9, :label10,
    ].new(:counter1, "docstring3", registry)
    counter[test: "many labels", label1: "one", label2: "two",
      label3: "three", label4: "four", label5: "five", label6: "six",
      label7: "seven", label8: "eight", label9: "nine", label10: "ten",
    ].inc(1.2345)

    gauge1[test: "infinity"].set(Float64::INFINITY)
    gauge1[test: "-infinity"].set(-Float64::INFINITY)
    gauge1[test: "nan"].set(-Float64::NAN)
    gauge1[test: "large"].set(9.876e54)
    gauge1[test: "unicode (ﾉ◕ヮ◕)ﾉ*:･ﾟ✧"].set(42)

    histogram = Crometheus::Histogram.new(:histogram1, "docstring4", registry, buckets: [1.0, 2.0, 3.0])
    histogram.observe(1.5)

    summary = Crometheus::Summary.new(:summary1, "docstring5", registry)
    summary.observe(100.0)

    registry.start_server.should eq true
    sleep 0.5

    response = HTTP::Client.get "http://localhost:5000/metrics"
    response.status_code.should eq 200
    expected_response = %<\
# HELP spec_counter1 docstring3
# TYPE spec_counter1 counter
spec_counter1{test="many labels", label1="one", label2="two", label3="three", \
label4="four", label5="five", label6="six", label7="seven", label8="eight", \
label9="nine", label10="ten"} 1.2345
# HELP spec_gauge1 docstring1
# TYPE spec_gauge1 gauge
spec_gauge1{test="infinity"} +Inf
spec_gauge1{test="-infinity"} -Inf
spec_gauge1{test="nan"} NaN
spec_gauge1{test="large"} 9.876e+54
spec_gauge1{test="unicode (ﾉ◕ヮ◕)ﾉ*:･ﾟ✧"} 42.0
# HELP spec_gauge2 docstring2
# TYPE spec_gauge2 gauge
spec_gauge2 0.0
# HELP spec_histogram1 docstring4
# TYPE spec_histogram1 histogram
spec_histogram1_count 1.0
spec_histogram1_sum 1.5
spec_histogram1_bucket{le="1.0"} 0.0
spec_histogram1_bucket{le="2.0"} 1.0
spec_histogram1_bucket{le="3.0"} 1.0
spec_histogram1_bucket{le="+Inf"} 1.0
# HELP spec_summary1 docstring5
# TYPE spec_summary1 summary
spec_summary1_count 1.0
spec_summary1_sum 100.0
>
    it "serves metrics in Prometheus text exposition format v0.0.4" do
      response.body.each_line.zip(expected_response.each_line).each do |a, b|
        a.should eq b
      end
      response.body.should eq expected_response
    end

    it "stops serving" do
      registry.stop_server.should eq true
      expect_raises(IO::Error) do
        HTTP::Client.get "http://localhost:5000/metrics"
      end
    end

    it "allows host/port/path configuration" do
      registry.host = "localhost"
      registry.port = 19009
      registry.path = "/xyz"
      registry.start_server.should eq true
      sleep 0.5

      response = HTTP::Client.get "http://localhost:19009/"
      response.status_code.should eq 404
      response = HTTP::Client.get "http://localhost:19009/xyz"
      response.status_code.should eq 200
      response.body.lines.should eq expected_response.lines

      registry.stop_server
      registry.path = /a.?b/
      registry.start_server.should eq true
      sleep 0.5

      response = HTTP::Client.get "http://localhost:19009/cba"
      response.status_code.should eq 404
      response = HTTP::Client.get "http://localhost:19009/123abcdef"
      response.status_code.should eq 200
      response.body.lines.should eq expected_response.lines
      response = HTTP::Client.get "http://localhost:19009/x/a/b/c"
      response.status_code.should eq 200
      response.body.lines.should eq expected_response.lines

      registry.stop_server.should eq true
    end

    it "prefixes metrics with namespace" do
      registry2 = Crometheus::Registry.new(false)
      Crometheus::Gauge.new(:my_gauge, "docstring", registry2).set 15.0
      registry2.namespace = ""
      registry2.start_server.should eq true
      sleep 0.2
      HTTP::Client.get("http://localhost:5000/metrics").body.should eq %<\
# HELP my_gauge docstring
# TYPE my_gauge gauge
my_gauge 15.0
>
      registry2.namespace = "ns"
      HTTP::Client.get("http://localhost:5000/metrics").body.should eq %<\
# HELP ns_my_gauge docstring
# TYPE ns_my_gauge gauge
ns_my_gauge 15.0
>
      registry2.stop_server
    end
  end

  describe "#get_handler" do
    it "returns an HTTP handler" do
      Crometheus::Registry.new(false).get_handler.should be_a HTTP::Handler
    end
  end

  describe "#namespace=" do
    it "rejects improper names" do
      registry = Crometheus::Registry.new(false)
      expect_raises(ArgumentError) { registry.namespace = "*" }
      expect_raises(ArgumentError) { registry.namespace = "a$b" }
    end
  end
end
