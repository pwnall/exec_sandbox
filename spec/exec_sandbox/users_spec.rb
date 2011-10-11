require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe ExecSandbox::Users do
  let(:test_user) { 'exec_sandbox_rspec' }
  let(:test_group) { Etc.getgrgid(Etc.getpwnam(Etc.getlogin).gid).name }
  
  describe '#create_user_named' do
    
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
        @uid = ExecSandbox::Users.create_user_named test_user
      end
      
      after do
        ExecSandbox::Users.destroy_user test_user
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
        @uid = ExecSandbox::Users.create_user_named test_user, test_group
      end
      
      after do
        ExecSandbox::Users.destroy_user test_user
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
  
  describe '#destroy_user' do
    describe 'with single-use group' do
      before do
        ExecSandbox::Users.create_user_named test_user
        @home_dir = Etc.getpwnam(test_user)
        ExecSandbox::Users.destroy_user test_user
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
        ExecSandbox::Users.create_user_named test_user, test_group
        @home_dir = Etc.getpwnam(test_user)
        ExecSandbox::Users.destroy_user test_user
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
end
