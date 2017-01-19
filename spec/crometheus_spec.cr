require "./spec_helper"
require "../src/crometheus"

describe Crometheus do
  describe ".valid_labels?" do
    it "returns true on most hashes" do
      Crometheus.valid_labels?(
        {:foo => "bar", :_baz => "___..Quux"}).should eq(true)
    end
    it "fails when a key starts with __" do
      Crometheus.valid_labels?({:__reserved => "str"}).should eq(false)
    end
    it "fails on reserved labels" do
      Crometheus.valid_labels?({:job => "str"}).should eq(false)
      Crometheus.valid_labels?({:instance => "str"}).should eq(false)
    end
    it "fails when labels don't match [a-zA-Z_][a-zA-Z0-9_]*" do
      Crometheus.valid_labels?({:"foo*bar" => "str"}).should eq(false)
    end
  end
end
