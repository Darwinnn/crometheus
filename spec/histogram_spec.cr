require "./spec_helper"
require "../src/crometheus/histogram"

describe Crometheus::Histogram do
  histogram1 = Crometheus::Histogram.new(buckets: [0.1, 0.25, 0.5, 1.0])
  histogram2 = Crometheus::Histogram.new(
    labels: {:foo => "bar"},
    buckets: [1.0, 2.0, 7.0, 11.0]
  )

  describe ".new" do
    it "allows buckets to be set by default" do
      Crometheus::Histogram.new.buckets.keys.should eq([
        0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0,
        Float64::INFINITY])
    end

    it "allows buckets to be set explicitly" do
      Crometheus::Histogram.new(
        labels: {:foo => "bar"},
        buckets: [1.0, 2.0, 7.0, 11.0]
      ).buckets.keys.should eq([1.0, 2.0, 7.0, 11.0, Float64::INFINITY])
    end
  end

  describe "#linear_buckets" do
    it "returns a linearly increasing Array of Float64s" do
      Crometheus::Histogram.linear_buckets(1, 2, 5).should eq [
        1.0, 3.0, 5.0, 7.0, Float64::INFINITY]
      Crometheus::Histogram.linear_buckets(-20, 10, 4).should eq [
        -20.0, -10.0, 0.0, Float64::INFINITY]
    end
  end

  describe "#geometric_buckets" do
    it "returns a geometrically increasing Array of Float64s" do
      Crometheus::Histogram.geometric_buckets(1, 2, 4).should eq [
        1.0, 2.0, 4.0, Float64::INFINITY]
      Crometheus::Histogram.geometric_buckets(2, 1.5, 5).should eq [
        2.0, 3.0, 4.5, 6.75, Float64::INFINITY]
    end
  end

  describe "#observe" do
    it "updates @count, @sum, and the appropriate bucket" do
      histogram2.observe(7)
      histogram2.count.should eq 1.0
      histogram2.sum.should eq 7.0
      histogram2.buckets.should eq({
        1.0 => 0.0,
        2.0 => 0.0,
        7.0 => 1.0,
        11.0 => 1.0,
        Float64::INFINITY => 1.0
      })
      histogram2.observe(17.5)
      histogram2.count.should eq 2.0
      histogram2.sum.should eq 24.5
      histogram2.buckets.should eq({
        1.0 => 0.0,
        2.0 => 0.0,
        7.0 => 1.0,
        11.0 => 1.0,
        Float64::INFINITY => 2.0
      })
    end
  end

  describe "#measure_runtime" do
    it "yields, then observes the runtime of the block" do
      histogram1.reset
      histogram1.measure_runtime {sleep 0.2}
      histogram1.buckets.should eq({
        0.100 => 0.0,
        0.250 => 1.0,
        0.500 => 1.0,
        1.000 => 1.0,
        Float64::INFINITY => 1.0
      })
      histogram1.count.should eq 1.0
      (0.15..0.25).should contain histogram1.sum

      histogram1.measure_runtime {sleep 0.3}
      histogram1.buckets.should eq({
        0.100 => 0.0,
        0.250 => 1.0,
        0.500 => 2.0,
        1.000 => 2.0,
        Float64::INFINITY => 2.0
      })
      histogram1.count.should eq 2.0
      (0.45..0.55).should contain histogram1.sum
    end

    it "works even when the block raises an exception" do
      expect_raises (CrometheusTestException) do
        histogram1.measure_runtime {sleep 0.3; raise CrometheusTestException.new}
      end
      histogram1.buckets.should eq({
        0.100 => 0.0,
        0.250 => 1.0,
        0.500 => 3.0,
        1.000 => 3.0,
        Float64::INFINITY => 3.0
      })
      histogram1.count.should eq 3.0
      (0.75..0.85).should contain histogram1.sum
    end
  end

  describe "#samples" do
    it "yields appropriate Samples" do
      histogram1.reset
      histogram1.observe(0.01)
      histogram1.observe(0.11)
      histogram1.observe(0.21)
      histogram1.observe(0.31)

      expected = [
        Crometheus::Sample.new(suffix: "_count", value: 4.0),
        Crometheus::Sample.new(suffix: "_sum", value: 0.01 + 0.11 + 0.21 + 0.31), # not 0.64 due to FP error
        Crometheus::Sample.new(labels: {:le => "0.1"}, value: 1.0),
        Crometheus::Sample.new(labels: {:le => "0.25"}, value: 3.0),
        Crometheus::Sample.new(labels: {:le => "0.5"}, value: 4.0),
        Crometheus::Sample.new(labels: {:le => "1.0"}, value: 4.0),
        Crometheus::Sample.new(labels: {:le => "+Inf"}, value: 4.0)
      ]
      histogram1.samples.size.should eq expected.size
      histogram1.samples.zip(expected).each do |actual, expected|
        actual.should eq expected
      end

      histogram2.samples.should eq [
        Crometheus::Sample.new(suffix: "_count", labels: {:foo => "bar"}, value: 2.0),
        Crometheus::Sample.new(suffix: "_sum", labels: {:foo => "bar"}, value: 24.5),
        Crometheus::Sample.new(labels: {:foo => "bar", :le => "1.0"}, value: 0.0),
        Crometheus::Sample.new(labels: {:foo => "bar", :le => "2.0"}, value: 0.0),
        Crometheus::Sample.new(labels: {:foo => "bar", :le => "7.0"}, value: 1.0),
        Crometheus::Sample.new(labels: {:foo => "bar", :le => "11.0"}, value: 1.0),
        Crometheus::Sample.new(labels: {:foo => "bar", :le => "+Inf"}, value: 2.0)
      ]
    end
  end

  describe ".valid_label?" do
    it "disallows \"le\" as a label" do
      expect_raises(ArgumentError) do
        Crometheus::Histogram.new({:le => "x"})
      end
    end

    it "adheres to standard label restrictions" do
      expect_raises(ArgumentError) do
        Crometheus::Histogram.new({:"~" => "x"})
      end
    end
  end
end
