#!/usr/bin/env ruby

# Allocates a buffer sized according to the second argument and writes it to the
# file indicated by the first argument.

buffer = String.new "\xFE" * ARGV[1].to_i
File.open(ARGV[0], 'wb') do |f|
  f.write buffer
  f.flush
end
