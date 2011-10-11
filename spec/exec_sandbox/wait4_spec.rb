require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe ExecSandbox::Wait4 do
  describe '#wait4' do
    describe 'on write_arg' do
      before do
        pid = Kernel.fork { Process.exec bin_fixture(:exit_arg), '42' }
        @status, @usage = ExecSandbox::Wait4.wait4 pid
      end
      
      it 'should have the correct exit status' do
        @status.should == 42
      end
      
      it 'should not take more than 50ms of user time' do
        @usage[:user_time].should <= 0.050
      end
      
      it 'should not take more than 50ms of system time' do
        @usage[:system_time].should <= 0.050
      end
    end
  end
end