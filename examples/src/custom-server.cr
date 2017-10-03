# An example that shows how to use a registry's HTTP handler in tandem
# with Crystal's HTTP features.
# Projects of any scale will usually build their own handler stack like
# this, rather than rely on the built-in start_server or run_server
# methods.
require "http/server"
require "http/server/handlers/compress_handler"
require "crometheus"

metrics_handler = Crometheus.default_registry.get_handler
Crometheus.default_registry.path = "/metrics"
summary = Crometheus::Summary.new(:manual_values, "values entered via web ui")

server = HTTP::Server.new("localhost", 3000, [HTTP::CompressHandler.new,
                                              HTTP::LogHandler.new,
                                              HTTP::ErrorHandler.new(true),
                                              Crometheus::Middleware::HttpCollector.new,
                                              metrics_handler]) do |context|
  if "/" == context.request.path
    if val = context.request.body.try &.gets_to_end
      val =~ /value=(.+)/
      summary.observe $1.to_f
      message = "Observed #{$1.to_f}<br />"
    end
    context.response << MAIN_HTML % message
  else
    context.response.status_code = 404
    context.response << ERROR_HTML % context.request.path
  end
end

puts "Launching server at http://localhost:3000"
puts "Press Ctrl+C to exit"
server.listen

#####

MAIN_HTML = <<-HTML
<html><body>
  %s
  <br />Type a numeric value to observe that value in a histogram.
  <br />Type anything else to cause an exception.
  <form method="post">
    <input type="text" name="value" />
    <input type="submit" value="Observe!" />
  </form>
  <br />
  <a href="/metrics">See metrics</a>
</body></html>
HTML

ERROR_HTML = <<-HTML
<html><body>
  No resource at %s.
  You can <a href="/">go home</a> or <a href="/metrics">see metrics</a>.
</body></html>
HTML
