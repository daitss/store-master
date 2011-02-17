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

  # TODO: check for bad status values within a silo-pool as well?  

  class IntraPoolAnalyzer

    def initialize pool_fixity_streams
      @pool_fixity_streams  = pool_fixity_streams
      @report = Reporter.new("Redundant Packages Within a Pool")
    end

    def run 
      @pool_fixity_streams.each do |pool_fixity_stream|         
        Streams::FoldedStream.new(pool_fixity_stream.rewind).each do |name, records|      # fold values for identical keys into one array
          if records.count > 1 
            @report.warn "#{name} #{records.map { |rec| rec.location }.join(', ')}"
          end
        end
      end
      self
    end

    def reports
      [ @report ]
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
