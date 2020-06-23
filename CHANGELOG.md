## **0.3.1** - 2020-06-23
* Updated for Crystal 0.35.1

## **0.3.0** - 2020-05-10
* Patched to work with Crystal 0.34.0

## **0.2.0** - 2017-10-02
* New: `Crometheus::Middleware::HttpCollector` allows easy HTTP metric
  gathering.
* Changed: Metric names now implicitly add an underscore before the
  suffix, if present.
* New: `Registry#path` specifies the HTTP request path(s) on which to
  serve metrics.
* New: `Registry#handler` returns an `HTTP::Handler` object.
* New: `Registry` by default creates a `StandardExports` (or derived)
  metric for exporting process statistics.
* New: `Crometheus.alias` allows shorthand aliasing of `LabeledMetric`
  types

## **0.1.1** - 2017-02-06
* Initial release
* Includes Gauges, Counters, Summaries, and Histograms
* Includes Registry class with basic server functionality
