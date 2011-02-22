require 'datyl/streams'
require 'fastercsv'
require 'net/http'
require 'store-master/model.rb'

# Create a variety of sorted data streams from the silo-pool services keyed by package-name.
# This returns what the silos have, not what store-master thinks they have.

module Streams

  # TODO: can we get rid of timestamp and thus speed this up a bit?

  # Create a struct to contain individual pool fixity records: PoolFixityStream will return the
  # key/value pairs <String:package-name>, <Struct:PoolFixityRecord>

  Struct.new('PoolFixityRecord', :location, :sha1, :md5, :timestamp, :status)

  # PoolFixityStream 
  #
  # Return a stream of all of the fixity data from one pool.  The each
  # method yields two values, a package name and a struct describing
  # those resources:
  #
  # E20110129_CYXBHO.000, #<struct Struct::PoolFixityRecord location="http://pool.b.local/silo-pool.b.1/data/E20110129_CYXBHO.000", sha1="ccd53fa068173b4f5e52e55e3f1e863fc0e0c201", md5="4732518c5fe6dbeb8429cdda11d65c3d", timestamp="2011-01-29T02:43:50-05:00", status="ok">
  # E20110129_CYYJLZ.001, #<struct Struct::PoolFixityRecord location="http://pool.b.local/silo-pool.b.1/data/E20110129_CYYJLZ.001", sha1="249fcdac02c9d1265a66d309c7679e89ba16be2d", md5="c6aed85f0ef29ceea5c0d032eeb8fcc6", timestamp="2011-02-02T12:05:22-05:00", status="ok">
  # E20110129_CYZBEK.000, #<struct Struct::PoolFixityRecord location="http://pool.b.local/silo-pool.b.1/data/E20110129_CYZBEK.000", sha1="da39a3ee5e6b4b0d3255bfef95601890afd80709", md5="d41d8cd98f00b204e9800998ecf8427e", timestamp="2011-01-29T02:43:53-05:00", status="ok">
  #
  # In the interest of speed the location and timestamp fields are simple strings (not a URI and DateTime as you might expect)

  class PoolFixityStream < DataFileStream

    attr_reader :url

    def initialize pool    

      file = Tempfile.new("pool-fixity-data-#{pool.name}-")
      @url = pool.fixity_url

      get_request = Net::HTTP::Get.new(@url.path)
      get_request.basic_auth(@url.user, @url.password) if url.user or url.password

      http = Net::HTTP.new(@url.host, @url.port)
      http.open_timeout = 60 * 2
      http.read_timeout = 60 * 10  # TODO: get some perfomance metrics on this
      
      http.request(get_request) do |response|
        raise StoreMaster::ConfigurationError, "Bad response when contacting the silo at #{url}, response was #{response.code} #{response.message}." unless response.code == '200'
        response.read_body do |buff|
          next if buff =~ /"name",/
          file.write buff
        end
      end
      file.rewind
      super(file)
    end

    def to_s
      "#<#{self.class}##{self.object_id} #{@url}>"   # TODO: double check that URL is properly sanitized
    end

    # The CSV data returned by the above HTTP request is of the form:
    #
    # "E20110127_OEFCIO.000","http://pool.a.local/silo-pool.a.2/data/E20110127_OEFCIO.000","a5ffd229992586461450851d434e3ce51debb626","15e4aeae105dc0cfc8edb2dd4c79454e","2011-01-27T13:04:27-05:00","ok"
    # "E20110127_OPAHSG.000","http://pool.a.local/silo-pool.a.2/data/E20110127_OPAHSG.000","a5ffd229992586461450851d434e3ce51debb626","15e4aeae105dc0cfc8edb2dd4c79454e","2011-01-27T13:27:55-05:00","ok"
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
  # Just like PoolMultiFixities, but we return the storemaster's URL for the package as
  # the key, e.g http://store-master.com/packages/EZQQYQMC2_6PYZMQ.000 instead of EZQQYQMC2_6PYZMQ.000

  class StoreUrlMultiFixities < MultiStream

    def initialize streams
      @values_container = PoolFixityRecordContainer    
      @streams = streams.map { |stream| UniqueStream.new(stream.rewind) }
      @prefix = StoreMasterModel::Package.server_location + '/packages/'
    end

    def get
      k, v = super
      return if k.nil?
      return @prefix + k, v
    end
  end
    

end # of module Streams
