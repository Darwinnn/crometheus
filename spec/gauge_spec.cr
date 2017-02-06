require "./spec_helper"
require "../src/crometheus/gauge"

describe Crometheus::Gauge do
  it "defaults new gauges to 0.0" do
    Crometheus::Gauge.new(:x, "", nil).get.should eq 0.0
  end

  describe "#set and #get" do
    it "sets and gets the metric value" do
      gauge = Crometheus::Gauge.new(:x, "", nil)
      gauge.set(23)
      gauge.get.should eq(23.0)
      gauge.set(24.0f32)
      gauge.get.should eq(24.0)
      gauge.set(25.0)
      gauge.get.should eq(25.0)
    end
  end

  describe "#inc" do
    it "increments the value" do
      gauge = Crometheus::Gauge.new(:x, "", nil)
      gauge.set 20.0
      gauge.inc
      gauge.get.should eq 21.0
      gauge.inc 9.0
      gauge.get.should eq 30.0
    end
  end

  describe "#dec" do
    it "decrements the value" do
      gauge = Crometheus::Gauge.new(:x, "", nil)
      gauge.set 20.0
      gauge.dec
      gauge.get.should eq 19.0
      gauge.dec 4.0
      gauge.get.should eq 15.0
    end
  end

  describe "#set_to_current_time" do
    it "sets the gauge to the current UNIX timestamp" do
      gauge = Crometheus::Gauge.new(:x, "", nil)
      gauge.set_to_current_time
      (1484901416..4102444800).should contain gauge.get
    end
  end

  describe "#measure_runtime" do
    it "sets the gauge to the runtime of a block" do
      gauge = Crometheus::Gauge.new(:x, "", nil)
      gauge.measure_runtime {sleep 0.4}
      (0.35..0.45).should contain gauge.get
    end

    it "works even when exceptions are raised" do
      gauge = Crometheus::Gauge.new(:x, "", nil)
      gauge.set 0.0
      expect_raises(CrometheusTestException) do
        gauge.measure_runtime {sleep 0.2; raise CrometheusTestException.new}
      end
      (0.2..0.25).should contain gauge.get

    end
  end

  describe "#count_concurrent" do
    it "increases the gauge while a block is running" do
      gauge = Crometheus::Gauge.new(:x, "", nil)
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
      gauge = Crometheus::Gauge.new(:x, "", nil)
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

  describe "#samples" do
    it "yields appropriate Samples" do
      gauge = Crometheus::Gauge.new(:x, "", nil)
      gauge.set(11)
      get_samples(gauge).should eq [Crometheus::Sample.new(11.0)]
    end
  end
end
