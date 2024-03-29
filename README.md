[![Build Status](https://travis-ci.org/Darwinnn/crometheus.svg?branch=master)](https://travis-ci.org/Darwinnn/crometheus)
# crometheus

This a github fork of ezrast's [Crometheus](https://gitlab.com/ezrast/crometheus) with patches that allow it to work with the latest Crystal version (1.4 for now)

[Crometheus](https://gitlab.com/ezrast/crometheus) is a [Prometheus](https://prometheus.io/) client library for instrumenting programs written in the [Crystal programming language](https://crystal-lang.org/).
For the most part, Crometheus assumes a basic familiarity with Prometheus.
To that end, readers may wish to skim the official documentation on Prometheus' [data model](https://prometheus.io/docs/concepts/data_model/), [metric types](https://prometheus.io/docs/concepts/metric_types/), and [text exposition format](https://prometheus.io/docs/instrumenting/exposition_formats/#text-format-details).

Crometheus is in early development and comes with no guarantees. This project is not affiliated with or endorsed by Prometheus.

For latest updates, see [CHANGELOG.md](CHANGELOG.md).

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  crometheus:
    github: darwinnn/crometheus
    branch: master
```

## Usage

```crystal
require "crometheus"

# Create an unlabeled summary.
summary = Crometheus::Summary.new(
  :my_first_summary,
  "A sample summary metric")

# Observe some values.
summary.observe 100
summary.observe 200.0

# Create a gauge with labels "foo" and "bar".
gauge = Crometheus::Gauge[:foo, :bar].new(
  :my_first_gauge,
  "A sample gauge metric, with labels")

# In some cases the above syntax will cause type inference to fail;
# work around it with the `Crometheus.alias` macro like this.
Crometheus.alias WidgetCounter = Crometheus::Counter[:kind]
widget_counter = WidgetCounter.new(
  :widgets_made,
  "Number of widgets produced")

# Set some values.
gauge[foo: "Hello", bar: "Anthony"].set 3.14159
gauge[foo: "Goodbye", bar: "Clarice"].set -8e12
widget_counter[kind: "sprocket"].inc
7.times{ widget_counter[kind: "pinion"].inc }

# Access the default registry and start up the server.
Crometheus.default_registry.run_server
```
Then visit [http://localhost:5000](http://localhost:5000) to see your
metrics (you may see some default process metrics as well):
```text
# HELP my_first_gauge A sample gauge metric, with labels
# TYPE my_first_gauge gauge
my_first_gauge{foo="Hello", bar="Anthony"} 3.14159
my_first_gauge{foo="Goodbye", bar="Clarice"} -8000000000000.0
# HELP my_first_summary A sample summary metric
# TYPE my_first_summary summary
my_first_summary_count 2.0
my_first_summary_sum 300.0
# HELP widgets_made Number of widgets produced
# TYPE widgets_made counter
widgets_made{kind="sprocket"} 1.0
widgets_made{kind="pinion"} 7.0
```

The above is all the setup you need for straightforward use cases; all that's left is creating real metrics and instrumenting your code.
See the reference documentation for the [Gauge](https://ezrast.gitlab.io/crometheus/Crometheus/Gauge.html), [Counter](https://ezrast.gitlab.io/crometheus/Crometheus/Counter.html), [Histogram](https://ezrast.gitlab.io/crometheus/Crometheus/Histogram.html), and [Summary](https://ezrast.gitlab.io/crometheus/Crometheus/Summary.html) classes to learn more about the available metric types.
The bracket notation `Gauge[:foo, :bar]` in the example above is a bit of macro magic that creates a [LabeledMetric](https://ezrast.gitlab.io/crometheus/Crometheus/Metric/LabeledMetric.html) with `Gauge` as a type parameter.
See the `examples` directory for more samples.

For server configuration see the [Registry](https://ezrast.gitlab.io/crometheus/Crometheus/Registry.html) class documentation.
If you want to use multiple registries, e.g. to expose two different sets of metrics on different ports, you'll need to instantiate a second Registry object (other than the default) and pass it as a third argument to your metric constructors (after the name and docstring).

If you want to define a custom metric type, see the documentation for the [Metric](https://ezrast.gitlab.io/crometheus/Crometheus/Metric.html) class, and inherit from that.

Alternately, you can just dive into the [API Documentation](https://ezrast.gitlab.io/crometheus) right from the top.

## Contributing

1. Fork it
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Merge Request

## Author

- [Ezra Stevens](https://gitlab.com/ezrast) - original author
- [Darwin](https://github.com/darwinnn) - github fork and patches for Crystal 0.34.0

