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
    # Sort the list of redirections by file descriptor number.
    redirects = []
    [:in, :out, :err].each_with_index do |sym, fd_num|
      if target = io[sym]
        redirects << [fd_num, redirects.length, target]
      end
    end
    io.each do |k, v|
      if k.kind_of? Integer
        redirects << [k, redirects.length, v]
      end
    end
    
    # Perform the redirections.
    redirects.sort!
    redirects.each do |fd_num, _, target|    
      if target.respond_to?(:fileno)
        # IO stream.
        if target.fileno != fd_num
          LibC.close fd_num
          LibC.dup2 target.fileno, fd_num
        end
      else
        # Filename string.
        LibC.close fd_num
        open_fd = IO.sysopen(target, 'r+')
        if open_fd != fd_num
          LibC.dup2 open_fd, fd_num
          LibC.close open_fd
        end
      end
    end
    
    # Close all file descriptors not in the redirection table.
    redirected_fds = Set.new redirects.map(&:first)
    max_fd = LibC.getdtablesize
    0.upto(max_fd) do |fd|
      next if redirected_fds.include?(fd)
      
      # TODO(pwnall): this is slow; consider detecting the Ruby version and
      #               only running it on buggy MRIs
      begin
        # This fails if rb_reserved_fd_p returns 0.
        # In that case, we shouldn't close the FD, otherwise the VM will crash.
        IO.new(fd)
      rescue ArgumentError, Errno::EBADF
        next
      end
      LibC.close fd
    end
  end
  
  # Sets the process' principal for access control.
  #
  # @param [Hash] principal information about the process' principal
  # @option principal [String] :dir the process' working directory
  # @option principal [Fixnum] :uid the new user ID
  # @option principal [Fixnum] :gid the new group ID
  def self.set_principal(principal)
    Dir.chdir principal[:dir] if principal[:dir]
    
    if principal[:gid]
      begin
        Process::Sys.setresgid principal[:gid], principal[:gid], principal[:gid]
      rescue NotImplementedError
        Process::Sys.setgid principal[:gid]
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
        Process::Sys.setuid principal[:uid]
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
      _setrlimit Process::RLIMIT_CPU, limits[:cpu]
    end
    if limits[:processes]
      _setrlimit Process::RLIMIT_NPROC, limits[:processes]
    end
    if limits[:file_size]
      _setrlimit Process::RLIMIT_FSIZE, limits[:file_size]
    end
    if limits[:open_files]
      _setrlimit Process::RLIMIT_NOFILE, limits[:open_files]
    end
    if limits[:data]
      _setrlimit Process::RLIMIT_AS, limits[:data]
      _setrlimit Process::RLIMIT_DATA, limits[:data]
      _setrlimit Process::RLIMIT_STACK, limits[:data]
      _setrlimit Process::RLIMIT_MEMLOCK, limits[:data]
      _setrlimit Process::RLIMIT_RSS, limits[:data]
    end
  end
  
  # Wrapper for Process.setrlimit that eats exceptions.
  def self._setrlimit(limit, value)
    begin
      Process.setrlimit limit, value, value
    rescue Errno::EPERM
      # The call failed, probably because the limit is already lower than this.
    end
  end
  
  # Maps raw I/O functions.
  module LibC
    extend FFI::Library
    ffi_lib FFI::Library::LIBC
    attach_function :close, [:int], :int
    attach_function :getdtablesize, [], :int
    attach_function :dup2, [:int, :int], :int
  end  # module ExecSandbox::Spawn::Libc
end  # module ExecSandbox::Spawn
  
end  # namespace ExecSandbox
