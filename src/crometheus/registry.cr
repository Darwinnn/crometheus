require "http/server"
require "./collection"

module Crometheus
  class Registry
    property collections = [] of CollectionBase
    property host = "localhost", port = 9027
    @server : HTTP::Server? = nil
    @server_on = false

    def register(collection)
      if @collections.find {|coll| coll.name == collection.name}
        raise Exception.new "Registered collections must have unique names"
      end
      @collections << collection
      @collections.sort_by! {|coll| coll.name}
    end

    def forget(collection)
      @collections.delete(collection)
    end

    def start_server
      return false if @server && @server_on
      @server = server = HTTP::Server.new(@host, @port) do |context|
        context.response.content_type = "text/plain; version=0.0.4"
        @collections.each do |coll|
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
