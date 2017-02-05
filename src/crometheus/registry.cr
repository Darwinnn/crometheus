require "http/server"
require "./metric"
require "./stringify"

module Crometheus
  # The `Registry` class is responsible for aggregating samples from all
  # configured metrics and exposing data to Prometheus via an HTTP
  # server.
  #
  # Crometheus automatically instantiates a `Registry` for you, and
  # `Metric` registers with it by default. This means that for most
  # applications, this is all it takes to get an HTTP server up and
  # serving:
  # ```
  # require "crometheus/registry"
  # Crometheus.default_registry.host = "0.0.0.0" # defaults to "localhost"
  # Crometheus.default_registry.port = 12345     # defaults to 5000
  # Crometheus.default_registry.start_server
  # ```
  class Registry
    # A list of all `Metric` objects being exposed by this registry.
    getter metrics = [] of Metric
    # The host that the server should bind to.
    property host = "localhost"
    # The port that the server should bind to.
    property port = 5000
    # `namespace`, if non-empty, will be prefixed to all metric names,
    # separated by an underscore.
    getter namespace = ""
    @server : HTTP::Server? = nil
    @server_on = false

    # Adds a `Metric` to this registry. The metric's samples will then
    # show up whenever the server is scraped. Metrics call `#register`
    # automatically in their constructors, so manual invocation is not
    # usually required.
    def register(metric)
      if @metrics.find {|mm| mm.name == metric.name}
        raise ArgumentError.new "Registered metrics must have unique names"
      end
      @metrics << metric
      @metrics.sort_by! {|mm| mm.name}
    end

    # Removes a `Metric` from the registry. The `Metric` keeps its
    # state and can be re-registered later.
    def unregister(metric)
      @metrics.delete(metric)
    end

    # Spawns a new fiber that serves HTTP connections on `host` and
    # `port`, then returns `true`. If the server is already running,
    # returns `false` without creating a new one.
    #
    # `#start_server` is included for convenience, but does not do any
    # exception handling. Serious applications should use `#run_server`
    # instead, which runs in the current fiber.
    def start_server
      return false if @server_on

      spawn do
        run_server
      end
      return true
    end

    # Stops the HTTP server, then returns `true`. If the server is not
    # running, returns `false` instead.
    def stop_server
      return false unless @server && @server_on
      @server.as(HTTP::Server).close
      Fiber.yield
      return true
    end

    # Creates an `HTTP::Server` object bound to `host` and `port`
    # and begins serving metrics. Returns `true` once the server is
    # stopped. Returns `false` immediately if this registry is already
    # serving.
    def run_server
      return false if @server_on
      @server = server = HTTP::Server.new(@host, @port) do |context|
        context.response.content_type = "text/plain; version=0.0.4"
        generate_text_format(context.response)
      end

      @server_on = true
      begin
        server.listen
      ensure
        @server_on = false
      end
      return true
    end

    # Sets `namespace` to `str`, after validating legality.
    def namespace=(str : String)
      unless str =~ /[a-zA-Z_:][a-zA-Z0-9_:]*/
        raise ArgumentError.new("#{str} does not match [a-zA-Z_:][a-zA-Z0-9_:]*")
      end
      @namespace = str
    end

    private def generate_text_format(io)
      prefix = namespace.empty? ? "" : namespace + "_"
      @metrics.each do |mm|
        io << "# HELP " << prefix << mm.name << ' ' << mm.docstring << '\n'
        io << "# TYPE " << prefix << mm.name << ' ' <<
          (mm.class.type.as?(Metric::Type) || "untyped") << '\n'
        mm.samples do |sample|
          io << prefix << mm.name << sample.suffix
          unless sample.labels.empty?
            io << '{' << sample.labels.map {|kk,vv| "#{kk}=\"#{vv}\""}.join(", ") << '}'
          end
          io << ' ' << Crometheus.stringify(sample.value) << '\n'
        end
      end
    end
  end

  @@default_registry = Registry.new
  # Returns the default `Registry`. All new `Metric` instances get
  # registered to this by default.
  def self.default_registry
    @@default_registry
  end
end
