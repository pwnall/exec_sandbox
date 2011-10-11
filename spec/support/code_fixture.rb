# Path to one of the fixture code files.
#
# @param [Symbol] fixture_id the name of the code file
# @return [String] fully-qualified path to the code file
def bin_fixture(fixture_id)
  File.expand_path "#{File.dirname(__FILE__)}/../fixtures/#{fixture_id.to_s}.rb"
end
