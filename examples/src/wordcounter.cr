# A simplistic usage example for basic Crometheus features.
# Creates some metrics, starts a server with default settings, and
# measures some silly statistics based on user input.
require "crometheus/counter"
require "crometheus/gauge"
require "crometheus/histogram"
include Crometheus

class WordCounter
  # Alias a labeled histogram type with a single label
  Crometheus.alias WordLengths = Histogram[:kind]

  def initialize
    # Initialize some new unlabelled metrics, passing a name and
    # docstring to each
    @lines = Counter.new(:lines, "The number of lines entered")
    @last_usage = Gauge.new(:last_usage, "Timestamp of latest gets()")
    @last_usage.set_to_current_time

    # Helper method for creating bucket arrays for histograms; simply
    # generates [4.0, 5.0, 6.0, 7.0, 8.0, 9.0, +Inf]
    bucket_array = Histogram.linear_buckets(4, 1, 7)

    # Histograms take a "buckets" argument in addition to name and
    # docstring.
    @word_length = WordLengths.new(:word_length, "How many words have been typed",
      buckets: bucket_array)

    # Accessing a particular labelset forces it to be initialized to 0.
    # Since we know all the label values we'll be using in advance,
    # we'll initialize them; this is optional.
    ["", "allcaps", "punctuated", "palindrome"].each do |label|
      @word_length[kind: label]
    end
  end

  def count_words(line : String)
    @lines.inc
    @last_usage.set_to_current_time
    line.scan(/\b\S+\b/) do |match|
      word = match[0]
      length = word.chars.count &.alphanumeric?
      @word_length[kind: ""].observe(length)
      @word_length[kind: "palindrome"].observe(length) if word == word.reverse
      @word_length[kind: "allcaps"].observe(length) if word == word.upcase
      @word_length[kind: "punctuated"].observe(length) unless word.chars.all? &.alphanumeric?
    end
  end
end

# By default, all metrics are added to a default registry, accessible
# like this.
reg = Crometheus.default_registry
reg.namespace = "wordcounter"
# Fire up the HTTP server in the background.
reg.start_server

word_counter = WordCounter.new

puts "Type a line of text, then visit http://#{reg.host}:#{reg.port}."
puts "Press Ctrl+D to quit."
while true
  line = gets
  if line.nil?
    break
  end
  word_counter.count_words(line)
end
