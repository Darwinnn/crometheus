require "./crometheus/*"

# Crometheus is a [Prometheus](https://prometheus.io/) client library
# for instrumenting programs written in the Crystal programming
# language. Users are advised to familiarize themselves with Prometheus
# before attempting to make use of this library.
#
# Users getting started with Crometheus should become familiar with the
# `Crometheus::Collector` class, which holds a collection of metrics
# under the same metric name but different labelsets, and the
# `Crometheus::Registry` class, which keeps track of all of a program's
# Collectors and exports their data in a Prometheus-compatible format.
# Additionally, at least one of `Crometheus::Counter`,
# `Crometheus::Gauge`, `Crometheus::Histogram`, and
# `Crometheus::Summary` will need to be used in order to gather data,
# though `Crometheus::Collector` will take care of instantiating those
# for you.
#
# More advanced users wanting to implement their own metric types should
# examine `Crometheus::Metric`, which forms the abstract base for all
# metric types, and see how the built-in types implement its methods.
module Crometheus
end
