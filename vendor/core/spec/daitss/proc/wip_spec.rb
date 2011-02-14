require 'daitss/proc/wip'
require 'uuid'

# Proto AIP: Work In Progress
describe Wip do

  subject do
    id = UUID.generate :compact
    p = Package.new
    p.uri = UUID.generate :urn
    ac = Account.get Daitss::Archive::SYSTEM_ACCOUNT_ID
    pr = ac.projects.first :id => Daitss::Archive::DEFAULT_PROJECT_ID
    p.project = pr
    p.sip = Sip.new :name => "foo"
    p.save or raise "cant save package"
    path = File.join archive.workspace.path, p.id
    Wip.make path, :disseminate
  end

  it "should let addition of new files" do
    df = subject.new_original_datafile 0
    df.open('w') { |io| io.write 'foo' }
    df.open { |io| io.read }.should == 'foo'
  end

  it "should not let the addition of existing datafiles" do
    subject.new_original_datafile 0
    lambda { subject.new_original_datafile 0 }.should raise_error(/datafile 0 already exists/)
  end

  it "should let addition of new metadata" do
    subject['submit-event'] = "submitted at #{Time.now}"
    wip_prime = Daitss.archive.workspace[subject.id]
    subject['submit-event'].should == wip_prime['submit-event']
  end

  it "should equal a wip with the same path" do
    other = Wip.new subject.path
    subject.should == other
  end

  it "should not equal a wip with a different path" do
    uuid = UUID.generate :compact
    path = File.join $sandbox, uuid
    wip = Wip.make path, :disseminate
    subject.should_not == wip
  end

end
