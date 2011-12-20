#!/usr/bin/env ruby

# Counts from 1 to the first argument, and writes each number on a separate
# line. Odd numbers go to STDOUT, even numbers go to STDERR. 
# on both STDOUT and STDERR.

limit = ARGV[0].to_i
1.upto(limit) do |i|
  file = (i % 2 == 0) ? STDERR : STDOUT
  file.write "#{i}\n"
  file.flush
end
