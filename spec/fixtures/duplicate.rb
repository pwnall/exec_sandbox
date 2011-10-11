#!/usr/bin/env ruby

# Writes STDIN to STDOUT twice.

bits = STDIN.read
2.times { STDOUT.write bits }
STDOUT.flush
