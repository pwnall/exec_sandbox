require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe ExecSandbox::Users do
  let(:test_user) { 'exec_sandbox_rspec' }
  let(:test_group) { Etc.getgrgid(Etc.getpwnam(Etc.getlogin).gid).name }
  let(:current_user) { Etc.getlogin }
  
  describe '#temp' do
    before { @user_name = ExecSandbox::Users.temp 'exsbx.rspec' }
    after { ExecSandbox::Users.destroy @user_name }
    
    it 'should create a user whose name starts with the prefix' do
      @user_name.should match(/^exsbx\.rspec/)
    end

    it 'should create a user' do
      Etc.getpwnam(@user_name).should_not be_nil
    end
    
    it 'should create a group with the same name' do
      Etc.getgrgid(Etc.getpwnam(@user_name).gid).name.should == @user_name
    end
    
    it 'should create a home directory for the user' do
      File.exist?(Etc.getpwnam(@user_name).dir).should be_true
    end
  end
  
  describe '#create' do    
    shared_examples_for 'user creation' do
      it 'should return the UID of a user with the right name' do
        Etc.getpwuid(@uid).name.should == test_user
      end
  
      it "should create the new user's home directory" do
        File.exist?(Etc.getpwuid(@uid).dir).should be_true
      end

      it "should have the new user's name in its home directory" do
        Etc.getpwuid(@uid).dir.should match(test_user)
      end
    end
    
    describe 'with no group' do
      before do
        @uid = ExecSandbox::Users.create test_user
      end
      
      after do
        ExecSandbox::Users.destroy test_user
      end
      
      it_should_behave_like 'user creation'

      it "should create a group with the user's name" do
        Etc.getgrnam(test_user).should_not be_nil
      end
      
      it "should set the new user's GID to the group" do
        Etc.getpwuid(@uid).gid.should == Etc.getgrnam(test_user).gid
      end
    end
    
    describe 'with given group' do
      before do
        @uid = ExecSandbox::Users.create test_user, test_group
      end
      
      after do
        ExecSandbox::Users.destroy test_user
      end
      
      it_should_behave_like 'user creation'
  
      it "should not create a group with the user's name" do
        lambda {
          Etc.getgrnam(test_user)
        }.should raise_error(ArgumentError)
      end
      
      it "should set the new user's GID to the correct group" do
        Etc.getpwuid(@uid).gid.should == Etc.getgrnam(test_group).gid
      end
    end
  end
  
  describe '#destroy' do
    describe 'with single-use group' do
      before do
        ExecSandbox::Users.create test_user
        @home_dir = Etc.getpwnam(test_user)
        ExecSandbox::Users.destroy test_user
      end
      
      it 'should remove the user' do
        lambda {
          Etc.getpwnam(test_user)
        }.should raise_error(ArgumentError)
      end
  
      it "should remove the user's group" do
        lambda {
          Etc.getgrnam(test_user)
        }.should raise_error(ArgumentError)
      end
    end
    
    describe 'delete_user with shared group' do
      before do
        ExecSandbox::Users.create test_user, test_group
        @home_dir = Etc.getpwnam(test_user)
        ExecSandbox::Users.destroy test_user
      end
      
      it 'should remove the user' do
        lambda {
          Etc.getpwnam(test_user)
        }.should raise_error(ArgumentError)
      end
  
      it "should not remove the generic group" do
        Etc.getgrnam(test_group).should_not be_nil
      end
    end
  end
  
  describe '#named' do
    describe 'with non-matching RegExp' do
      it 'should not return any user' do
        ExecSandbox::Users.named(/exec_sandbox_rspec/).should be_empty
      end
    end
    
    describe 'with non-matching String' do
      it 'should not return any user' do
        ExecSandbox::Users.named(/exec_sandbox_rspec/).should be_empty
      end
    end
    
    describe 'with the name of the current user' do
      it 'should return the current user' do
        ExecSandbox::Users.named(current_user).should == [current_user]
      end
    end
    
    describe 'with RegExp matching one user' do
      before do
        ExecSandbox::Users.create test_user, test_group
      end      
      after do
        ExecSandbox::Users.destroy test_user
      end
      it 'should return that one user' do
        ExecSandbox::Users.named(/exec.sandbox.rspe/).should ==
            ['exec_sandbox_rspec']
      end
    end
  end
  
  describe '#destroy_temps' do
    let(:temp_prefix) { 'exsbx.rspec' }    

    before do
      @all_users = ExecSandbox::Users.named(/.*/).sort
    end
    
    describe 'in a system with no temps' do
      before do
        @removed = ExecSandbox::Users.destroy_temps temp_prefix
      end
      
      it 'should not remove any users' do
        ExecSandbox::Users.named(/.*/).sort.should == @all_users
      end
      
      it 'should return an empty array' do
        @removed.should be_empty
      end
    end
    
    describe 'in a system with two temps' do
      before do
        @temp1 = ExecSandbox::Users.temp temp_prefix
        @temp2 = ExecSandbox::Users.temp temp_prefix
        
        @removed = ExecSandbox::Users.destroy_temps temp_prefix
      end

      it 'should only remove the two temps' do
        ExecSandbox::Users.named(/.*/).sort.should == @all_users
      end
            
      it 'should return the two temps' do
        @removed.sort.should == [@temp1, @temp2].sort
      end
    end
  end
end
