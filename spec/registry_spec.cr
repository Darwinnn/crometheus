require "./spec_helper"
require "../src/crometheus/registry"
require "../src/crometheus/collector"
require "../src/crometheus/gauge"
require "../src/crometheus/counter"

describe Crometheus::Registry do
  registry = Crometheus::Registry.new
  gauge1 = Crometheus::Collector(Crometheus::Gauge).new(:gauge1, "docstring1", nil)
  gauge2 = Crometheus::Collector(Crometheus::Gauge).new(:gauge2, "docstring2", nil)

  describe "#register" do
    it "ingests collectors passed to it" do
      registry.register(gauge1)
      registry.register(gauge2)
      registry.collectors.should eq [gauge1, gauge2]
    end

    it "enforces unique collector names" do
      gauge_dupe = Crometheus::Collector(Crometheus::Metric).new(:gauge2, "docstring3", nil)
      expect_raises {registry.register(gauge_dupe)}
    end
  end

  describe "#unregister" do
    it "deletes collectors from the registry" do
      registry.unregister(gauge1)
      registry.collectors.should eq [gauge2]
    end
  end

  registry.register(gauge1)

  describe "#start_server and #stop_server" do
    registry.start_server
    sleep 0.5

    counter = Crometheus::Collector(Crometheus::Counter).new(:counter1, "docstring3", registry)
    counter.inc(1.2345)
    counter.labels(test: "many labels", label1: "one", label2: "two",
      label3: "three", label4: "four", label5: "five", label6: "six",
      label7: "seven", label8: "eight", label9: "nine", label10: "ten",
    ).inc

    gauge1.labels(test: "infinity").set(Float64::INFINITY)
    gauge1.labels(test: "-infinity").set(-Float64::INFINITY)
    gauge1.labels(test: "nan").set(-Float64::NAN)
    gauge1.labels(test: "large").set(9.876e54)
    gauge1.labels(test: "unicode", face: "(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧").set(42)

    histogram = Crometheus::Collector(Crometheus::Histogram).new(:histogram1, "docstring4", registry, buckets: [1.0, 2.0, 3.0])
    histogram.observe(1.5)

    summary = Crometheus::Collector(Crometheus::Summary).new(:summary1, "docstring5", registry)
    summary.observe(100.0)

    response = HTTP::Client.get "http://localhost:5000/metrics"
    response.status_code.should eq 200
    expected_response = %<\
# HELP counter1 docstring3
# TYPE counter1 counter
counter1 1.2345
counter1{test="many labels", label1="one", label2="two", label3="three", \
label4="four", label5="five", label6="six", label7="seven", label8="eight", \
label9="nine", label10="ten"} 1.0
# HELP gauge1 docstring1
# TYPE gauge1 gauge
gauge1{test="infinity"} +Inf
gauge1{test="-infinity"} -Inf
gauge1{test="nan"} NaN
gauge1{test="large"} 9.876e+54
gauge1{test="unicode", face="(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧"} 42.0
# HELP gauge2 docstring2
# TYPE gauge2 gauge
# HELP histogram1 docstring4
# TYPE histogram1 histogram
histogram1_count 1.0
histogram1_sum 1.5
histogram1_bucket{le="1.0"} 0.0
histogram1_bucket{le="2.0"} 1.0
histogram1_bucket{le="3.0"} 1.0
histogram1_bucket{le="+Inf"} 1.0
# HELP summary1 docstring5
# TYPE summary1 summary
summary1_count 1.0
summary1_sum 100.0
>
    it "serves metrics in Prometheus text exposition format v0.0.4" do
      response.body.each_line.zip(expected_response.each_line).each do |a,b|
        a.should eq b
      end
      response.body.should eq expected_response
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
      sleep 0.5
      response = HTTP::Client.get "http://127.0.0.55:99009/metrics"
      response.status_code.should eq 200
      response.body.each_line.zip(expected_response.each_line).each do |a,b|
        a.should eq b
      end
      registry.stop_server
    end
  end
end
