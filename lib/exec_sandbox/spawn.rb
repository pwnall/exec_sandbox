# namespace
module ExecSandbox

# Manages sandboxed processes.
module Spawn
  # Waits for a child process to finish and collects exit information.
  #
  # @param [Fixnum] pid the PID of the child process to wait for
  def reap_child(pid)
    
  end
  
  # Constrains the resource usage of the current process.
  #
  # @param [Hash{Symbol => Number}] limits the constraints to be applied
  # @option limits [Fixnum] :cpu maximum CPU time (for best results, give it an
  #     extra second, and measure actual resource usage after the process
  #     completes)
  # @option limits [Fixnum] :processes number of processes that can be spawned
  #     by the user who owns this process (useful in conjunction with temporary
  #     users)
  # @option limits [Fixnum] :file_size maximum size of a file created by the
  #     process; the process can still fill the disk by creating many files of
  #     this size
  # @option limits [Fixnum] :open_files maximum number of open files; remember
  #     that any process uses 3 open files for STDIN, STDOUT, and STDERR
  # @option limits [Fixnum] :data maximum data segment size (static data plus
  #     heap) and stack; allow slack for the libraries used by the process;
  #     mostly useful to prevent a process from freezing the machine by pushing
  #     everything into swap
  def limit_resources(limits)
    if limits[:cpu]
      Process.setrlimit Process::RLIMIT_CPU, limits[:cpu], limits[:cpu]
    end
    if limits[:processes]
      Process.setrlimit Process::NPROC, limits[:processes], limits[:processes]
    end
    if limits[:file_size]
      Process.setrlimit Process::FSIZE, limits[:file_size], limits[:file_size]
    end
    if limits[:open_files]
      Process.setrlimit Process::NOFILE, limits[:open_files],
                                         limits[:open_files]
    end
    if limits[:data]
      Process.setrlimit Process::DATA, limits[:data], limits[:data]
      Process.setrlimit Process::STACK, limits[:data], limits[:data]
    end
  end
end  # module ExecSandbox::Spawn
  
end  # namespace ExecSandbox
