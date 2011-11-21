require 'storage-master/fixity/utils'

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', 'lib')


describe FixityUtils do

  it "should properly pluralize" do

    FixityUtils.pluralize(0, 's', 'es').should == 'es'

    FixityUtils.pluralize(1, 's', 'es').should == 's'

    FixityUtils.pluralize(2, 's', 'es').should == 'es'
  end


end
