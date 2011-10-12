require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe ExecSandbox::Spawn do
  let(:test_user) { Etc.getlogin }
  let(:test_uid) { Etc.getpwnam(test_user).uid }
  let(:test_gid) { Etc.getpwnam(test_user).gid }
  let(:test_group) { Etc.getgrgid(test_gid).name }
  
  describe '#spawn IO redirection' do
    before do
      @temp_in = Tempfile.new 'exec_sandbox_rspec'
      @temp_in.write "Spawn IO test\n"
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
          @temp_out.read.should == "Spawn IO test\nSpawn IO test\n"
        ensure
          @temp_out.close
        end
      end
    end
    
    describe 'with paths' do
      before do
        pid = ExecSandbox::Spawn.spawn bin_fixture(:duplicate),
            {:in => @temp_in.path, :out => @temp_out.path}
        @status = ExecSandbox::Wait4.wait4 pid
      end

      it_behaves_like 'duplicate.rb'        
    end
    
    describe 'with file descriptors' do
      before do
        File.open(@temp_in.path, 'r') do |in_io|
          File.open(@temp_out.path, 'w') do |out_io|
            pid = ExecSandbox::Spawn.spawn bin_fixture(:duplicate),
                {:in => in_io, :out => out_io, :err => STDERR}
            @status = ExecSandbox::Wait4.wait4 pid
          end
        end
      end

      it_behaves_like 'duplicate.rb'
    end
    
    describe 'without stdout' do
      before do
        pid = ExecSandbox::Spawn.spawn bin_fixture(:duplicate),
                                       {:in => @temp_in.path}
        @status = ExecSandbox::Wait4.wait4 pid
      end
      
      it 'should crash' do
        @status[:exit_code].should_not == 0
      end
    end
  end

  describe '#spawn principal' do
    before do
      @temp = Tempfile.new 'exec_sandbox_rspec'
      @temp_path = @temp.path
      @temp.close
    end
    after do
      File.unlink(@temp_path) if File.exist?(@temp_path)
    end
    
    describe 'with root credentials' do
      before do
        pid = ExecSandbox::Spawn.spawn [bin_fixture(:write_arg),
            @temp_path, "Spawn uid test\n"], {:err => STDERR},
            {:uid => 0, :gid => 0}
        @status = ExecSandbox::Wait4.wait4 pid
        @fstat = File.stat(@temp_path)
      end
      
      it 'should not crash' do
        @status[:exit_code].should == 0
      end
      
      it 'should have the UID set to root' do
        @fstat.uid.should == 0
      end
      it 'should have the GID set to root' do
        @fstat.gid.should == 0
      end

      it 'should have the correct output' do
        File.read(@temp_path).should == "Spawn uid test\n"
      end
    end
    
    describe 'with non-root credentials' do
      before do
        @temp.unlink
        pid = ExecSandbox::Spawn.spawn [bin_fixture(:write_arg),
            @temp_path, "Spawn uid test\n"], {:err => STDERR},
            {:uid => test_uid, :gid => test_gid}
        @status = ExecSandbox::Wait4.wait4 pid
      end
      
      it 'should not crash' do
        @status[:exit_code].should == 0
      end
      
      it 'should have the UID set to the test user' do
        File.stat(@temp_path).uid.should == test_uid
      end
      it 'should have the GID set to the test group' do
        File.stat(@temp_path).gid.should == test_gid
      end
      
      it 'should have the correct output' do
        File.read(@temp_path).should == "Spawn uid test\n"
      end
    end

    describe 'with non-root credentials and a root-owned redirect file' do
      before do
        File.chmod 0700, @temp_path
        pid = ExecSandbox::Spawn.spawn [bin_fixture(:write_arg),
            @temp_path, "Spawn uid test\n"], {},
            {:uid => test_uid, :gid => test_gid}
        @status = ExecSandbox::Wait4.wait4 pid
      end
      
      it 'should crash (euid is set correctly)' do
        @status[:exit_code].should_not == 0
      end

      it 'should not have the correct output' do
        File.read(@temp_path).should_not == "Spawn uid test\n"
      end
    end
    
    describe 'with non-root credentials and a root-owned redirect file' do
      before do
        File.chmod 070, @temp_path
        pid = ExecSandbox::Spawn.spawn [bin_fixture(:write_arg), @temp_path,
            "Spawn uid test\n"], {},
            {:uid => test_uid, :gid => test_gid}
        @status = ExecSandbox::Wait4.wait4 pid
      end
      
      it 'should crash (egid is set correctly)' do
        @status[:exit_code].should_not == 0
      end

      it 'should not have the correct output' do
        File.read(@temp_path).should_not == "Spawn uid test\n"
      end
    end
  end
  
  describe '#spawn resource limits' do
    before do
      @temp = Tempfile.new 'exec_sandbox_rspec'
      @temp_path = @temp.path
      @temp.close
    end
    after do
      File.unlink(@temp_path) if File.exist?(@temp_path)
    end
    
    describe 'buffer.rb' do
      describe 'without limitations' do
        before do
          pid = ExecSandbox::Spawn.spawn [bin_fixture(:buffer), @temp_path,
              (100 * 1024 * 1024).to_s], {:err => STDERR}, {}, {}
          @status = ExecSandbox::Wait4.wait4 pid
        end

        it 'should not crash' do
          @status[:exit_code].should == 0
        end
        
        it 'should output 100 megs' do
          File.stat(@temp_path).size.should == 100 * 1024 * 1024
        end
      end
      
      describe 'with memory limitation' do
        before do
          pid = ExecSandbox::Spawn.spawn [bin_fixture(:buffer), @temp_path,
              (100 * 1024 * 1024).to_s], {}, {}, {:data => 64 * 1024 * 1024}
          @status = ExecSandbox::Wait4.wait4 pid
        end
        
        it 'should crash' do
          @status[:exit_code].should_not == 0
        end
        
        it 'should not have a chance to output data' do
          File.stat(@temp_path).size.should == 0
        end
      end
      
      describe 'with output limitation' do
        before do
          pid = ExecSandbox::Spawn.spawn [bin_fixture(:buffer), @temp_path,
              (100 * 1024 * 1024).to_s], {}, {}, {:file_size => 8 * 1024 * 1024}
          @status = ExecSandbox::Wait4.wait4 pid
        end
        
        it 'should crash' do
          @status[:exit_code].should_not == 0
        end
        
        it 'should not output more than 16 megs' do
          File.stat(@temp_path).size.should <= 16 * 1024 * 1024
        end
      end
    end
    
    describe 'fork.rb' do
      describe 'without limitations' do
        before do
          pid = ExecSandbox::Spawn.spawn [bin_fixture(:fork), @temp_path,
              10.to_s], {:err => STDERR}, {}, {}
          @status = ExecSandbox::Wait4.wait4 pid
        end

        it 'should not crash' do
          @status[:exit_code].should == 0
        end
        
        it 'should output 10 +es' do
          File.stat(@temp_path).size.should == 10
        end
      end
      
      describe 'with sub-process limitation' do
        before do
          pid = ExecSandbox::Spawn.spawn [bin_fixture(:fork), @temp_path,
              10.to_s], {}, {}, {:processes => 4}
          @status = ExecSandbox::Wait4.wait4 pid
        end
        
        it 'should crash' do
          @status[:exit_code].should_not == 0
        end
        
        it 'should output less than 5 +es' do
          File.stat(@temp_path).size.should < 5
        end
      end
    end
    
    describe 'churn.rb' do
      describe 'without limitations' do
        before do
          pid = ExecSandbox::Spawn.spawn [bin_fixture(:churn), @temp_path,
              3.to_s], {:err => STDERR}, {}, {}
          @status = ExecSandbox::Wait4.wait4 pid
        end

        it 'should not crash' do
          @status[:exit_code].should == 0
        end
        
        it 'should run for at least 2 seconds' do
          (@status[:user_time] + @status[:system_time]).should > 2
        end
        
        it 'should output something' do
          File.stat(@temp_path).size.should > 0
        end
      end
      
      describe 'with CPU time limitation' do
        before do
          pid = ExecSandbox::Spawn.spawn [bin_fixture(:churn), @temp_path,
              10.to_s], {}, {}, {:cpu => 1}
          @status = ExecSandbox::Wait4.wait4 pid
        end

        it 'should run for at least 0.5 seconds' do
          (@status[:user_time] + @status[:system_time]).should >= 0.5
        end

        it 'should run for less than 2 seconds' do
          (@status[:user_time] + @status[:system_time]).should < 2
        end
        
        it 'should not have a chance to output' do
          File.stat(@temp_path).size.should == 0
        end
      end
    end
  end
end
