#!/usr/bin/env ruby

# Writes the current directory to the file indicated by the first argument.

File.open(ARGV[0], 'wb') do |f|
  f.write Dir.pwd
  f.flush
end
