# @title ExecSandbox - Run foreign binaries using POSIX sandboxing features 
# @author Victor Costan

# Standard library
require 'English'
require 'etc'
require 'fcntl'
require 'fileutils'
require 'set'
require 'tempfile'
require 'tmpdir'

# Gems
require 'ffi'

# TODO(pwnall): documentation
module ExecSandbox
end  # namespace ExecSandbox

# Code
require 'exec_sandbox/sandbox.rb'
require 'exec_sandbox/spawn.rb'
require 'exec_sandbox/users.rb'
require 'exec_sandbox/wait4.rb'
