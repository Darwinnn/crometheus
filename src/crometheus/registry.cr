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
        @collectors.each do |coll|
          context.response << coll
        end
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

  end

  # Default registry
  @@registry = Registry.new
  def self.registry
    @@registry
  end
end
