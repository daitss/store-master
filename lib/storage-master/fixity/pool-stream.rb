require 'datyl/streams'
require 'fastercsv'
require 'net/http'
require 'storage-master/model'
require 'storage-master/exceptions'
require 'uri'

# Create a variety of sorted data streams from the silo-pool services keyed by package-name.

module Streams

  # Create a struct to contain individual pool fixity records: PoolFixityStream will return the
  # key/value pairs <String:package-name>, <Struct:PoolFixityRecord>

  Struct.new('PoolFixityRecord', :location, :sha1, :md5, :size, :fixity_time, :put_time, :status)

  # PoolFixityStream
  #
  # Return a stream of all of the fixity data from one pool.  The each
  # method yields two values, a package name and a struct describing
  # those resources:
  #
  #  EO05UJJHZ_HPDFHG.001 #<struct Struct::PoolFixityRecord location="http://silos.ripple.fcla.edu:70/001/data/EO05UJJHZ_HPDFHG.001", sha1="4abc7ec5f02b946dc4812f0b60bda34940ae62f3", md5="0d736ef6585b44bf0552a61b95ad9b87", size="1313843200", fixity_time="2011-04-27T11:38:30Z", put_time="2011-04-20T20:21:33Z", status="ok">
  #  EQ93PZGKM_ER3H8G.000 #<struct Struct::PoolFixityRecord location="http://silos.ripple.fcla.edu:70/001/data/EQ93PZGKM_ER3H8G.000", sha1="a6ec8b7415e1a4fdfacbd42d1a7c0e3435ea2dd4", md5="c9672d29178ee51eafef97a4b8297a5b", size="587591680", fixity_time="2011-04-27T11:38:45Z", put_time="2011-04-20T22:08:41Z", status="ok">
  #  ESKMPS0TO_7W4ASP.000 #<struct Struct::PoolFixityRecord location="http://silos.ripple.fcla.edu:70/001/data/ESKMPS0TO_7W4ASP.000", sha1="a1bc6134dbc4dc0beffa94235f470bb7e0e8a016", md5="9fc127a90ec6c02b094d6f656f74232c", size="1003280384", fixity_time="2011-04-27T11:39:11Z", put_time="2011-04-21T14:20:13Z", status="ok">
  #
  # In the interest of speed the location and timestamp fields are simple strings (not a URI and DateTime as you might expect)

  class PoolFixityStream < DataFileStream

    attr_reader :url


    # The optional stored_before must produce a valid datetime when it's 'to_s' method is called
    # TODO:  the stored_before query parameter is a bad way of doing things - need to be more HATEOS-driven.

    def initialize pool, options = {}
      file = Tempfile.new("pool-fixity-data-#{pool.name}-")
      @url = pool.fixity_url

      params = []
      options.each { |k, v|  params.push URI.escape("#{k}=#{v}") }

      @url.query = params.join('&') unless params.empty?

      get_request = Net::HTTP::Get.new(@url.request_uri)
      get_request.basic_auth(@url.user, @url.password) if url.user or url.password

      http = Net::HTTP.new(@url.host, @url.port)
      http.open_timeout = 60 * 15
      http.read_timeout = 60 * 60

      http.request(get_request) do |response|
        raise StorageMaster::ConfigurationError, "Bad response when contacting the silo at #{url}, response was #{response.code} #{response.message}." unless response.code == '200'
        response.read_body { |buff| file.write buff }
      end
      file.rewind
      file.gets        # remove initial CSV title "name","location","sha1","md5","size","fixity_time","put_time","status"
      super(file)

    rescue StorageMaster::ConfigurationError => e
      raise
    rescue Exception => e
      raise "Error initializing pool data from #{@url}: #{e.class} - #{e.message}"
    end

    def rewind
      super
      @io.gets        # remove initial CSV title "name","location","sha1","md5","size","fixity_time","put_time","status"
      self
    end
    

    def to_s
      "#<#{self.class} #{@url}>"
    end

    # The CSV data returned by the above HTTP request is of the form:
    #
    #   "name","location","sha1","md5","size","fixity_time","put_time","status"
    #   "E20110420_OOJGPX.000","http://silos.ripple.fcla.edu:70/004/data/E20110420_OOJGPX.000","a5ffd229992586461450851d434e3ce51debb626","15e4aeae105dc0cfc8edb2dd4c79454e","8192","2011-04-27T11:36:03Z","2011-04-20T17:25:58Z","ok"
    #   "E20110420_OOKCET.000","http://silos.ripple.fcla.edu:70/004/data/E20110420_OOKCET.000","a5ffd229992586461450851d434e3ce51debb626","15e4aeae105dc0cfc8edb2dd4c79454e","8192","2011-04-27T11:36:03Z","2011-04-20T17:26:02Z","ok"
    #   "E20110420_OOKUHK.000","http://silos.ripple.fcla.edu:70/004/data/E20110420_OOKUHK.000","a5ffd229992586461450851d434e3ce51debb626","15e4aeae105dc0cfc8edb2dd4c79454e","8192","2011-04-27T11:36:04Z","2011-04-20T17:26:06Z","ok"
    #  ...
    # key = name;  value = [ location, sha1, md5, date, status ]

    def read
      rec = CSV.parse_line(@io.gets)
      return rec.shift, Struct::PoolFixityRecord.new(*rec)
    end

  end # of class PoolFixityStream


  # PoolFixityRecordContainer
  #
  # A specialized array to hold collections of the PoolFixityRecords
  # returned by the above; PoolMultiFixities will return these
  # arrays. This array provides convenience methods that map over all
  # the records in the array.

  class PoolFixityRecordContainer < Array

    # A boolean that indicates that, for a given field, whether all the
    # PoolFixityRecords in the container have the same value. Use with
    # with a field of :size, :md5 or :sha1

    def consistent? field
      self.map{ |elt| elt.send field }.uniq.length == 1
    rescue => e
      nil
    end

    # A boolean that indicates the give field isn't consistent

    def inconsistent? field
      not consistent? field
    rescue => e
      nil
    end

  end # of class PoolFixityRecordContainer

  # PoolMultiFixities
  #
  # Return a stream of key/value pairs that folds the data from a
  # number of PoolFixityStreams.  It uses the same key (namely, the
  # package-name, a string) and the value is a specialized array of
  # the structs from the constituent PoolFixityStream values. The
  # arrays are homogenous in the type of elements (namely,
  # PoolFixityRecords) but may well vary in the number of elements (of
  # which there will be from one to the number of streams).
  #
  # This stream is used to determine both the consisitency of fixities
  # across muiltiple pools, as well as confirming the required number of copies
  # of packages across those pools.

  class PoolMultiFixities < MultiStream
    def initialize streams
      @values_container = PoolFixityRecordContainer
      @streams = streams.map { |stream| UniqueStream.new(stream.rewind) }
    end
  end


  # StoreUrlMultiFixities
  #
  # Just like PoolMultiFixities, but we return the storage master's URL for the package as
  # the key, e.g http://storage-master.com/packages/EZQQYQMC2_6PYZMQ.000 instead of EZQQYQMC2_6PYZMQ.000

  class StoreUrlMultiFixities < MultiStream

    def initialize streams
      if StorageMasterModel::Package.server_location.nil?
        raise StorageMaster::ConfigurationError, "The storage master data has not been completely set up; use StorageMasterModel::Package.server_location = <http://server.example.com>/"
      end
      @values_container = PoolFixityRecordContainer
      @streams = streams.map { |stream| UniqueStream.new(stream.rewind) }
      @prefix = StorageMasterModel::Package.server_location + '/packages/'
    end


    def get
      k, v = super
      return if k.nil?
      return @prefix + k, v
    end
  end


end # of module Streams
