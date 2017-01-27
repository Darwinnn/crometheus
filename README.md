# crometheus

Crometheus is a [Prometheus](https://prometheus.io/) client library for instrumenting programs written in the [Crystal programming language](https://crystal-lang.org/).
For the most part, Crometheus assumes a basic familiarity with Prometheus.
To that end, readers may wish to skim the official documentation on Prometheus' [data model](https://prometheus.io/docs/concepts/data_model/), [metric types](https://prometheus.io/docs/concepts/metric_types/), and [text exposition format](https://prometheus.io/docs/instrumenting/exposition_formats/#text-format-details).

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
require "crometheus"

# Create a gauge collector.
gauge = Crometheus::Collector(Crometheus::Gauge).new(
  :my_first_gauge,
  "A sample gauge metric")

# Create one labeled and one unlabeled time series.
gauge.set 100.0
gauge[label: "yes"].set 200

# Access the default registry and start up the server.
Crometheus.default_registry.run_server
```
Then http://localhost:5000 to see your metrics:
```text
# HELP my_first_gauge A sample gauge metric
# TYPE my_first_gauge gauge
my_first_gauge 100.0
my_first_gauge{label="yes"} 200.0
```

The above is all the setup you need for straightforward use cases; all that's left is creating real metrics and instrumenting your code.
See the reference documentation (coming soon! Though the source is documented) for the `Crometheus::Gauge`, `Crometheus::Counter`, `Crometheus::Histogram`, and `Crometheus::Summary` classes to learn more about the available metric types.
Always use these classes as a parameter for `Crometheus::Collector`; avoid instantiating them yourself.

For server configuration see the `Crometheus::Registry` class documentation.
If you want to use multiple registries, e.g. to expose two different sets of metrics on different ports, you'll need to instantiate a second `Crometheus::Registry` object and pass it as a third argument to your `Crometheus::Collector` constructors.

If you want to define a custom metric type, see the documentation for the `Crometheus::Metric` class, and inherit from that.
Be sure your metric's method names don't collide with anything in `Crometheus::Collector`, since that class uses `forward_missing_to` to pretend it's a metric.

## Author

- [Ezra Stevens](https://gitlab.com/ezrast) - creator, maintainer
