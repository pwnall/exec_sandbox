# namespace
module ExecSandbox

# Interface to the wait4 system call using the ffi library.
module Wait4
  # Waits for a process to end, and collects its exit status and resource usage.
  #
  # @param [Fixnum] pid the PID of the process to wait for; should be a child of
  #                     this process
  # @return [Fixnum, ExecSandbox::Wait4::Rusage] process exit status and resource
  #                                              usage
  def self.wait4(pid)
    status_ptr = FFI::MemoryPointer.new :int
    rusage = ExecSandbox::Wait4::Rusage.new
    returned_pid = LibC.wait4(pid, status_ptr, 0, rusage.pointer)
    raise SystemCallError, FFI.errno if returned_pid < 0
    status = status_ptr.read_int
    status_ptr.free
    return status, rusage
  end

  # Maps wait4 in libc. 
  module LibC
    extend FFI::Library
    ffi_lib FFI::Library::LIBC
    attach_function :wait4, [:int, :pointer, :int, :pointer], :int,
                    :blocking => true
  end  # module ExecSandbox::Wait4::Libc
  
  # Maps struct rusage in sys/resource.h, used by wait4.
  class Rusage < FFI::Struct
    # Total amount of user time used.
    layout :ru_utime_sec, :time_t,
           :ru_utime_usec, :suseconds_t,
    # Total amount of system time used.
           :ru_stime_sec, :time_t,
           :ru_stime_usec, :suseconds_t,
    # Maximum resident set size (in kilobytes).
           :ru_maxrss, :long,
    # Amount of sharing of text segment memory with other processes
    # (kilobyte-seconds).
           :ru_ixrss, :long,
    # Amount of data segment memory used (kilobyte-seconds).
           :ru_idrss, :long,
    # Amount of stack memory used (kilobyte-seconds).
           :ru_isrss, :long,
    # Number of soft page faults (i.e. those serviced by reclaiming a page from
    # the list of pages awaiting reallocation.
           :ru_minflt, :long,
    # Number of hard page faults (i.e. those that required I/O).
           :ru_majflt, :long,
    # Number of times a process was swapped out of physical memory.
           :ru_nswap, :long,
    # Number of input operations via the file system.  Note: This and
    # `ru_oublock' do not include operations with the cache.
           :ru_inblock, :long,
    # Number of output operations via the file system.
           :ru_oublock, :long,
    # Number of IPC messages sent.
           :ru_msgsnd, :long,
    # Number of IPC messages received.
           :ru_msgrcv, :long,
    # Number of signals delivered.
           :ru_nsignals, :long,
    # Number of voluntary context switches, i.e. because the process gave up the
    # process before it had to (usually to wait for some resource to be
    # available).
           :ru_nvcsw, :long,
    # Number of involuntary context switches, i.e. a higher priority process
    # became runnable or the current process used up its time slice.
           :ru_nivcsw, :long,
    # Padding, so we don't crash if the struct gets ammended on newer OSes.
           :padding, :byte, 256
  end  # struct ExecSandbox::Wait4::Rusage

end  # module ExecSandbox::Wait4
  
end  # namespace ExecSandbox
