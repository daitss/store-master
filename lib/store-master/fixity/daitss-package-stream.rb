require 'datyl/streams'
require 'daitss/model'
require 'store-master/fixity/daitss-model-extensions'

module Streams

  # This data stream returns key/value pairs of fixity information as
  # known by DAITSS.  The keys are sorted, unique URLs (strings)
  # showing the store-master provided location.  The values are a
  # datamapper-provided struct giving the expected MD5, SHA1 and Size
  # of the package, as well as its IEID.
  #
  # 'http://betastore.tarchive.fcla.edu/packages/EZQQYQMC2_6PYZMQ.000' #<Struct::DataMapper ieid="EZQQYQMC2_6PYZMQ", url="http://betastore.tarchive.fcla.edu/packages/EZQQYQMC2_6PYZMQ.000", md5="7e45d204d270da0f8aab2a65f59a2429", sha1="e541c693e56edd9a7e04cab94de5740092ae3953", size=4761600>
  # 'http://betastore.tarchive.fcla.edu/packages/EZYNH5CZC_ZP2B9Y.000' #<Struct::DataMapper ieid="EZYNH5CZC_ZP2B9Y", url="http://betastore.tarchive.fcla.edu/packages/EZYNH5CZC_ZP2B9Y.000", md5="52076e3d8a9196d365c8381e135b6812", sha1="b046c58503f570ea090b8c5e46cc5f4e0c27f003", size=1962598400>
  # 'http://betastore.tarchive.fcla.edu/packages/EZYVXE2TV_J9MW69.000' #<Struct::DataMapper ieid="EZYVXE2TV_J9MW69", url="http://betastore.tarchive.fcla.edu/packages/EZYVXE2TV_J9MW69.000", md5="0959a55d2b6b46c4080bc85b10b87947", sha1="05fc20aaebad2708b91ad4c0d372ca733da7417a", size=2763468800>
  #  ...
  #

  class DaitssPackageStream
    
    include CommonStreamMethods

    # TODO: we might be better off maintaining an index into @ieids and keeping it around, rather than shifting
    # materials off and having to re-create it with another database hit.  We'll see after how it's used in practice.

    CHUNK_SIZE = 2000

    def initialize options = {}
      @before = options[:before] || DateTime.now
      setup
    end

    def rewind
      setup
      self
    end

    def to_s
      "#<#{self.class}##{self.object_id} IEIDs prior to #{@before}>"
    end

    def eos?
      @ieids.empty? and @buff.empty? and not @ungot
    end

    def get
      return if eos?

      if @ungot
        @ungot = false
        return @last.url, @last
      end

      if @buff.empty?
        @buff = Daitss::Package.package_copies @ieids.shift(CHUNK_SIZE)
      end

      @last = @buff.shift

      return @last.url, @last
    end

    def unget
      raise "The unget method only supports one level of unget; unfortunately, two consecutitve ungets have been called on #{self.to_s}" if @ungot
      @ungot = true
    end

    # closing is just for consistency; really a no-op

    def close
      @closed = true
    end

    def closed?
      @closed
    end

    private 

    def setup
      @ieids  = Daitss::Package.package_copies_ids @before
      @last   = nil
      @buff   = []
      @closed = false
      @ungot  = false
    end

  end # of class DaitssPackageStream

end # of module Streams
