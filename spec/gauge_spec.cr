require "./spec_helper"
require "../src/crometheus/gauge"

describe "Crometheus::Gauge" do
  describe "#set and #get" do
    it "sets and gets the metric value" do
      gauge = Crometheus::Gauge.new(:my_gauge1, "First gauge description")
      gauge.set(23)
      gauge.get.should eq(23.0)
      gauge.set(24.0f32)
      gauge.get.should eq(24.0)
      gauge.set(25.0)
      gauge.get.should eq(25.0)
    end
    
    it "sets and gets the metric value for a given label set" do
      gauge = Crometheus::Gauge.new(:my_gauge2, "Second gauge description")
      gauge.set({:mylabel => "foo"}, 25.0)
      gauge.get({:mylabel => "foo"}).should eq(25.0)
    end
    
    it "raises when getting an unset value" do
      gauge = Crometheus::Gauge.new(:my_gauge3, "Third gauge description")
      expect_raises do
        gauge.get
      end

      expect_raises do
        gauge.get({:mylabel => "unset"})
      end
    end
  end
  
  describe "#format" do
    it "appends a self-summary to the passed IO object" do
      gauge = Crometheus::Gauge.new(:my_gaugen, "Nth gauge description")
      gauge.set(10.0)
      gauge.set({:mylabel => "foo"}, 3.14e+42)
      gauge.set({:mylabel => "bar", :otherlabel => "baz"}, -1.23e-45)
      String.build {|ss| ss << gauge.format}.should eq %<\
# TYPE my_gaugen gauge
# HELP my_gaugen Nth gauge description
my_gaugen 10.0
my_gaugen{mylabel="foo"} 3.14e+42
my_gaugen{mylabel="bar", otherlabel="baz"} -1.23e-45
>
    end
  end
end
