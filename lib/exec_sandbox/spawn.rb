# namespace
module ExecSandbox

# Manages sandboxed processes.
module Spawn
  # @param [Hash{Symbol => Number}] 
  def apply_limits(limits)
    if limits[:cpu]
      Process.setrlimit Process::RLIMIT_CPU, limits[:cpu], limits[:cpu]
    end
    if limits[:processes]
      Process.setrlimit Process::NPROC, limits[:processes], limits[:processes]
    end
  end
end  # module ExecSandbox::Spawn
  
end  # namespace ExecSandbox
