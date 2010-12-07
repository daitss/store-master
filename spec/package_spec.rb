$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), 'lib')) # for spec_helpers

require 'store/dm'
require 'store/package'
require 'store/pool'
require 'store/reservation'
require 'fileutils'
require 'spec_helpers'
require 'digest/md5'
require 'digest/sha1'


# Note that failing tests can leave orphaned junk on the silos that will need to bne cleaned
# out before proceeding, e.g.
#
#  curl -X DELETE http://storage.local/b/data/E20080805_AAAAAM.000
#  curl -X DELETE http://storage.local/b/data/E20080805_AAAAAM.001
#  ...

def datamapper_setup
  DM.setup(File.join(File.dirname(__FILE__), 'db.yml'), 'store_master_mysql')
  DM.recreate_tables
end

def active_silos
  # [ 'http://storage.local/store-master-test-silo-1/data/', 'http://storage.local/store-master-test-silo-2/data/' ]
  # [ 'http://silos.sake.fcla.edu/002/data/', 'http://silos.sake.fcla.edu/003/data/' ]

  [ 'http://storage.local:2001/a/data/', 'http://storage.local:2001/b/data/' ]
end

@@IEID = ieid()

def ieid
  @@IEID
end

def sample_tarfile_path 
  File.join(File.dirname(__FILE__), 'lib', 'E20080805_AAAAAM.tar')
end

def sample_tarfile
  File.open sample_tarfile_path
end

@@MD5  = Digest::MD5.hexdigest(sample_tarfile.read)
@@SHA1 = Digest::SHA1.hexdigest(sample_tarfile.read)
@@SIZE = File.stat(sample_tarfile_path).size

def sample_metadata name
  { :ieid => ieid, :type => 'application/x-tar', :size => @@SIZE, :md5 => @@MD5, :name => name }
end

def resource_exists? url
  `curl -s #{url} >& /dev/null`
  $? == 0
end

# size of longest common substring from http://en.wikibooks.org/wiki/Algorithm_Implementation/Strings/Longest_common_subsequence

def lcs_size(s1, s2)
  num=Array.new(s1.size){Array.new(s2.size)}
  len,ans=0 
  s1.scan(/./).each_with_index do |l1,i |
    s2.scan(/./).each_with_index do |l2,j |
 
      unless l1==l2
        num[i][j]=0
      else
        (i==0 || j==0)? num[i][j]=1 : num[i][j]=1 + num[i-1][j-1]
        len = ans = num[i][j] if num[i][j] > len
      end
    end
  end 
  ans
end

def index_of_pool_that_best_matches_url(pools, url)

  # get a list of [ index, length ] pairs, where length is the size of
  # the longest-common-substring computed between the pool location
  # and the url passed as argument.

  pool_ranks    = []
  pools.each_with_index { |p, i| pool_ranks.push [ i, lcs_size(p.put_location, url) ] }

  # sort list by length longest common substring, largest first - so:
  # [ [0, 23], [1, 28], [3, 0] ]    =>     [ [1, 28], [0, 23], [3, 0] ]

  pool_ranks.sort! { |a, b|   b[1] <=> a[1] }  

  # return the pool index that had the best (longest) match:
  pool_ranks[0][0]
end


@@all_package_names = []

@@silos_available = nil

def nimby
  case @@silos_available

  when nil
    @@silos_available = true
    active_silos.each do |silo|
      @@silos_available &&= resource_exists?(silo)
    end
    nimby

  when true
    
  when false
    pending "No active silos are available; can't run this test"
  end
end

describe Store::Package do

  before(:all) do
    datamapper_setup
    active_silos.each { |silo| Store::Pool.create(silo) }
  end

  it "should let us determine that a package doesn't exist" do
    name = ieid + '.000'
    Store::Package.exists?(name).should == false
  end
    
  it "should not let us retrieve an unsaved package" do
    name = ieid + '.000'
    pkg = Store::Package.lookup(name)
    pkg.nil? == true
  end

  it "should let us create a package" do
    nimby

    name   = Store::Reservation.new(ieid).name
    metadata = sample_metadata(name)

    io  = sample_tarfile
    pkg = Store::Package.create(io, metadata, Store::Pool.list_active)
    pkg.name.should == name
    pkg.md5.should   == @@MD5
    pkg.sha1.should  == @@SHA1
    pkg.size.should  == @@SIZE

    @@all_package_names.push name
  end

  it "should let us determine that a recorded package exists" do
    nimby
    last_saved_package = @@all_package_names[-1]
    Store::Package.exists?(last_saved_package).should == true
  end


  it "should let us retrieve a saved package" do
    nimby
    last_saved_package = @@all_package_names[-1]
    pkg = Store::Package.lookup(last_saved_package)
    pkg.name.should == last_saved_package
  end

  it "should not let us recreate a package with an existing name" do
    nimby
    lambda { Store::Package.create(sample_tarfile, sample_metadata(name), Store::Pool.list_active) }.should raise_error
  end

  it "should let us retrieve the locations of copies of a stored package" do    
    nimby
    res = Store::Reservation.new(ieid);  @@all_package_names.push res.name
    pkg = Store::Package.create(sample_tarfile, sample_metadata(res.name), Store::Pool.list_active)

    pkg.locations.length.should == active_silos.length

    pkg.locations.each do |copy| 
      found = false
      active_silos.each { |silo|  found ||= (not (copy =~ /^#{silo}/).nil?) }   # found stays true once 'copy' includes the silo
      found.should == true   
    end    
  end


  it "should order the list of locations for a package based on the pool's read_preference" do
    nimby

    # setup some package data

    pools = Store::Pool.list_active
    name   = Store::Reservation.new(ieid).name
    pkg = Store::Package.create(sample_tarfile, sample_metadata(name), pools)
    pkg.name.should == name
    @@all_package_names.push name

    pools.length.should >= 2  # test won't mean much with out at least two pools

    # adjust preferences - higher value means more preferred - and check to see
    # if that forces the pool to the top of the list

    pools.each { |p| p.read_preference = 0 }

    pools[0].read_preference = 10
    index_of_pool_that_best_matches_url(pools, pkg.locations.shift).should == 0

    pools[1].read_preference = 20
    index_of_pool_that_best_matches_url(pools, pkg.locations.shift).should == 1

  end

  it "should list all of the package names we've stored" do    
    (Store::Package.names - @@all_package_names).should == []
    (@@all_package_names - Store::Package.names).should == []
  end


  it "should allow us to delete packages" do

    # get all the locations for all the names

    @@all_package_names.each do |name|
      Store::Package.exists?(name).should == true
      pkg = Store::Package.lookup(name)
      pkg.nil?.should == false
      pkg.delete
      Store::Package.exists?(name).should == false
    end
  end

end
