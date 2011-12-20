# namespace
module ExecSandbox

# Manages sandbox users.
#
# @see Users#temp
# @see Users#destroy
module Users
  # Creates an unprivileged user.
  #
  # @param [String] prefix used at the beginning of temporary user names to
  #                        help identify the application that created the users
  # @return [String] the user's name
  def self.temp(prefix = 'xsbx.rb')
    loop do
      user_name = prefix + '-%x.%x.%x' % [$PID, Time.now.to_i, rand(65536)]
      etc = nil
      begin
        etc = Etc.getpwnam(name)
      rescue ArgumentError
        # User not found: good!
      end
      next if etc
      
      create user_name
      return user_name
    end
  end
  
  # Creates a user for unprivileged operations.
  #
  # @param [String] user_name the user's short (UNIX) name (should be unique)
  # @param [String] primary_group_name; if no name is supplied, the user's
  #                 primary group will be set to a new group
  #
  # @return [Fixnum] the new user's UID
  def self.create(user_name, primary_group_name = nil)
    group_id = primary_group_name && Etc.getgrnam(primary_group_name).gid 
    
    if RUBY_PLATFORM =~ /darwin/  # OSX
      home_dir = "/Users/#{user_name}" 
      unless group_id
        # Create a group with the same name as the user.
        group_id = `dscl . -list /Groups`.split.
            map { |g| `dscl . -read /Groups/#{g} PrimaryGroupID`.split.last.
            to_i }.sort.last + 1

        # Simulate adduser's group creation.
        command_prefix = ['dscl', '.', '-create', "/Groups/#{user_name}"]
        [
          [],
          ['PrimaryGroupID', group_id.to_s],
        ].each do |command_suffix|
          command = command_prefix + command_suffix
          unless Kernel.system(*command)
            raise RuntimeError, "User creation failed at #{command.inspect}!"
          end
        end
      end
      
      # Find an available UID.
      user_id = `dscl . -list /Users`.split.
          map { |u| `dscl . -read /Users/#{u} UniqueID`.split.last.to_i }.
          sort.last + 1
    
      # Simulate adduser.
      command_prefix = ['dscl', '.', '-create', "/Users/#{user_name}"]
      [
        [],
        ['UserShell', '/bin/bash'],
        ['UniqueID', user_id.to_s],
        ['PrimaryGroupID', group_id.to_s],
        ['NFSHomeDirectory', home_dir],
      ].each do |command_suffix|
        command = command_prefix + command_suffix
        unless Kernel.system(*command)
          raise RuntimeError, "User creation failed at #{command.inspect}!"
        end
      end
      
    elsif RUBY_PLATFORM =~ /win/  # Windows
      raise 'Windows is not supported; patches welcome!'
      
    else  # Linux
      if group_id
        command = ['useradd', '--gid', group_id.to_s, '--no-user-group',
                   '--no-create-home', '--system',
                   '--comment', 'exec_sandbox.rb temporary user', user_name]
      else
        command = ['useradd', '--user-group', '--no-create-home', '--system',
                   '--comment', 'exec_sandbox.rb temporary user', user_name]
      end
      unless Kernel.system(*command)
        raise RuntimeError, "User creation failed at #{command.inspect}!"
      end
    
      home_dir = File.join '/home', user_name
      user_id = Etc.getpwnam(user_name).uid
      group_id = Etc.getpwnam(user_name).gid
    end  # RUBY_PLATFORM

    FileUtils.mkdir_p home_dir
    FileUtils.chown_R user_id, group_id, home_dir
    FileUtils.chmod_R 0750, home_dir
    
    user_id
  end
  
  # Removes a user that was previously created by create.
  #
  # @param [String] user_name the user's short (UNIX) name
  def self.destroy(user_name)
    user_pw = Etc.getpwnam(user_name)
    home_dir = user_pw.dir
    FileUtils.rm_rf home_dir
    
    user_gid = user_pw.gid
    group_name = Etc.getgrgid(user_gid).name
    # If the group name matches the user name, the group is a temp.
    destroy_group = user_name == group_name
    
    if RUBY_PLATFORM =~ /darwin/  # OSX
      command = ['dscl', '.', '-delete', "/Users/#{user_name}"]
      unless Kernel.system(*command)
        raise RuntimeError, "User removal failed at #{command.inspect}!"
      end

      if destroy_group
        command = ['dscl', '.', '-delete', "/Groups/#{group_name}"]
        unless Kernel.system(*command)
          raise RuntimeError, "User removal failed at #{command.inspect}!"
        end
      end
    elsif RUBY_PLATFORM =~ /win/  # Windows
      raise 'Windows is not supported; patches welcome!'
      ['userdel', git_user]
    else  # Linux
      command = ['userdel', user_name]
      unless Kernel.system(*command)
        raise RuntimeError, "User removal failed at #{command.inspect}!"
      end
      if destroy_group
        # Make sure that the group exists. userdel might remove it.
        begin
          Etc.getgrnam(group_name)
        rescue ArgumentError
          destroy_group = false
        end
      end
      if destroy_group
        command = ['groupdel', group_name]
        unless Kernel.system(*command)
          raise RuntimeError, "User removal failed at #{command.inspect}!"
        end
      end
    end  # RUBY_PLATFORM
  end
  
  # Finds users whose names match a String or Regexp pattern.
  #
  # @param [String] pattern matched against user names using ===
  # @return [Array<String>] names of users 
  def self.named(pattern)
    users = []
    Etc.passwd do |user|
      users << user.name if pattern === user.name
    end
    users
  end

  # Destroys users created by temp.
  #
  # @param [String] prefix match the prefix given to temp
  # @return [Array<String>] names of users that were deleted
  def self.destroy_temps(prefix = 'xsbx.rb')
    # Matches the names created by temp.
    pattern = /^#{prefix}\-[0-9a-f]+\.[0-9a-f]+\.[0-9a-f]+$/
    # Each returns the collection that it iterates over.
    self.named(pattern).each { |name| destroy name }
  end
end  # module ExecSandbox::Users
  
end  # namespace ExecSandbox
