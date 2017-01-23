require "http/server"
require "./collector"

module Crometheus
  class Registry
    property collectors = [] of CollectorBase
    property host = "localhost", port = 9027
    @server : HTTP::Server? = nil
    @server_on = false

    def register(collector)
      if @collectors.find {|coll| coll.name == collector.name}
        raise Exception.new "Registered collectors must have unique names"
      end
      @collectors << collector
      @collectors.sort_by! {|coll| coll.name}
    end

    def forget(collector)
      @collectors.delete(collector)
    end

    def start_server
      return false if @server && @server_on
      @server = server = HTTP::Server.new(@host, @port) do |context|
        context.response.content_type = "text/plain; version=0.0.4"
        generate_text_format(context.response)
      end

      spawn do
        @server_on = true
        server.listen
        @server_on = false
      end
      return true
    end

    def stop_server
      return false unless @server && @server_on
      @server.as(HTTP::Server).close
      Fiber.yield
      return true
    end

    def generate_text_format(io)
      @collectors.each do |coll|
        io << "# HELP " << coll.name << ' ' << coll.docstring << '\n'
        io << "# TYPE " << coll.name << ' ' << coll.type << '\n'
        coll.collect do |sample|
          io << coll.name << sample.suffix
          unless sample.labels.empty?
            io << '{' << sample.labels.map {|kk,vv| "#{kk}=\"#{vv}\""}.join(", ") << '}'
          end
          io << ' ' << stringify(sample.value) << '\n'
        end
      end
    end

    # Prometheus represents infinities as "+Inf" or "Inf" or "-Inf"
    # and NaN's as "Nan". I'm not sure if it will accept Crystal's
    # representations, which are different.
    # TODO: check if this is necessary
    private def stringify(ff : Float64) : String | Float64
      case ff
      when Float64::INFINITY
        "+Inf"
      when -Float64::INFINITY
        "-Inf"
      when ff
        ff
      else
        "Nan"
      end
    end

    # I believe the following will be more efficient once
    # https://github.com/crystal-lang/crystal/issues/3923 is resolved.
    # private def stringify(ff : Float64) : String | Float64
    #   return @@stringify_dict[ff]
    # rescue KeyError
    #   return ff
    # end
    # @@stringify_dict = {
    #   Float64::INFINITY => "+Inf",
    #   -Float64::INFINITY => "-Inf",
    #   Float64::NAN => "Nan"}
  end

  # Default registry
  @@registry = Registry.new
  def self.registry
    @@registry
  end
end
