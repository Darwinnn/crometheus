require "./spec_helper"
require "../src/crometheus/summary"

describe Crometheus::Summary do
  describe "#observe" do
    it "changes the count and sum" do
      summary = Crometheus::Summary.new(:x, "", nil)
      summary.count.should eq 0.0
      summary.sum.should eq 0.0
      summary.observe 10
      summary.count.should eq 1.0
      summary.sum.should eq 10.0
      summary.observe 100.0
      summary.count.should eq 2.0
      summary.sum.should eq 110.0
      summary.observe -60.0
      summary.count.should eq 3.0
      summary.sum.should eq 50.0
    end
  end

  describe "#reset" do
    it "sets count and sum to zero" do
      summary = Crometheus::Summary.new(:x, "", nil)
      summary.observe 100
      summary.reset
      summary.count.should eq 0.0
      summary.sum.should eq 0.0
    end
  end

  describe "#measure_runtime" do
    it "yields and increases sum by the runtime of the block" do
      summary = Crometheus::Summary.new(:x, "", nil)
      summary.measure_runtime { sleep 0.1 }
      summary.count.should eq 1.0
      (0.05..0.15).should contain summary.sum
    end

    it "works even when the block raises an exception" do
      summary = Crometheus::Summary.new(:x, "", nil)
      expect_raises (CrometheusTestException) do
        summary.measure_runtime { sleep 0.3; raise CrometheusTestException.new }
      end
      summary.measure_runtime { sleep 0.1 }
      summary.count.should eq 2.0
      (0.35..0.45).should contain summary.sum
    end
  end

  describe "#samples" do
    it "yields appropriate Samples" do
      summary = Crometheus::Summary.new(:x, "", nil)
      summary.observe(0.1)
      summary.observe(0.3)
      get_samples(summary).should eq [
        Crometheus::Sample.new(suffix: "count", value: 2.0),
        Crometheus::Sample.new(suffix: "sum", value: 0.4),
      ]

      summary2 = Crometheus::Summary.new(:x, "", nil)
      summary2.observe(-20)
      get_samples(summary2).should eq [
        Crometheus::Sample.new(suffix: "count", value: 1.0),
        Crometheus::Sample.new(suffix: "sum", value: -20.0),
      ]
    end
  end

  describe ".valid_labels?" do
    it "disallows \"quantile\" as a label" do
      Crometheus::Summary.valid_label?(:quantile).should eq false
    end

    it "adheres to standard label restrictions" do
      Crometheus::Summary.valid_label?(:__reserved).should eq false
    end
  end
end
