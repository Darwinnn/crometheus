require "http/server"
require "../registry"
require "../counter"
require "../histogram"

module Crometheus
  # The Middleware module is reserved for definitions that are not
  # necessary for Crometheus to function but may be useful to
  # developers.
  module Middleware
    # This class is an `HTTP::Handler` that records basic statistics
    # about every request that comes in, and passes through to the next
    # handler without modifying the request or response.
    # It creates the `http_requests_total`,
    # `http_request_duration_seconds`, and
    # `http_request_exceptions_total` metrics.
    # See the `custom-server` example for a use case.
    class HttpCollector
      include HTTP::Handler

      Crometheus.alias RequestCounter = Crometheus::Counter[:code, :method, :path]
      Crometheus.alias DurationHistogram = Crometheus::Histogram[:method, :path]
      Crometheus.alias ExceptionCounter = Crometheus::Counter[:exception, :method, :path]

      # Transforms request paths before labeling metrics, so that
      # multiple paths may be tracked in the same time series.
      property path_cleaner : String -> String

      # Substitutes `":id"` in place of numeric path components, e.g.
      # turning `"/forum/102/thread/12"` into `"/forum/:id/thread/:id"`.
      DEFAULT_PATH_CLEANER = ->(path : String){ path.gsub(%r{/\d+(?=/|$)}, "/:id") }

      # Initializes the `HttpCollector`, allowing the user to set the
      # registry to which metrics will be added and the path cleaner.
      # Defaults to `Crometheus.default_registry` and
      # `DEFAULT_PATH_CLEANER`.
      # Set `path_cleaner` to `nil` to avoid mangling paths altogether.
      def initialize(@registry = Crometheus.default_registry,
                     path_cleaner : (String -> String) | Nil = DEFAULT_PATH_CLEANER )
        @requests = RequestCounter.new(
          :http_requests_total,
          "The total number of HTTP requests handled by the application.",
          @registry)
        @durations = DurationHistogram.new(
          :http_request_duration_seconds,
          "The HTTP response duration of the application.",
          @registry)
        @exceptions = ExceptionCounter.new(
          :http_request_exceptions_total,
          "The total number of exceptions raised by the application.",
          @registry)
        @path_cleaner = path_cleaner || ->(path : String){ path }
      end

      # :nodoc:
      def call(context)
        method = context.request.method
        path = context.request.try &.path
        path = path ? path_cleaner.call(path) : ""

        @durations[method: method, path: path].measure_runtime do
          begin
            call_next(context)
          rescue ex
            @exceptions[exception: ex.class.to_s, method: method, path: path].inc
            raise ex
          end
        end

        @requests[code: context.response.status_code.to_s, method: method, path: path].inc
      end
    end
  end
end
