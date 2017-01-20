require "./spec_helper"
require "../src/crometheus/collector"
require "../src/crometheus/counter"

describe Crometheus::Collector(Crometheus::Counter) do
  counter = Crometheus::Collector(Crometheus::Counter).new(:counter1, "A Counter Description")

  it "defaults new counters to 0.0" do
    counter.get.should eq 0.0
    counter.labels(mylabel: "foo").get.should eq 0.0
  end

  describe "#inc" do
    it "increments the value" do
      counter.inc
      counter.get.should eq 1.0
      counter.inc 9.0
      counter.get.should eq 10.0
    end
  end

  describe "#reset" do
    it "resets the value to zero" do
      counter.inc
      counter.reset
      counter.get.should eq 0.0
    end
  end

end
