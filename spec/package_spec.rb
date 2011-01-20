$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), 'lib')) # for spec_helpers

require 'store-master/data-model'
require 'fileutils'
require 'spec_helpers'
require 'digest/md5'
require 'digest/sha1'

# store-master needs a few pools, on my development host I've set two up,
# pool.a.local and pool.b.local - each is made up of two silos, defined
# as .dmg images 
#


# Note that failing tests can leave orphaned junk on the silos that will need to be cleaned
# out before proceeding, e.g.
#
#  curl -X DELETE http://storage.local/b/data/E20080805_AAAAAM.000
#  curl -X DELETE http://storage.local/b/data/E20080805_AAAAAM.001
#  ...
#
# something like this may help:
#
# #!/bin/sh
#
# for s in http://pool.a.local/silo-pool.a.1 http://pool.a.local/silo-pool.a.2 http://pool.b.local/silo-pool.b.1  http://pool.b.local/silo-pool.b.2; do
#   for p in `curl -s $s/fixity/ | grep FIXITY  | cut -d\" -f2`; do
#     echo curl -s -X DELETE $s/data/$p
#     curl -s -X DELETE $s/data/$p
#   done
# done

include DataModel

def datamapper_setup
  ## DataMapper::Logger.new(STDERR, :debug)

  DataModel.setup(File.join(File.dirname(__FILE__), 'db.yml'), 'store_master_postgres')
  DataModel.recreate_tables
end

def test_pools
  # [ 'http://storage.local/store-master-test-silo-1/data/', 'http://storage.local/store-master-test-silo-2/data/' ]
  # [ 'http://silos.sake.fcla.edu/002/data/', 'http://silos.sake.fcla.edu/003/data/' ]

  [ 'http://pool.a.local/services', 'http://pool.b.local/services' ]
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

  ### STDERR.puts 'index of...', pools[0].inspect, pools[1].inspect, url, ''
  pools.each_with_index { |p, i| pool_ranks.push [ i, lcs_size(p.services_location, url) ] }

  # sort list by length longest common substring, largest first - so:
  # [ [0, 23], [1, 28], [3, 0] ]    =>     [ [1, 28], [0, 23], [3, 0] ]

  ### STDERR.puts pool_ranks.inspect
  pool_ranks.sort! { |a, b|   b[1] <=> a[1] }  

  # return the pool index that had the best (longest) match:
  pool_ranks[0][0]
end


@@all_package_names = []

def nimby
  pending "No active pools are available; can't run this test" unless test_pools
  test_pools.each do |p| 
    pending "Configured pool #{p} is not reachable" unless resource_exists? p
  end
end


describe Package do

  before(:all) do
    datamapper_setup
    test_pools.each { |pool| Pool.add(pool) }
  end

  it "should let us determine that a package doesn't exist" do
    name = ieid + '.000'
    Package.exists?(name).should == false
  end
    
  it "should not let us retrieve an unsaved package" do
    name = ieid + '.000'
    pkg = Package.lookup(name)
    pkg.nil? == true
  end

  it "should let us create a package" do
    nimby

    name   = Reservation.make(ieid)
    metadata = sample_metadata(name)

    io  = sample_tarfile
    pkg = Package.store(io, metadata)
    pkg.name.should == name
    pkg.md5.should   == @@MD5
    pkg.sha1.should  == @@SHA1
    pkg.size.should  == @@SIZE

    @@all_package_names.push name
  end

  it "should let us determine that a recorded package exists" do
    nimby
    last_saved_package = @@all_package_names[-1]
    Package.exists?(last_saved_package).should == true
  end


  it "should let us retrieve a saved package" do
    nimby
    last_saved_package = @@all_package_names[-1]
    pkg = Package.lookup(last_saved_package)
    pkg.name.should == last_saved_package
  end

  it "should not let us recreate a package with an existing name" do
    nimby
    lambda { Package.store(sample_tarfile, sample_metadata(name)) }.should raise_error
  end

  it "should let us retrieve the locations of copies of a stored package" do    
    nimby

    name = Reservation.make(ieid);  @@all_package_names.push name
    pkg  = Package.store(sample_tarfile, sample_metadata(name))
    pkg.locations.length.should == test_pools.length
  end


  it "should order the list of locations for a package based on the pool's read_preference" do
    nimby

    pools = Pool.list_active
    pending "This test requires 2 or more pools, skipping"  unless pools.length >= 2  

    name  = Reservation.make(ieid)
    pkg   = Package.store(sample_tarfile, sample_metadata(name))

    pkg.name.should == name
    @@all_package_names.push name

    # adjust preferences - higher value means more preferred - and check to see
    # if that forces the pool to the top of the list

    pools.each { |p| p.assign :read_preference, 0 }

    #### STDERR.puts '', pools[0].inspect, pools[1].inspect, '', pkg.copies[0].pool.inspect, pkg.copies[1].pool.inspect, ''

    pools[0].assign :read_preference, 10  

    ### STDERR.puts '', pools[0].inspect, pools[1].inspect, '', pkg.copies[0].pool.inspect, pkg.copies[1].pool.inspect, ''

    index_of_pool_that_best_matches_url(pools, pkg.locations[0].to_s).should == 0

    pools[1].assign :read_preference, 20

    ### STDERR.puts '', pools[0].inspect, pools[1].inspect, '', pkg.copies[0].pool.inspect, pkg.copies[1].pool.inspect, ''

    index_of_pool_that_best_matches_url(pools, pkg.locations[0].to_s).should == 1
  end

  it "should list all of the package names we've stored" do    
    (Package.names - @@all_package_names).should == []
    (@@all_package_names - Package.names).should == []
  end


  it "should allow us to delete packages" do

    # get all the locations for all the names

    @@all_package_names.each do |name|
      Package.exists?(name).should == true
      pkg = Package.lookup(name)
      pkg.nil?.should == false
      pkg.delete
      Package.exists?(name).should == false
    end
  end

end
