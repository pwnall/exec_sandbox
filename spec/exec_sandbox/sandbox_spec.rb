require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe ExecSandbox::Sandbox do  
  describe 'IO redirection' do
    before do
      @temp_in = Tempfile.new 'exec_sandbox_rspec'
      @temp_in.write "I/O test\n"
      @temp_in.close
      @temp_out = Tempfile.new 'exec_sandbox_rspec'
      @temp_out.close
      
      ExecSandbox.use do |s|
        @result = s.run bin_fixture(:duplicate), :in => @temp_in.path,
                                                 :out => @temp_out.path
      end
    end
    after do
      @temp_in.unlink
      @temp_out.unlink
    end

    it 'should not crash' do
      @result[:exit_code].should == 0
    end
    
    it 'should produce the correct result' do
      File.read(@temp_out.path).should == "I/O test\nI/O test\n" 
    end
  end
  
  describe 'pipe redirection' do
    describe 'duplicate.rb' do
      before do
        ExecSandbox.use do |s|
          @result = s.run bin_fixture(:duplicate), :in_data => "Pipe test\n"
        end
      end
      
      it 'should not crash' do
        @result[:exit_code].should == 0
      end
      
      it 'should produce the correct result' do
        @result[:out_data].should == "Pipe test\nPipe test\n"
      end
    end
    
    describe 'buffer.rb' do
      let(:buffer_size) { 1024 * 1024 }
      before do
        ExecSandbox.use do |s|
          @result = s.run [bin_fixture(:buffer), '', buffer_size.to_s]
        end
      end
      
      it 'should not crash' do
        @result[:exit_code].should == 0
      end
      
      it 'should produce the correct result' do
        @result[:out_data].should == "S" * buffer_size
      end
    end
  end
  
  
  describe 'resource limitations' do
    describe 'churn.rb' do
      before do
        @temp_out = Tempfile.new 'exec_sandbox_rspec'
        @temp_out.close
      end
      after do
        @temp_out.unlink
      end
      
      describe 'without limitations' do
        before do
          ExecSandbox.use do |s|
            @result = s.run [bin_fixture(:churn), 'stdout', 3.to_s]
            s.pull 'stdout', @temp_out.path
          end
        end
  
        it 'should not crash' do
          @result[:exit_code].should == 0
        end
        
        it 'should run for at least 2 seconds' do
          (@result[:user_time] + @result[:system_time]).should > 2
        end
        
        it 'should output something' do
          File.stat(@temp_out.path).size.should > 0
        end
      end
      
      describe 'with CPU time limitation' do
        before do
          ExecSandbox.use do |s|
            @result = s.run [bin_fixture(:churn), 'stdout', 3.to_s],
                            :limits => {:cpu => 1}
            s.pull 'stdout', @temp_out.path
          end
        end
  
        it 'should run for at least 0.5 seconds' do
          (@result[:user_time] + @result[:system_time]).should >= 0.5
        end
  
        it 'should run for less than 2 seconds' do
          (@result[:user_time] + @result[:system_time]).should < 2
        end
        
        it 'should not have a chance to output' do
          File.stat(@temp_out.path).size.should == 0
        end
      end
    end
  end
  
  describe '#push' do
    let(:test_user) { Etc.getlogin }
    let(:test_uid) { Etc.getpwnam(test_user).uid }
    let(:test_gid) { Etc.getpwnam(test_user).gid }
    let(:test_group) { Etc.getgrgid(test_gid).name }

    before do
      @sandbox = ExecSandbox.open test_user
    end
    after do
      @sandbox.close
    end
    
    describe 'a file' do
      before do
        @to = @sandbox.push __FILE__
      end
      
      it 'should copy straight to the sandbox directory' do
        File.dirname(@to).should == @sandbox.path
      end
      
      it 'should use the same file name' do
        File.basename(@to).should == 'sandbox_spec.rb' 
      end
      
      it "should set the file's owner to the admin" do
        File.stat(@to).uid.should == test_uid
      end
      
      it "should not set the file's group to the admin" do
        File.stat(@to).gid.should_not == test_gid
      end
    end
  end
end
