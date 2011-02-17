require 'datyl/reporter'
require 'datyl/streams'
require 'store-master/fixity/pool-stream'
require 'store-master/fixity/utils'

# Analyzers run checks over various pool and daitss fixity data
# streams; it produces reports listing warnings and errors that are
# provided for later printing or mailing; if logging has been
# initialized, then the reporter objects will write to logs.

module Analyzer

  # IntraPoolAnalyzer
  #
  # Initialize with an array of streams, one for each of our pools.
  # Check each pool for internal consistency, which here means we have
  # exacly one fixity record for each package (no redundant packages
  # in a silo-pool)

  class IntraPoolAnalyzer

    # Recall that each of the PoolFixityStreamss given to us yield key/value pairs  <String::package>, <Struct::PoolFixityRecord>, e.g.
    # E20110129_CYXBHO.000, #<struct Struct::PoolFixityRecord location="http://pool.b.local/silo-pool.b.1/data/E20110129_CYXBHO.000", sha1="ccd53fa068173b4f5e52e55e3f1e863fc0e0c201", md5="4732518c5fe6dbeb8429cdda11d65c3d", timestamp="2011-01-29T02:43:50-05:00", status="ok">
    # All fields within the struct are simple strings.

    def initialize pool_fixity_streams, max_days
      @expiration_date = (DateTime.now - max_days).to_s
      @pool_fixity_streams  = pool_fixity_streams

      @redundant_package_report = Reporter.new("Multiple Packages Within a Pool")
      @expired_fixity_report    = Reporter.new("Packages With Expired Fixities (Older Than #{max_days} Days)")
      @bad_status_report        = Reporter.new("Packages With Bad Fixity Status (From Silo Pool Data)")
    end

    def run 
      @pool_fixity_streams.each do |pool_fixity_stream|

        pool_fixity_stream.rewind.each do |package_name, fixity_record|
          if fixity_record.status != 'ok'
            @bad_status_report.err "#{fixity_record.location} has fixity status #{fixity_record.status}, last checked #{Time.parse(fixity_record.timestamp).asctime}"
          end

          if fixity_record.timestamp < @expiration_date
            @expired_fixity_report.warn "#{fixity_record.location} last checked #{Time.parse(fixity_record.timestamp).asctime}"
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

    def reports
      [ @redundant_package_report, @expired_fixity_report, @bad_status_report ]
    end
  end # of class IntraPoolAnalyzer

  # InterPoolAnalyzer
  #
  # As above, we initialize with an array of streams, one for each of our pools.  Here, however
  # consistency,  which here means we have exacly one fixity record for each package (no redundant
  # packages in a silo-pool)

  class InterPoolAnalyzer

    def initialize pool_fixity_streams, required_copies
      @pool_fixity_streams  = pool_fixity_streams
      @required_copies      = required_copies
      @report_wrong_number  = Reporter.new "Packages Not Having the Required #{FixityUtils.pluralize_phrase(@required_copies, 'Copy', 'Copies')} in Pools"
      @report_copy_mismatch = Reporter.new "Packages Having Mismatched SHA1, MD5 or Sizes Between the Silo Pools"
    end

    def run
      Streams::PoolMultiFixities.new(@pool_fixity_streams).each do |name, pool_records|
        @report_wrong_number.warn "#{name} has #{FixityUtils.pluralize_phrase(pool_records.count, 'copy', 'copies')}" if pool_records.count != @required_copies 

        @report_copy_mismatch.warn "SHA1 mismatch for #{name}: " +  pool_records.map { |p|  "#{p.location} has #{p.sha1}" }.join(', ')  if pool_records.inconsistent? :sha1
        @report_copy_mismatch.warn "MD5 mismatch for #{name}: "  +  pool_records.map { |p|  "#{p.location} has #{p.md5}"  }.join(', ')  if pool_records.inconsistent? :md5
        @report_copy_mismatch.warn "Size mismatch for #{name}: " +  pool_records.map { |p|  "#{p.location} has #{p.size}" }.join(', ')  if pool_records.inconsistent? :size
      end
      self
    end
    
    def reports
      [ @report_wrong_number, @report_copy_mismatch ]
    end

  end # of class InterPoolAnalyzer

  
end # of module Analyzer
