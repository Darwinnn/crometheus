# crometheus

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
    gitlab: ezrast/crometheus
    branch: master
```

## Usage

```crystal
require "crometheus/summary"
require "crometheus/gauge"

# Create an unlabeled summary.
summary = Crometheus::Summary.new(
  :my_first_summary,
  "A sample summary metric")

# Observe some values.
summary.observe 100
summary.observe 200.0

# Create a gauge, which will have labels "foo" and "bar".
gauge = Crometheus::Gauge[:foo, :bar].new(
  :my_first_gauge,
  "A sample gauge metric, with labels")

# Set some values.
gauge[foo: "Hello", bar: "Anthony"].set 3.14159
gauge[foo: "Goodbye", bar: "Clarice"].set -8e12

# Access the default registry and start up the server.
Crometheus.default_registry.run_server
```
Then visit [http://localhost:5000](http://localhost:5000) to see your metrics:
```text
# HELP my_first_gauge A sample gauge metric, with labels
# TYPE my_first_gauge gauge
my_first_gauge{foo="Hello", bar="Anthony"} 3.14159
my_first_gauge{foo="Goodbye", bar="Clarice"} -8000000000000.0
# HELP my_first_summary A sample summary metric
# TYPE my_first_summary summary
my_first_summary_count 2.0
my_first_summary_sum 300.0
```

The above is all the setup you need for straightforward use cases; all that's left is creating real metrics and instrumenting your code.
See the reference documentation for the [Gauge](https://ezrast.gitlab.io/crometheus/Crometheus/Gauge.html), [Counter](https://ezrast.gitlab.io/crometheus/Crometheus/Counter.html), [Histogram](https://ezrast.gitlab.io/crometheus/Crometheus/Histogram.html), and [Summary](https://ezrast.gitlab.io/crometheus/Crometheus/Summary.html) classes to learn more about the available metric types.
The bracket notation `Gauge[:foo, :bar]` in the example above is a bit of macro magic that creates a [LabeledMetric](https://ezrast.gitlab.io/crometheus/Crometheus/Metric/LabeledMetric.html) with `Gauge` as a type parameter.
A slightly more involved example is available at `examples/src/wordcounter.cr`.

For server configuration see the [Registry](https://ezrast.gitlab.io/crometheus/Crometheus/Registry.html) class documentation.
If you want to use multiple registries, e.g. to expose two different sets of metrics on different ports, you'll need to instantiate a second Registry object (other than the default) and pass it as a third argument to your metric constructors (after the name and docstring).

If you want to define a custom metric type, see the documentation for the [Metric](https://ezrast.gitlab.io/crometheus/Crometheus/Metric.html) class, and inherit from that.

Alternately, you can just dive into the [API Documentation](https://ezrast.gitlab.io/crometheus) right from the top.

## Author

- [Ezra Stevens](https://gitlab.com/ezrast) - creator, maintainer
