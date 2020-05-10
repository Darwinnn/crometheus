require "./spec_helper"
require "../src/crometheus/counter"

describe Crometheus::Counter do
  it "defaults to 0.0" do
    counter = Crometheus::Counter.new(:x, "", nil)
    counter.get.should eq 0.0
  end

  describe "#inc" do
    it "increments the value" do
      counter = Crometheus::Counter.new(:x, "", nil)
      counter.inc
      counter.get.should eq 1.0
      counter.inc 9.0
      counter.get.should eq 10.0
    end

    it "raises on negative numbers" do
      expect_raises(ArgumentError) do
        Crometheus::Counter.new(:x, "", nil).inc -1.0
      end
    end
  end

  describe "#reset" do
    it "resets the value to zero" do
      counter = Crometheus::Counter.new(:x, "", nil)
      counter.inc
      counter.reset
      counter.get.should eq 0.0
    end
  end

  describe "#count_exceptions" do
    it "increments when the block raises an exception" do
      counter = Crometheus::Counter.new(:x, "", nil)
      10.times do |ii|
        begin
          counter.count_exceptions { raise CrometheusTestException.new if ii % 2 == 0 }
        rescue ex : CrometheusTestException
        end
      end
      counter.get.should eq 5.0
    end

    it "re-raises the exception" do
      expect_raises(CrometheusTestException) do
        Crometheus::Counter.new(:x, "", nil).count_exceptions {
          raise CrometheusTestException.new
        }
      end
    end
  end

  describe ".count_exceptions_of_type" do
    it "increment when the block raises the given type of exception" do
      counter = Crometheus::Counter.new(:x, "", nil)
      exceptions = [CrometheusTestException.new, KeyError.new, DivisionByZeroError.new,
                    CrometheusTestException.new, CrometheusTestException.new]
      exceptions.each do |ex|
        expect_raises(ex.class) do
          Crometheus::Counter.count_exceptions_of_type(counter, CrometheusTestException) { raise ex }
        end
      end
      counter.get.should eq 3.0
    end
  end

  describe "#samples" do
    it "returns an appropriate Array of Samples" do
      counter = Crometheus::Counter.new(:x, "", nil)
      counter.inc(10)
      get_samples(counter).should eq [Crometheus::Sample.new(10.0)]
    end
  end
end
