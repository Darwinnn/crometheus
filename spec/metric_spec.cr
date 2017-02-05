require "./spec_helper"
require "../src/crometheus/metric"

class Simple < Crometheus::Metric
  def samples(&block : Crometheus::Sample -> Nil) : Nil
    yield Crometheus::Sample.new(1.0)
  end

  def self.type
    Crometheus::Metric::Type::Untyped
  end
end

class LessSimple < Crometheus::Metric
  getter value : Float64
  def initialize(@name : Symbol,
                 @docstring : String,
                 @value : Float64,
                 register_with : Crometheus::Registry? = Crometheus.default_registry)
  end

  def samples(&block : Crometheus::Sample -> Nil) : Nil
    yield Crometheus::Sample.new(2.0)
  end

  def self.type
    Crometheus::Metric::Type::Untyped
  end
end

describe Crometheus::Metric do
  describe ".new" do
    it "automatically registers with the default registry" do
      simple = Simple.new(:a, "")
      Crometheus.default_registry.metrics.first.should eq simple
    end

    it "registers with a registry passed to the constructor" do
      registry = Crometheus::Registry.new
      simple = Simple.new(:b, "", registry)
      registry.metrics.should eq [simple]
      Crometheus.default_registry.metrics.should_not contain simple
    end

    it "rejects unacceptable names" do
      expect_raises(ArgumentError) {Simple.new(:"123", "")}
      expect_raises(ArgumentError) {Simple.new(:"a&b", "")}
    end
  end

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

  describe ".[]" do
    it "creates a LabeledMetric" do
      Simple[:foo, :bar].new(:x, "", nil).is_a?(
        Crometheus::Metric::LabeledMetric(
          NamedTuple(foo: String, bar: String),
          Simple,
        )).should eq true
    end
  end

  describe Crometheus::Metric::LabeledMetric do
    describe "#[]" do
      it "creates uniquely identified metrics" do
        simple = Simple[:foo, :bar].new(:x, "", nil)
        metric1 = simple[foo: "a", bar: "b"]
        metric1.class.should eq Simple
        metric1.should eq simple[foo: "a", bar: "b"]
        metric1.should_not eq simple[foo: "a", bar: "c"]
      end
    end

    describe "#get_labels" do
      it "returns an array of every labelset in use" do
        simple = Simple[:foo, :bar].new(:x, "", nil)
        simple.get_labels.should eq [] of NamedTuple(foo: String, bar: String)
        simple[foo: "a", bar: "b"]
        simple[foo: "x", bar: "y"]
        simple.get_labels.should eq [{foo: "a", bar: "b"}, {foo: "x", bar: "y"}]
      end
    end

    describe "#samples" do
      it "yields a sample for every labelset" do
        simple = Simple[:foo, :bar].new(:x, "", nil)
        get_samples(simple).should eq [] of Crometheus::Sample
        simple[foo: "a", bar: "b"]
        simple[foo: "x", bar: "y"]
        get_samples(simple).should eq [
          Crometheus::Sample.new(1.0, labels: {:foo => "a", :bar => "b"}),
          Crometheus::Sample.new(1.0, labels: {:foo => "x", :bar => "y"}),
        ]
      end
    end

    describe "#remove" do
      it "deletes the metric with the given labelset" do
        simple = Simple[:foo, :bar].new(:x, "", nil)
        simple[foo: "a", bar: "b"]
        simple[foo: "x", bar: "y"]
        simple.remove(foo: "a", bar: "b")
        simple.get_labels.should eq [{foo: "x", bar: "y"}]
        get_samples(simple).should eq [
          Crometheus::Sample.new(1.0, labels: {:foo => "x", :bar => "y"}),
        ]
      end
    end

    describe "#clear" do
      it "deletes all metrics" do
        simple = Simple[:foo, :bar].new(:x, "", nil)
        simple[foo: "a", bar: "b"]
        simple[foo: "x", bar: "y"]
        simple.clear
        simple.get_labels.should eq [] of NamedTuple(foo: String, bar: String)
        get_samples(simple).should eq [] of Crometheus::Sample
      end
    end

    it "passes unknown kwargs to Metric objects" do
      less_simple1 = LessSimple[:foo].new(:x, "", nil, value: 12.0)
      less_simple1[foo: "x"].value.should eq 12.0

      less_simple2 = LessSimple[:foo].new(:x, "", value: 13.0)
      less_simple2[foo: "x"].value.should eq 13.0
    end
  end
end
