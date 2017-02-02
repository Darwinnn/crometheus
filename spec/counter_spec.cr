require "./spec_helper"
require "../src/crometheus/counter"

describe Crometheus::Counter do
  counter = Crometheus::Counter.new

  it "defaults new counters to 0.0" do
    counter.get.should eq 0.0
  end

  describe "#inc" do
    it "increments the value" do
      counter.inc
      counter.get.should eq 1.0
      counter.inc 9.0
      counter.get.should eq 10.0
    end

    it "raises on negative numbers" do
      expect_raises(ArgumentError) {counter.inc -1.0}
    end
  end

  describe "#reset" do
    it "resets the value to zero" do
      counter.inc
      counter.reset
      counter.get.should eq 0.0
    end
  end

  describe "#count_exceptions" do
    it "increments when the block raises an exception" do
      counter.reset
      10.times do |ii|
        begin
          counter.count_exceptions {raise ArgumentError.new if ii % 2 == 0}
        rescue ex : ArgumentError
        end
      end
      counter.get.should eq 5.0
    end

    it "re-raises the exception" do
      expect_raises(ArgumentError) {counter.count_exceptions {raise ArgumentError.new}}
    end
  end

  describe ".count_exceptions_of_type" do
    it "increment when the block raises the given type of exception" do
      exceptions = [ArgumentError.new, KeyError.new, DivisionByZero.new,
        ArgumentError.new, ArgumentError.new]
      counter.reset
      exceptions.each do |ex|
        expect_raises do
          Crometheus::Counter.count_exceptions_of_type(counter, ArgumentError) {raise ex}
        end
      end
      counter.get.should eq 3.0
    end
  end

  describe "#samples" do
    it "returns an appropriate Array of Samples" do
      counter.reset
      counter.inc(10)
      counter.samples.should eq [Crometheus::Sample.new(value: 10.0)]
    end
  end

end
