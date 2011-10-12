# @title ExecSandbox - Run foreign binaries using POSIX sandboxing features 
# @author Victor Costan

# Standard library
require 'etc'

# Gems
require 'ffi'

# TODO(pwnall): documentation
module ExecSandbox
end  # namespace ExecSandbox

# Code
require 'exec_sandbox/dir.rb'
require 'exec_sandbox/sandbox.rb'
require 'exec_sandbox/spawn.rb'
require 'exec_sandbox/users.rb'
require 'exec_sandbox/wait4.rb'
