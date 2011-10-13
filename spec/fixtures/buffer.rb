#!/usr/bin/env ruby

# Allocates a buffer sized according to the second argument and writes it to the
# file indicated by the first argument.

buffer = String.new "S" * ARGV[1].to_i
if ARGV[0].empty?
  STDOUT.write buffer
  STDOUT.flush
else
  File.open(ARGV[0], 'wb') do |f|
    f.write buffer
    f.flush
  end
end
