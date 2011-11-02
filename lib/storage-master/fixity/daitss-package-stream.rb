require 'datyl/streams'
require 'daitss/model'
require 'storage-master/fixity/daitss-model-extensions'

module Streams

  # This data stream returns key/value pairs of fixity information as
  # known by DAITSS.  The keys are sorted, unique URLs (strings)
  # showing the storage-master provided location.  The values are a
  # datamapper-provided struct giving the expected MD5, SHA1 and Size
  # of the package, as well as its IEID.
  #
  # "http://storage-master.fda.fcla.edu:70/packages/E101W4TQQ_VGD9QW.000",  #<struct ieid="E101W4TQQ_VGD9QW", url="http://storage-master.fda.fcla.edu:70/packages/E101W4TQQ_VGD9QW.000", last_successful_fixity_time="2011-10-02T03:38:38Z", package_store_time="2011-09-19T18:19:52Z", md5="f1b797725b64c4a06a81bcfac0c1f077", sha1="1a6f80fd868cda45e6f8413f8fc9dbd9c081f3f9", size=9256960>
  # "http://storage-master.fda.fcla.edu:70/packages/E104GJTXL_KZQB6L.000",  #<struct ieid="E104GJTXL_KZQB6L", url="http://storage-master.fda.fcla.edu:70/packages/E104GJTXL_KZQB6L.000", last_successful_fixity_time="2011-09-30T10:39:50Z", package_store_time="2011-07-28T12:05:46Z", md5="c2e481ca90d60674b2de2a1279eb2dc6", sha1="c97a9aeba05f84461be8e73fa124b4435e4fea50", size=54087680>
  # "http://storage-master.fda.fcla.edu:70/packages/E1095RV78_SZTIN2.000",  #<struct ieid="E1095RV78_SZTIN2", url="http://storage-master.fda.fcla.edu:70/packages/E1095RV78_SZTIN2.000", last_successful_fixity_time="2011-10-09T20:22:43Z", package_store_time="2011-06-02T05:06:19Z", md5="1203fd48d996a1baf3bc93ea4543d5ea", sha1="781c8b17429c3353c93464ffe0b0484549979de2", size=1572372480>
  #  ...

  class DaitssPackageStream
    
    include CommonStreamMethods

    def initialize options = {}
      @before = options[:before] || DateTime.now
      setup
    end

    def rewind
      setup
      self
    end

    def to_s
      "#<#{self.class} IEIDs prior to #{@before}>"
    end

    def eos?
      return false if ungetting?
      return @buff.empty?
    end
    
    def read 
      return if eos?
      return if @buff.empty?

      datum = @buff.shift
      return datum.url, datum
    end

    private 

    def setup
      @buff  = Daitss::Package.package_copies @before
    end

  end # of class DaitssPackageStream

end # of module Streams


