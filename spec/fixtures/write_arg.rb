#!/usr/bin/env ruby

# Writes its second argument to the file indicated by the first argument.

File.open(ARGV[0], 'wb') { |f| f.write ARGV[1] }
