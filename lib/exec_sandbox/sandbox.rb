# namespace
module ExecSandbox

# Manages sandboxed processes.
module Sandbox
  # Empty sandbox.
  #
  # @param [String] owner the name of a user who will be able to peek into the
  #                       sandbox
  def initialize(owner = nil)
    @user_name = ExecSandbox::Users.temp
    user_pwd = Etc.getpwnam @user_name
    @user_uid = user_pwd.uid
    @user_gid = user_pwd.git
    @owner_name = owner
    owner_pwd = Etc.getpwnam @owner_name
    @owner_uid = user_pwd.uid
    @owner_gid = user_pwd.gid
  end
end  # module ExecSandbox::Sandbox
  
  # Builds a sandbox.
  
  def self.build(owner = nil, &block)
    
  end
end  # namespace ExecSandbox
