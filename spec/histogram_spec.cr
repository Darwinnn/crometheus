require "./spec_helper"
require "../src/crometheus/histogram"

describe Crometheus::Histogram do
  describe ".new" do
    it "allows buckets to be set by default" do
      histogram = Crometheus::Histogram.new(:x, "", nil).buckets.keys.should eq([
        0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0,
        Float64::INFINITY
      ])
    end

    it "allows buckets to be set explicitly" do
      Crometheus::Histogram.new(:x, "", nil,
        buckets: [0.1, 0.25, 0.5, 1.0]
      ).buckets.keys.should eq([0.1, 0.25, 0.5, 1.0, Float64::INFINITY])
    end
  end

  describe "#linear_buckets" do
    it "creates linearly increasing buckets" do
      histogram = Crometheus::Histogram.new(:x, "", nil,
        buckets: Crometheus::Histogram.linear_buckets(1, 2, 5)
      ).buckets.keys.should eq [
        1.0, 3.0, 5.0, 7.0, 9.0, Float64::INFINITY]

      histogram = Crometheus::Histogram.new(:x, "", nil,
        buckets: Crometheus::Histogram.linear_buckets(-20, 10, 4)
      ).buckets.keys.should eq [
        -20.0, -10.0, 0.0, 10.0, Float64::INFINITY]
    end
  end

  describe "#geometric_buckets" do
    it "returns a geometrically increasing Array of Float64s" do
      histogram = Crometheus::Histogram.new(:x, "", nil,
        buckets: Crometheus::Histogram.geometric_buckets(1, 2, 4)
      ).buckets.keys.should eq [
        1.0, 2.0, 4.0, 8.0, Float64::INFINITY]

      histogram = Crometheus::Histogram.new(:x, "", nil,
        buckets: Crometheus::Histogram.geometric_buckets(2, 1.5, 5)
      ).buckets.keys.should eq [
        2.0, 3.0, 4.5, 6.75, 10.125, Float64::INFINITY]
    end
  end

  describe "#observe" do
    it "updates @count, @sum, and the appropriate buckets" do
      histogram = Crometheus::Histogram.new(:x, "", nil,
        buckets: [1.0, 2.0, 7.0, 11.0])

      histogram.observe(7)
      histogram.count.should eq 1.0
      histogram.sum.should eq 7.0
      histogram.buckets.should eq({
        1.0 => 0.0,
        2.0 => 0.0,
        7.0 => 1.0,
        11.0 => 1.0,
        Float64::INFINITY => 1.0
      })
      histogram.observe(17.5)
      histogram.count.should eq 2.0
      histogram.sum.should eq 24.5
      histogram.buckets.should eq({
        1.0 => 0.0,
        2.0 => 0.0,
        7.0 => 1.0,
        11.0 => 1.0,
        Float64::INFINITY => 2.0
      })
    end
  end

  describe "#measure_runtime" do
    histogram = Crometheus::Histogram.new(:x, "", nil,
      buckets: [0.1, 0.25, 0.5, 1.0])
    it "yields, then observes the runtime of the block" do
      histogram.measure_runtime {sleep 0.2}
      histogram.buckets.should eq({
        0.100 => 0.0,
        0.250 => 1.0,
        0.500 => 1.0,
        1.000 => 1.0,
        Float64::INFINITY => 1.0
      })
      histogram.count.should eq 1.0
      (0.15..0.25).should contain histogram.sum

      histogram.measure_runtime {sleep 0.3}
      histogram.buckets.should eq({
        0.100 => 0.0,
        0.250 => 1.0,
        0.500 => 2.0,
        1.000 => 2.0,
        Float64::INFINITY => 2.0
      })
      histogram.count.should eq 2.0
      (0.45..0.55).should contain histogram.sum
    end

    it "works even when the block raises an exception" do
      expect_raises (CrometheusTestException) do
        histogram.measure_runtime {sleep 0.3; raise CrometheusTestException.new}
      end
      histogram.buckets.should eq({
        0.100 => 0.0,
        0.250 => 1.0,
        0.500 => 3.0,
        1.000 => 3.0,
        Float64::INFINITY => 3.0
      })
      histogram.count.should eq 3.0
      (0.75..0.85).should contain histogram.sum
    end
  end

  describe "#samples" do
    it "yields appropriate Samples" do
      histogram1 = Crometheus::Histogram.new(:x, "", nil,
        buckets: [0.1, 0.25, 0.5, 1.0])
      histogram1.observe(0.11)
      histogram1.observe(0.22)
      histogram1.observe(0.33)
      histogram1.observe(0.44)

      expected = [
        Crometheus::Sample.new(4.0, suffix: "count"),
        Crometheus::Sample.new(1.1, suffix: "sum"),
        Crometheus::Sample.new(0.0, labels: {:le => "0.1"}, suffix: "bucket"),
        Crometheus::Sample.new(2.0, labels: {:le => "0.25"}, suffix: "bucket"),
        Crometheus::Sample.new(4.0, labels: {:le => "0.5"}, suffix: "bucket"),
        Crometheus::Sample.new(4.0, labels: {:le => "1.0"}, suffix: "bucket"),
        Crometheus::Sample.new(4.0, labels: {:le => "+Inf"}, suffix: "bucket")
      ]
      get_samples(histogram1).size.should eq expected.size
      get_samples(histogram1).zip(expected).each do |actual, expected|
        actual.should eq expected
      end

      histogram2 = Crometheus::Histogram.new(:x, "", nil,
        buckets: [1.0, 2.0, 7.0, 11.0])
      histogram2.observe(7)
      histogram2.observe(17.5)

      expected = [
        Crometheus::Sample.new(2.0, suffix: "count"),
        Crometheus::Sample.new(24.5, suffix: "sum"),
        Crometheus::Sample.new(0.0, labels: {:le => "1.0"}, suffix: "bucket"),
        Crometheus::Sample.new(0.0, labels: {:le => "2.0"}, suffix: "bucket"),
        Crometheus::Sample.new(1.0, labels: {:le => "7.0"}, suffix: "bucket"),
        Crometheus::Sample.new(1.0, labels: {:le => "11.0"}, suffix: "bucket"),
        Crometheus::Sample.new(2.0, labels: {:le => "+Inf"}, suffix: "bucket")
      ]
      get_samples(histogram2).size.should eq expected.size
      get_samples(histogram2).zip(expected).each do |actual, expected|
        actual.should eq expected
      end
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
