# namespace
module ExecSandbox

# Manages sandboxed processes.
class Sandbox
  # The path to the sandbox's working directory.
  attr_reader :path
  
  # Empty sandbox.
  #
  # @param [String] admin the name of a user who will be able to peek into the
  #                       sandbox
  def initialize(admin)
    @user_name = ExecSandbox::Users.temp
    user_pwd = Etc.getpwnam @user_name
    @user_uid = user_pwd.uid
    @user_gid = user_pwd.gid
    @path = user_pwd.dir
    @admin_name = admin
    admin_pwd = Etc.getpwnam(@admin_name)
    @admin_uid = admin_pwd.uid
    @admin_gid = admin_pwd.gid
    @destroyed = false
    
    # principal argument for Spawn.spawn()
    @principal = { :uid => @user_uid, :gid => @user_gid, :dir => @path }
  end
  
  # Copies a file or directory to the sandbox.
  #
  # @param [String] from path to the file or directory to be copied
  # @param [Hash] options tweaks the permissions and the path inside the sandbox
  # @option options [String] :to the path inside the sandbox where the file or
  #     directory will be copied (defaults to the name of the source)
  # @option options [Boolean] :read_only if true, the sandbox user will not be
  #     able to write to the file / directory
  # @return [String] the absolute path to the copied file / directory inside the
  #                  sandbox
  def push(from, options = {})
    to = File.join @path, (options[:to] || File.basename(from))
    FileUtils.cp_r from, to
    
    permissions = options[:read_only] ? 0770 : 0750
    FileUtils.chmod_R permissions, to
    FileUtils.chown_R @admin_uid, @user_gid, to
    # NOTE: making a file / directory read-only is useless -- the sandboxed
    #       process can replace the file with another copy of the file; this can
    #       be worked around by noting the inode number of the protected file /
    #       dir, and making a hard link to it somewhere else so the inode won't
    #       be reused.
    
    to
  end

  # Copies a file or directory from the sandbox.
  #
  # @param [String] from relative path to the sandbox file or directory
  # @param [String] to path where the file/directory will be copied
  # @param [Hash] options tweaks the permissions and the path inside the sandbox
  # @return [String] the path to the copied file / directory outside the
  #                  sandbox, or nil if the file / directory does not exist
  #                  inside the sandbox
  def pull(from, to)
    from = File.join @path, from
    return nil unless File.exist? from
    
    FileUtils.cp_r from, to
    FileUtils.chmod_R 0770, to
    FileUtils.chown_R @admin_uid, @admin_gid, to
    # NOTE: making a file / directory read-only is useless -- the sandboxed
    #       process can replace the file with another copy of the file; this can
    #       be worked around by noting the inode number of the protected file /
    #       dir, and making a hard link to it somewhere else so the inode won't
    #       be reused.
    
    to
  end
  
  # Runs a command in the sandbox.
  #
  # @param [Array, String] command to be run; use an array to pass arguments to
  #                        the command
  # @param [Hash] options stdin / stdout redirection and resource limitations
  # @option options [Hash] :limits see {Spawn#set_limits}
  # @option options [String] :in path to a file that is set as the child's stdin
  # @option options [String] :in_data contents to be written to a pipe that is
  #     set as the child's stdin; if neither :in nor :in_data are specified, the
  #     child will receive the read end of an empty pipe
  # @option options [String] :out path to a file that is set as the child's
  #     stdout; if not set, the child will receive the write end of a pipe whose
  #     contents is returned in :out_data
  # @return [Hash] the result of {Wait4#wait4}, plus an :out_data key if no :out
  #                option is given
  def run(command, options = {})
    limits = options[:limits] || {}
    
    io = {}
    if options[:in]
      io[:in] = options[:in]
      in_rd = nil
    else
      in_rd, in_wr = IO.pipe
      in_wr.write options[:in_data] if options[:in_data]
      in_wr.close
      io[:in] = in_rd
    end
    if options[:out]
      io[:out] = options[:out]
    else
      out_rd, out_wr = IO.pipe
      io[:out] = out_wr
    end
    io[:err] = STDERR unless options[:no_stderr]
    
    pid = ExecSandbox::Spawn.spawn command, io, @principal, limits
    # Close the pipe ends that are meant to be used in the child.
    in_rd.close if in_rd
    out_wr.close if out_wr
    
    # Collect information about the child.
    if out_rd
      out_pieces = []
      out_pieces << out_rd.read rescue nil
    end
    status = ExecSandbox::Wait4.wait4 pid
    if out_rd
      out_pieces << out_rd.read rescue nil
      out_rd.close
      status[:out_data] = out_pieces.join('')
    end
    status
  end
  
  # Removes the files and temporary user associated with this sandbox.
  def close
    return if @destroyed
    ExecSandbox::Users.destroy @user_name
    @destroyed = true
  end
  
  # Cleans up when the sandbox object is garbage-collected.
  def finalize
    close
  end
end  # module ExecSandbox::Sandbox
  
  # Creates a sandbox, yields it, and destroys it.
  #
  # @param [String] admin the name of a user who will be able to peek into the
  #                       sandbox (optional)
  # @return the value returned from the block passed to this method
  def self.use(admin = Etc.getlogin, &block)
    sandbox = ExecSandbox::Sandbox.new admin
    begin
      return yield(sandbox)
    ensure
      sandbox.close
    end
  end
  
  # Creates a sandbox.
  #
  # The sandbox should be disposed of by calling {Sandbox#close} on it. This
  # method is much less convenient than #use, so make sure you have a good
  # reason to call it.
  #
  # @param [String] admin the name of a user who will be able to peek into the
  #                       sandbox (optional)
  # @return the value returned from the block passed to this method
  def self.open(admin = Etc.getlogin)
    ExecSandbox::Sandbox.new admin
  end
end  # namespace ExecSandbox
