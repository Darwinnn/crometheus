require "./spec_helper"
require "../src/crometheus/metric"

describe Crometheus::Metric do
  describe ".valid_labels?" do
    it "returns true on most hashes" do
      Crometheus::Metric.valid_label?(:foo).should eq true
      Crometheus::Metric.valid_label?(:_baz).should eq true
    end
    it "fails when a key starts with __" do
      Crometheus::Metric.valid_label?(:__reserved).should eq(false)
    end
    it "fails on reserved labels" do
      Crometheus::Metric.valid_label?(:job).should eq(false)
      Crometheus::Metric.valid_label?(:instance).should eq(false)
    end
    it "fails when labels don't match [a-zA-Z_][a-zA-Z0-9_]*" do
      Crometheus::Metric.valid_label?(:"foo*bar").should eq(false)
    end
  end
end
