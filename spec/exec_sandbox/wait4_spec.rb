require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe ExecSandbox::Wait4 do
  describe '#wait4' do
    describe 'write_arg.rb' do
      before do
        pid = Kernel.fork { Process.exec bin_fixture(:exit_arg), '42' }
        @status = ExecSandbox::Wait4.wait4 pid
      end

      it 'should have the correct exit status' do
        @status[:exit_code].should == 42
      end

      it 'should not take more than 1s of user time' do
        @status[:user_time].should < 1
      end

      it 'should not take more than 1s of system time' do
        @status[:system_time].should < 1
      end
    end

    describe 'churn.rb' do
      before do
        pid = Kernel.fork { Process.exec bin_fixture(:churn), '', '2' }
        @status = ExecSandbox::Wait4.wait4 pid
      end

      it 'should have the correct exit status' do
        @status[:exit_code].should == 0
      end

      it 'should not take more than 3s of user time' do
        @status[:user_time].should < 3
      end

      it 'should not take less than 1s of user time' do
        @status[:user_time].should > 1
      end

      it 'should not take more than 1s of system time' do
        @status[:system_time].should < 1
      end
    end
  end

  describe '#wait4_nonblock' do
    describe 'churn.rb' do
      before do
        @pid = Kernel.fork { Process.exec bin_fixture(:churn), '', '1' }
      end

      after do
        begin
          ExecSandbox::Wait4.wait4 @pid
        rescue Errno::ECHILD
          # The child's status has already been reaped.
        end
      end

      it 'returns nil when wait4 would block' do
        ExecSandbox::Wait4.wait4_nonblock(@pid).should == nil
      end

      it 'does not block' do
        t_start = Time.now
        ExecSandbox::Wait4.wait4_nonblock @pid
        t_end = Time.now
        (t_end - t_start).should < 0.1
      end

      it 'returns resource usage data if called after the process ends' do
        sleep 2
        status = ExecSandbox::Wait4.wait4_nonblock @pid
        status[:user_time].should > 0.5
        status[:user_time].should < 2
      end
    end
  end
end
