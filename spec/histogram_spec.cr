require "./spec_helper"
require "../src/crometheus/histogram"

describe Crometheus::Histogram do
  histogram1 = Crometheus::Histogram.new(buckets: [0.1, 0.25, 0.5, 1.0])
  histogram2 = Crometheus::Histogram.new(buckets: [1.0, 2.0, 7.0, 11.0])

  describe ".new" do
    it "allows buckets to be set by default" do
      Crometheus::Histogram.new.buckets.keys.should eq([
        0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0,
        Float64::INFINITY])
    end

    it "allows buckets to be set explicitly" do
      Crometheus::Histogram.new(
        buckets: [1.0, 2.0, 7.0, 11.0]
      ).buckets.keys.should eq([1.0, 2.0, 7.0, 11.0, Float64::INFINITY])
    end
  end

  describe "#linear_buckets" do
    it "returns a linearly increasing Array of Float64s" do
      Crometheus::Histogram.linear_buckets(1, 2, 5).should eq [
        1.0, 3.0, 5.0, 7.0, 9.0, Float64::INFINITY]
      Crometheus::Histogram.linear_buckets(-20, 10, 4).should eq [
        -20.0, -10.0, 0.0, 10.0, Float64::INFINITY]
    end
  end

  describe "#geometric_buckets" do
    it "returns a geometrically increasing Array of Float64s" do
      Crometheus::Histogram.geometric_buckets(1, 2, 4).should eq [
        1.0, 2.0, 4.0, 8.0, Float64::INFINITY]
      Crometheus::Histogram.geometric_buckets(2, 1.5, 5).should eq [
        2.0, 3.0, 4.5, 6.75, 10.125, Float64::INFINITY]
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
        Crometheus::Sample.new(4.0, suffix: "_count"),
        Crometheus::Sample.new(0.01 + 0.11 + 0.21 + 0.31, suffix: "_sum"), # not 0.64 due to FP error
        Crometheus::Sample.new(1.0, labels: {:le => "0.1"}, suffix: "_bucket"),
        Crometheus::Sample.new(3.0, labels: {:le => "0.25"}, suffix: "_bucket"),
        Crometheus::Sample.new(4.0, labels: {:le => "0.5"}, suffix: "_bucket"),
        Crometheus::Sample.new(4.0, labels: {:le => "1.0"}, suffix: "_bucket"),
        Crometheus::Sample.new(4.0, labels: {:le => "+Inf"}, suffix: "_bucket")
      ]
      histogram1.samples.size.should eq expected.size
      histogram1.samples.zip(expected).each do |actual, expected|
        actual.should eq expected
      end

      histogram2.samples.should eq [
        Crometheus::Sample.new(2.0, suffix: "_count"),
        Crometheus::Sample.new(24.5, suffix: "_sum"),
        Crometheus::Sample.new(0.0, labels: {:le => "1.0"}, suffix: "_bucket"),
        Crometheus::Sample.new(0.0, labels: {:le => "2.0"}, suffix: "_bucket"),
        Crometheus::Sample.new(1.0, labels: {:le => "7.0"}, suffix: "_bucket"),
        Crometheus::Sample.new(1.0, labels: {:le => "11.0"}, suffix: "_bucket"),
        Crometheus::Sample.new(2.0, labels: {:le => "+Inf"}, suffix: "_bucket")
      ]
    end
  end

  describe ".valid_label?" do
    it "disallows \"le\" as a label" do
      Crometheus::Histogram.valid_label?(:le).should eq false
    end

    it "adheres to standard label restrictions" do
      Crometheus::Histogram.valid_label?(:"~").should eq false
    end
  end
end
