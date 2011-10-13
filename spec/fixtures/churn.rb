#!/usr/bin/env ruby

# Churns away at math for a number of seconds indicated by the second argument,
# then outputs a '+' and exists.

start = Time.now
loop do
  j = 0
  1.upto(1_000_000) { |i| j = i * i + 100 }
  break if Time.now - start >= ARGV[1].to_i
end

unless ARGV[0].empty?
  File.open(ARGV[0], 'wb') do |f|
    f.sync = true
    f.write '+'
    f.flush
  end
end
