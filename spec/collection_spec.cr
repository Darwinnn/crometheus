require "./spec_helper"
require "../src/crometheus/collection"

# Most of Collection's functionality only makes sense when used with a
# less abstract metric type than Metric (which is always 0.0). See
# gauge_spec.cr for a more thorough test suite.
describe Crometheus::Collection(Crometheus::Metric) do
  it "automatically registers with the default registry" do
    collection = Crometheus::Collection(Crometheus::Metric).new(:foo, "bar")
    Crometheus.registry.collections.first.should eq collection
  end

  it "registers with a registry passed to the constructor" do
    registry = Crometheus::Registry.new
    collection = Crometheus::Collection(Crometheus::Metric).new(:baz, "quux", registry)
    registry.collections.first.should eq collection
    Crometheus.registry.collections.should_not contain collection
  end
end
