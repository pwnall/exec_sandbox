require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe ExecSandbox::Spawn do
  let(:test_user) { Etc.getlogin }
  let(:test_uid) { Etc.getpwnam(test_user).uid }
  let(:test_gid) { Etc.getpwnam(test_user).gid }
  let(:test_group) { Etc.getgrgid(test_gid).name }
  
  describe '#spawn IO redirection' do
    before do
      @temp_in = Tempfile.new 'exec_sandbox_rspec'
      @temp_in.write "Spawn test\n"
      @temp_in.close
      @temp_out = Tempfile.new 'exec_sandbox_rspec'
      @temp_out.close
    end
    after do
      @temp_in.unlink
      @temp_out.unlink
    end

    shared_examples_for 'duplicate.rb' do
      it 'should not crash' do
        @status[:exit_code].should == 0
      end
      
      it 'should write successfully' do
        @temp_out.open
        begin
          @temp_out.read.should == "Spawn test\nSpawn test\n"
        ensure
          @temp_out.close
        end
      end
    end
    
    describe 'with paths' do
      before do
        pid = ExecSandbox::Spawn.spawn bin_fixture(:duplicate),
            {:stdin => @temp_in.path, :stdout => @temp_out.path}
        @status = ExecSandbox::Wait4.wait4 pid
      end

      it_behaves_like 'duplicate.rb'        
    end
    
    describe 'with file descriptors' do
      before do
        File.open(@temp_in.path, 'r') do |in_io|
          File.open(@temp_out.path, 'w') do |out_io|
            pid = ExecSandbox::Spawn.spawn bin_fixture(:duplicate),
                {:stdin => in_io, :stdout => out_io, :stderr => STDERR}
            @status = ExecSandbox::Wait4.wait4 pid
          end
        end
      end

      it_behaves_like 'duplicate.rb'
    end
    
    describe 'without stdout' do
      before do
        pid = ExecSandbox::Spawn.spawn bin_fixture(:duplicate),
                                       {:stdin => @temp_in.path}
        @status = ExecSandbox::Wait4.wait4 pid
      end
      
      it 'should crash' do
        @status[:exit_code].should_not == 0
      end
    end
    
    describe '#spawn principal' do
      
    end
    
    describe '#spawn resource limits' do
      
    end
  end
end
