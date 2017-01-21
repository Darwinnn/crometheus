require "./spec_helper"
require "../src/crometheus/collector"
require "../src/crometheus/gauge"

describe "Crometheus::Collector(Crometheus::Gauge)" do
  gauge = Crometheus::Collector(Crometheus::Gauge).new(:my_gauge1, "First gauge description")

  it "defaults new gauges to 0.0" do
    gauge.get.should eq 0.0
    gauge.labels(mylabel: "foo").get.should eq 0.0
  end

  describe "#set and #get" do
    it "sets and gets the metric value" do
      gauge.set(23)
      gauge.get.should eq(23.0)
      gauge.set(24.0f32)
      gauge.get.should eq(24.0)
      gauge.set(25.0)
      gauge.get.should eq(25.0)
    end
  end

  describe "#labels" do
    it "sets and gets the metric value for a given label set" do
      gauge.set 20.0
      gauge.labels(mylabel: "foo").set 25.0
      gauge.labels(mylabel: "bar").set 30.0
      gauge.get.should eq 20.0
      gauge.labels(mylabel: "foo").get.should eq 25.0
      gauge.labels(mylabel: "bar").get.should eq 30.0
    end
  end

  describe "#inc" do
    it "increments the value" do
      gauge.set 20.0
      gauge.inc
      gauge.get.should eq 21.0
      gauge.inc 9.0
      gauge.get.should eq 30.0
    end
  end

  describe "#dec" do
    it "decrements the value" do
      gauge.set 20.0
      gauge.dec
      gauge.get.should eq 19.0
      gauge.dec 4.0
      gauge.get.should eq 15.0
    end
  end

  describe "#set_to_current_time" do
    it "sets the gauge to the current UNIX timestamp" do
      gauge.set_to_current_time
      (1484901416..4102444800).should contain gauge.get
    end
  end

  describe "#measure_runtime" do
    it "sets the gauge to the runtime of a block" do
      gauge.measure_runtime {sleep 0.4}
      (0.4..0.45).should contain gauge.get
    end

    it "works even when exceptions are raised" do
      gauge.set 0.0
      expect_raises(CrometheusTestException) do
        gauge.measure_runtime {sleep 0.2; raise CrometheusTestException.new}
      end
      (0.2..0.25).should contain gauge.get

    end
  end

  describe "#count_concurrent" do
    it "increases the gauge while a block is running" do
      counted_sleep = ->(duration : Float64){
        gauge.count_concurrent {sleep duration}
      }

      gauge.set 0.0
      [0.2, 0.4, 0.6].each {|duration| spawn {counted_sleep.call duration}}
      sleep 0.1
      gauge.get.should eq 3.0
      sleep 0.2
      gauge.get.should eq 2.0
      sleep 0.2
      gauge.get.should eq 1.0
      sleep 0.2
      gauge.get.should eq 0.0
    end

    it "works when exceptions are raised" do
      gauge.set 0.0
      spawn do
        begin
          gauge.count_concurrent {sleep 0.2; raise CrometheusTestException.new}
        rescue ex : CrometheusTestException
        end
      end
      sleep 0.1
      gauge.get.should eq 1.0
      sleep 0.2
      gauge.get.should eq 0.0

    end
  end

  describe "#to_s" do
    it "appends a self-summary to the passed IO object" do
      gauge = Crometheus::Collector(Crometheus::Gauge).new(:my_gaugen, "Nth gauge description")
      gauge.set(10.0)
      gauge.labels(mylabel: "foo").set 3.14e+42
      gauge.labels(mylabel: "bar", otherlabel: "baz").set -1.23e-45
      gauge.to_s.should eq %<\
# HELP my_gaugen Nth gauge description
# TYPE my_gaugen gauge
my_gaugen 10.0
my_gaugen{mylabel="foo"} 3.14e+42
my_gaugen{mylabel="bar", otherlabel="baz"} -1.23e-45
>
    end
  end
end
