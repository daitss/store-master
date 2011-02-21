require 'datyl/reporter'
require 'datyl/streams'
require 'store-master/fixity/pool-stream'
require 'store-master/fixity/utils'

# Analyzers run checks over various pool and daitss fixity data
# streams; it produces reports listing warnings and errors that are
# provided for later printing or mailing; if logging has been
# initialized the reporter objects will log messages as appropriate.
#
# Analyzer objects have at least two public methods:
#
#  * run - Runs an analysis over one or more data streams, populating reporter objects with messages. Returns the analysis object itself.
#  * reports - Returns an array containing the reports generated during the run.


module Analyzer

  # IntraPoolAnalyzer
  #
  # Initialize with an array of streams, one for each of our pools.
  # Check each pool for internal consistency, which here means we have
  # exacly one fixity record for each package (no redundant packages
  # in a silo-pool)

  class IntraPoolAnalyzer

    # Recall that each of the PoolFixityStreamss given to us yield key/value pairs:
    # <String::package>, <Struct::PoolFixityRecord>, e.g.
    #
    # E20110129_CYXBHO.000, #<Struct::PoolFixityRecord location="http://pool.b.local/silo-pool.b.1/data/E20110129_CYXBHO.000", sha1="ccd53fa068173b4f5e52e55e3f1e863fc0e0c201", md5="4732518c5fe6dbeb8429cdda11d65c3d", timestamp="2011-01-29T02:43:50-05:00", status="ok">
    #
    # All fields within the struct are simple strings.

    attr_reader :reports

    def initialize pool_fixity_streams, max_days
      @expiration_date = (DateTime.now - max_days).to_s
      @pool_fixity_streams  = pool_fixity_streams

      @redundant_package_report = Reporter.new("Multiple Packages Within A Pool")
      @expired_fixity_report    = Reporter.new("Packages With Expired Fixities (Older Than #{max_days} Days)")
      @bad_status_report        = Reporter.new("Packages With Bad Fixity Status (From Silo Pool Data)")

      @reports = [ @redundant_package_report, @expired_fixity_report, @bad_status_report ]
    end

    def run
      @pool_fixity_streams.each do |pool_fixity_stream|

        pool_fixity_stream.rewind.each do |package_name, fixity_record|
          if fixity_record.status != 'ok'
            @bad_status_report.err "#{fixity_record.location} has fixity status #{fixity_record.status}, last checked #{Time.parse(fixity_record.timestamp).asctime}"
          end

          if fixity_record.timestamp < @expiration_date
            @expired_fixity_report.warn "#{fixity_record.location} fixity expired #{((Time.now - Time.parse(fixity_record.timestamp))/(60 * 60 * 24)).to_i} days ago"
          end
        end
      end

      @pool_fixity_streams.each do |pool_fixity_stream|
        Streams::FoldedStream.new(pool_fixity_stream.rewind).each do |package_name, fixity_records|      # fold values for identical keys into one array
          if fixity_records.count > 1
            @redundant_package_report.warn "#{package_name} #{fixity_records.map { |rec| rec.location }.join(', ')}"
          end
        end
      end
      self
    end

  end # of class IntraPoolAnalyzer

  # InterPoolAnalyzer
  #
  # As above, we initialize with an array of streams, one for each of our pools.  Here, however
  # consistency,  which here means we have exacly one fixity record for each package (no redundant
  # packages in a silo-pool)

  class InterPoolAnalyzer

    attr_reader :reports

    def initialize pool_fixity_streams, required_copies
      @pool_fixity_streams  = pool_fixity_streams
      @required_copies      = required_copies
      @report_wrong_number  = Reporter.new "Packages Not Having The Required #{@required_copies} #{FixityUtils.pluralize(@required_copies, 'Copy', 'Copies')} In Pools"
      @report_copy_mismatch = Reporter.new "Packages Having Mismatched SHA1, MD5 Or Sizes Between The Silo Pools"
      @reports              = [ @report_wrong_number, @report_copy_mismatch ]
    end

    def run
      Streams::PoolMultiFixities.new(@pool_fixity_streams).each do |name, pool_records|

        if pool_records.count < @required_copies
          @report_wrong_number.err  "#{name} has too few copies - found only #{FixityUtils.pluralize(pool_records.count, 'this copy', 'these copies')} in the pools: #{pool_records.map{ |p| p.location}.sort.join(', ')}"
        elsif pool_records.count > @required_copies
          @report_wrong_number.ward "#{name} has too many #{FixityUtils.pluralize(pool_records.count, 'copy', 'copies')} in our pools: #{pool_records.map{ |p| p.location }.sort.join(', ')}"
        end

        @report_copy_mismatch.warn "SHA1 mismatch for #{name}: " +  pool_records.map { |p|  "#{p.location} has #{p.sha1}" }.join(', ')  if pool_records.inconsistent? :sha1
        @report_copy_mismatch.warn "MD5 mismatch for #{name}: "  +  pool_records.map { |p|  "#{p.location} has #{p.md5}"  }.join(', ')  if pool_records.inconsistent? :md5
        @report_copy_mismatch.warn "Size mismatch for #{name}: " +  pool_records.map { |p|  "#{p.location} has #{p.size}" }.join(', ')  if pool_records.inconsistent? :size
      end
      self
    end

  end # of class InterPoolAnalyzer


  class StoreMasterVsPoolAnalyzer

    # StoreMasterPackageStream returns information about what the StoreMaster thinks should be on the silos;
    # the folded data stream looks as so:
    #
    # E20110210_ROGMBP.000  [ #<struct name="E20110210_ROGMBP.000", store_location="http://one.example.com/.../E20110210_ROGMBP.000", ieid="E20110210_ROGMBP">,
    #                         #<struct name="E20110210_ROGMBP.000", store_location="http://two.example.com/.../E20110210_ROGMBP.000", ieid="E20110210_ROGMBP"> ]
    # E20110210_ROIUIC.000  [ #<struct name="E20110210_ROIUIC.000", store_location="http://one.example.com/.../E20110210_ROIUIC.000", ieid="E20110210_ROIUIC">,
    #                         #<struct name="E20110210_ROIUIC.000", store_location="http://two.example.com/.../E20110210_ROIUIC.000", ieid="E20110210_ROIUIC"> ]
    # ....
    #
    # The Pool fixity records look as so:
    #
    # E20110210_ROGMBP.000 [ #<Struct::PoolFixityRecord location="http://one.example.com/.../E20110210_ROGMBP.000", sha1="a5ffd229992586461450851d434e3ce51debb626", md5="15e4aeae105dc0cfc8edb2dd4c79454e", timestamp="2011-02-10T16:11:54-05:00", status="ok">,
    #                        #<Struct::PoolFixityRecord location="http://two.example.com/.../E20110210_ROGMBP.000", sha1="a5ffd229992586461450851d434e3ce51debb626", md5="15e4aeae105dc0cfc8edb2dd4c79454e", timestamp="2011-02-10T16:11:54-05:00", status="ok"> ]
    # E20110210_ROIUIC.000 [ #<Struct::PoolFixityRecord location="http://one.example.com/.../E20110210_ROIUIC.000", sha1="a5ffd229992586461450851d434e3ce51debb626", md5="15e4aeae105dc0cfc8edb2dd4c79454e", timestamp="2011-02-10T16:12:05-05:00", status="ok">,
    #                        #<Struct::PoolFixityRecord location="http://two.example.com/.../E20110210_ROIUIC.000", sha1="a5ffd229992586461450851d434e3ce51debb626", md5="15e4aeae105dc0cfc8edb2dd4c79454e", timestamp="2011-02-10T16:12:06-05:00", status="ok"> ]
    # ....
    #
    # Our job here is to do a sanity check on these two streams, so we build a ComparisonStream. Cases:
    #    get locations for a given package from the store-master, but not the pools:  error: report missing from pool
    #    get locations for a given package name from the pools, but not the store-master:  warning: report orphan on the pool

    attr_reader :reports

    def initialize store_master_stream, pool_fixity_streams
      @store_fixities    = Streams::FoldedStream.new(store_master_stream.rewind)
      @pool_fixities     = Streams::PoolMultiFixities.new(pool_fixity_streams)
      @comparison_stream = Streams::ComparisonStream.new(@store_fixities, @pool_fixities)

      @report_error_missing  = Reporter.new("Missing Package Copies - Recorded On The Storemaster, But Not Present In The Pools")
      @report_warn_orphan    = Reporter.new("Orphaned Package Copies - Found In The Pools, But Not Recorded By The Storemaster")

      @reports = [ @report_error_missing, @report_warn_orphan ]
    end

    def run
      @comparison_stream.each do |package_name, store_data, pool_data|

        pool_locations  = pool_data  ? pool_data.map  { |datum| datum.location }.sort       : []
        store_locations = store_data ? store_data.map { |datum| datum.store_location }.sort : []

        in_pool_only    = pool_locations  - store_locations
        in_store_only   = store_locations - pool_locations

        unless in_pool_only.empty?
          @report_warn_orphan.warn  "#{package_name} has #{FixityUtils.pluralize(in_pool_only.count, 'an orphan', 'orphans')} in the pools: #{in_pool_only.join(', ')}"
        end

        unless in_store_only.empty?
          @report_error_missing.err "#{package_name} is missing #{FixityUtils.pluralize(in_store_only.count, 'this copy', 'these copies')} from the pools: #{in_store_only.join(', ')}"
        end
      end
      self
    end
  end # of class StoreVsPoolAnalyser



  class StoreMasterAnalyzer

    attr_reader :reports

    def initialize store_master_stream, required_number
      @required_number     = required_number
      @store_master_stream = store_master_stream
      @report_wrong_number = Reporter.new("StoreMaster Has The Wrong Number Of Copies (#{required_number} Required)")
      @reports             = [ @report_wrong_number ]
    end

    def run
      # StoreMasterPackageStream returns information about what the StoreMaster thinks should be on the silos;
      # the folded data looks as so:
      #
      # E20110210_ROGMBP.000  [ #<struct name="E20110210_ROGMBP.000", store_location="http://one.example.com/.../E20110210_ROGMBP.000", ieid="E20110210_ROGMBP">,
      #                         #<struct name="E20110210_ROGMBP.000", store_location="http://two.example.com/.../E20110210_ROGMBP.000", ieid="E20110210_ROGMBP">,
      #                         ... ]
      # E20110210_ROIUIC.000  [ #<struct name="E20110210_ROIUIC.000", store_location="http://one.example.com/.../E20110210_ROIUIC.000", ieid="E20110210_ROIUIC">,
      #                         #<struct name="E20110210_ROIUIC.000", store_location="http://two.example.com/.../E20110210_ROIUIC.000", ieid="E20110210_ROIUIC">,
      #                         ... ]
      #
      # We check that we have the expected number of copies for each package.

      Streams::FoldedStream.new(@store_master_stream.rewind).each do |name, copy_records|
        locations = copy_records.map{ |rec| rec.store_location }.sort.join(', ')

        if copy_records.count < @required_number
          @report_wrong_number.err "#{name} has too few copies recorded by the store-master service, we have only these:  #{locations}"
        elsif copy_records.count > @required_number
          @report_wrong_number.warn "#{name} has too many copies recorded by the store-master service, we have all of these:  #{locations}"
        end

      end
      self
    end


  end # of class StoreMasterAnalyser
end # of module Analyzer
