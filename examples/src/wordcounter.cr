# A simplistic usage example for basic Crometheus features.
# Creates some metrics, starts a server with default settings, and measures some
# silly statistics based on user input.
require "crometheus/counter"
require "crometheus/gauge"
require "crometheus/histogram"
include Crometheus

# Initialize some new unlabelled metrics, passing a name and docstring to each
lines = Counter.new(:lines, "The number of lines entered")
start_time = Gauge.new(:start_time, "Startup timestamp")
start_time.set_to_current_time
last_usage = Gauge.new(:last_usage, "Timestamp of latest gets()")
last_usage.set_to_current_time

# Helper method for creating bucket arrays for histograms; simply generates
# [4.0, 5.0, 6.0, 7.0, 8.0, 9.0, +Inf]
bucket_array = Histogram.linear_buckets(4, 1, 7)

# Initialize a histogram with a single "type" label. Histograms take a
# "buckets" argument in addition to name and docstring.
word_length = Histogram[:type].new(:word_length, "How many words have been typed",
  buckets: bucket_array)

# Since we know in advance what labelsets we will be using, we can force
# them all to be initialized now.
["", "allcaps", "punctuated", "palindrome"].each do |label|
  word_length[type: label]
end

# By default, all metrics are added to a default registry, accessible like this.
reg = Crometheus.default_registry
reg.namespace = "wordcounter"
# Fire up the HTTP server in the background.
reg.start_server

puts "Type a line of text, then visit http://#{reg.host}:#{reg.port}."
puts "Press Ctrl+D to quit."
while true
  line = gets
  if line.nil?
    break
  end
  lines.inc
  last_usage.set_to_current_time
  line.scan(/\b\S+\b/) do |match|
    word = match[0]
    length = word.chars.count &.alphanumeric?
    word_length[type: ""].observe(length)
    word_length[type: "palindrome"].observe(length) if word == word.reverse
    word_length[type: "allcaps"].observe(length) if word == word.upcase
    word_length[type: "punctuated"].observe(length) unless word.chars.all? &.alphanumeric?
  end
end
