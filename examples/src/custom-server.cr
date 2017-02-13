# An example that shows how to use a registry's HTTP handler in tandem
# with Crystal's HTTP features.
# Projects of any scale will usually build their own handler stack like
# this, rather than rely on the built-in start_server or run_server
# methods.
require "http/server"
require "crometheus/summary"

metrics_handler = Crometheus.default_registry.get_handler
Crometheus.default_registry.path = "/metrics"
summary = Crometheus::Summary.new(:manual_values, "values entered via web ui")

server = HTTP::Server.new("localhost", 3000, [HTTP::DeflateHandler.new,
                                              HTTP::LogHandler.new,
                                              HTTP::ErrorHandler.new(true),
                                              metrics_handler]
) do |context|
  if "/" == context.request.path
    if val = context.request.query_params["value"]?
      begin
        summary.observe val.to_f
        message = "Observed #{val.to_f}<br />"
      rescue ArgumentError
        message = "Invalid value: #{val}<br />"
      end
    end
    context.response << %{\
<html><body>
  #{message}
  <form>
    <input type="text" name="value" />
    <input type="submit" value="observe" />
  </form>
  <br />
  <a href="/metrics">See metrics</a>
</body></html>
}
  else
    context.response.status_code = 404
    context.response << %{
<html><body>
  No resource at #{context.request.path}.
  You can <a href="/">go home</a> or <a href="/metrics">see metrics</a>.
</body></html>
}
  end
end

puts "Launching server at http://localhost:3000"
puts "Press Ctrl+C to exit"
server.listen
