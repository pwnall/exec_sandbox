#!/usr/bin/env ruby

# Forks a number of processes matching second argument, each process writes a
# + to the file pointed by the first argument.

proc_count = ARGV[1].to_i
pids = Array.new proc_count

File.open(ARGV[0], 'wb') do |f|
  f.sync = true
  0.upto(proc_count - 1) do |i|
    pids[i] = fork do
      f.write '+'
      sleep 1
    end
  end
  0.upto(proc_count - 1) { |i| Process.waitpid(pids[i]) }
end
