# namespace
module ExecSandbox

# Manages sandboxed processes.
module Spawn
  # Spawns a child process.
  #
  # @param [String, Array] command the command to be executed via exec
  # @param [Hash] io see limit_io
  # @param [Hash] principal the principal for the enw process
  # @param [Hash] resources see limit_resources
  # @return [Fixnum] the child's PID
  def self.spawn(command, io = {}, principal = {}, resources = {})
    max_fd = 256  # TODO(pwnall): get the limit properly
    
    fork do
      limit_io io
      limit_resources resources
      set_principal principal
      if command.respond_to? :to_str
        Process.exec command
      else
        Process.exec *command
      end
    end
  end

  # Constraints the available file descriptors.
  #
  # @param [Hash] io associates file descriptors with IO objects or file paths;
  #                  all file descriptors not covered by io will be closed
  def self.limit_io(io)
    [:stdin, :stdout, :stderr].each_with_index do |sym, fd_num|
      if target = io.delete(sym)
        io[fd_num] = target
      end
    end
    io.each do |k, v|
      if v.respond_to?(:to_str)
        IO.for_fd(k).reopen(v, 'r+')
      else
        IO.for_fd(k).reopen(v)
      end
    end
    
    # Close all file descriptors.
    max_fd = 256  # TODO(pwnall): get this from some syscall
    0.upto(max_fd) do |fd|
      next if io[fd]
      IO.for_fd(fd).close rescue nil
    end
  end
  
  # Sets the process' principal for access control.
  #
  # @param [Hash] principal information about the process' principal
  # @option principal :uid the new user ID
  # @option principal :gid the new group ID
  def self.set_principal(principal)
    if principal[:gid]
      begin
        Process::Sys.setresgid principal[:gid], principal[:gid], principal[:gid]
      rescue NotImplementedError
        Process.gid = principal[:gid]
        Process.egid = principal[:gid]
      end
    end
    if principal[:uid]
      begin
        Process.initgroups Etc.getpwuid(principal[:uid]).name,
                           principal[:gid] || Process.gid
      rescue NotImplementedError
      end
      
      begin
        Process::Sys.setresuid principal[:uid], principal[:uid], principal[:uid]
      rescue NotImplementedError
        Process.uid = principal[:uid]
        Process.euid = principal[:uid]
      end
    end
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
  def self.limit_resources(limits)
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
