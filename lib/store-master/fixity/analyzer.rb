require 'datyl/reporter'
require 'datyl/streams'
require 'datyl/logger'
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
    #  EO05UJJHZ_HPDFHG.001 #<struct Struct::PoolFixityRecord location="http://silos.ripple.fcla.edu:70/001/data/EO05UJJHZ_HPDFHG.001", sha1="4abc7ec5f02b946dc4812f0b60bda34940ae62f3", md5="0d736ef6585b44bf0552a61b95ad9b87", size="1313843200", fixity_time="2011-04-27T11:38:30Z", put_time="2011-04-20T20:21:33Z", status="ok">
    #
    # All fields within the struct are simple strings.

    attr_reader :reports

    def initialize pool_fixity_streams, max_days
      @expiration_date = (DateTime.now - max_days).to_s
      @pool_fixity_streams  = pool_fixity_streams

      @redundant_package_report = Datyl::Reporter.new("Per-Pool Redundancy Report", "Multiple Copies Within A Pool")
      @expired_fixity_report    = Datyl::Reporter.new("Per-Pool Expiration Report", "Packages With Expired Fixities - Older Than #{max_days} Days")
      @bad_status_report        = Datyl::Reporter.new("Per-Pool Status Report", "Packages Currently Marked With Failed Fixity")

      @reports = [ @redundant_package_report, @expired_fixity_report, @bad_status_report ]
    end

    def run
      @pool_fixity_streams.each do |pool_fixity_stream|

        pool_fixity_stream.rewind.each do |package_name, fixity_record|
          if fixity_record.status != 'ok'
            @bad_status_report.err "#{fixity_record.location} fixity status of '#{fixity_record.status}' as of  #{Time.parse(fixity_record.timestamp)}"
          end

          if fixity_record.timestamp < @expiration_date
            days = '%3.1f' % ((Time.parse(@expiration_date) - Time.parse(fixity_record.timestamp))/(60 * 60 * 24))
            @expired_fixity_report.warn "#{fixity_record.location} fixity expired #{days} #{FixityUtils.pluralize(days,'day ago', 'days ago')}"
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

      @reports.each { |report| report.done }
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

      @report_wrong_number  = Datyl::Reporter.new "Inter-Pool Copy Check", "Packages Not Having The Required #{@required_copies} #{FixityUtils.pluralize(@required_copies, 'Copy', 'Copies')} In Pools"
      @report_copy_mismatch = Datyl::Reporter.new "Inter-Pool Fixity Check", "Packages Having Mismatched SHA1, MD5 Or Sizes Between The Silo Pools"
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

      @reports.each { |report| report.done }
      self
    end

  end # of class InterPoolAnalyzer


  class StoreMasterVsPoolAnalyzer

    # StoreMasterPackageStream returns information about what the StoreMaster thinks should be on the silos;
    # the folded data stream looks as so:
    #
    # E20110210_ROGMBP.000  [ #<struct name="E20110210_ROGMBP.000", store_location="http://one.example.com/.../E20110210_ROGMBP.000", ieid="E20110210_ROGMBP">,
    #                         #<struct name="E20110210_ROGMBP.000", store_location="http://two.example.com/.../E20110210_ROGMBP.000", ieid="E20110210_ROGMBP"> ]
    #
    # E20110210_ROIUIC.000  [ #<struct name="E20110210_ROIUIC.000", store_location="http://one.example.com/.../E20110210_ROIUIC.000", ieid="E20110210_ROIUIC">,
    #                         #<struct name="E20110210_ROIUIC.000", store_location="http://two.example.com/.../E20110210_ROIUIC.000", ieid="E20110210_ROIUIC"> ]
    # ....
    #
    # The Pool fixity records look as so:
    #
    #  EO05UJJHZ_HPDFHG.001 #<struct Struct::PoolFixityRecord location="http://silos.ripple.fcla.edu:70/001/data/EO05UJJHZ_HPDFHG.001", sha1="4abc7ec5f02b946dc4812f0b60bda34940ae62f3", md5="0d736ef6585b44bf0552a61b95ad9b87", size="1313843200", fixity_time="2011-04-27T11:38:30Z", put_time="2011-04-20T20:21:33Z", status="ok">
    #  EQ93PZGKM_ER3H8G.000 #<struct Struct::PoolFixityRecord location="http://silos.ripple.fcla.edu:70/001/data/EQ93PZGKM_ER3H8G.000", sha1="a6ec8b7415e1a4fdfacbd42d1a7c0e3435ea2dd4", md5="c9672d29178ee51eafef97a4b8297a5b", size="587591680", fixity_time="2011-04-27T11:38:45Z", put_time="2011-04-20T22:08:41Z", status="ok">
    #  ESKMPS0TO_7W4ASP.000 #<struct Struct::PoolFixityRecord location="http://silos.ripple.fcla.edu:70/001/data/ESKMPS0TO_7W4ASP.000", sha1="a1bc6134dbc4dc0beffa94235f470bb7e0e8a016", md5="9fc127a90ec6c02b094d6f656f74232c", size="1003280384", fixity_time="2011-04-27T11:39:11Z", put_time="2011-04-21T14:20:13Z", status="ok">
    # ....
    #
    # Our job here is to do a sanity check on these two streams, so we build a ComparisonStream. Cases:
    #    get locations for a given package from the store-master, but not the pools:  error: report missing from pool
    #    get locations for a given package name from the pools, but not the store-master:  warning: report orphan on the pool

    attr_reader :reports

    def initialize store_master_stream, pool_fixity_streams
      @store_fixities    = Streams::FoldedStream.new(store_master_stream.rewind)
      @pool_fixities     = Streams::PoolMultiFixities.new(pool_fixity_streams)

      @report_error_missing  = Datyl::Reporter.new("Store-Master/Pools - Missing Packages", "Packages Recorded On The Store-Master, But Not Present In The Pools")
      @report_warn_orphan    = Datyl::Reporter.new("Store-Master/Pools - Unexpected Packages", "Packages Found In The Pools, But Not Recorded By The Store-Master")

      @reports = [ @report_error_missing, @report_warn_orphan ]
    end

    def run
      (@store_fixities <=> @pool_fixities).each do |package_name, store_data, pool_data|

        pool_locations  = pool_data  ? pool_data.map  { |datum| datum.location }.sort       : []
        store_locations = store_data ? store_data.map { |datum| datum.store_location }.sort : []

        in_pool_only    = pool_locations  - store_locations
        in_store_only   = store_locations - pool_locations

        unless in_pool_only.empty?
          @report_warn_orphan.warn in_pool_only.join(', ')
        end

        unless in_store_only.empty?
          @report_error_missing.err "#{package_name} is missing #{FixityUtils.pluralize(in_store_only.count, 'this copy', 'these copies')}: #{in_store_only.join(', ')}"
        end
      end
      @reports.each { |report| report.done }
      self
    end
  end # of class StoreVsPoolAnalyser



  class StoreMasterAnalyzer

    attr_reader :reports

    def initialize store_master_stream, required_number
      @required_number     = required_number
      @store_master_stream = store_master_stream
      @report_wrong_number = Datyl::Reporter.new("Store-Master Copy Check", "Store-Master Didn't Record The Required #{required_number} #{FixityUtils.pluralize @required_number, 'Copy', 'Copies'}")
      @reports             = [ @report_wrong_number ]
    end

    def run
      # StoreMasterPackageStream returns information about what the StoreMaster thinks should be on the silos;
      # the folded data looks as so:
      #
      # E20110210_ROGMBP.000  [ #<struct name="E20110210_ROGMBP.000", store_location="http://pool-one.example.com/.../E20110210_ROGMBP.000", ieid="E20110210_ROGMBP">,
      #                         #<struct name="E20110210_ROGMBP.000", store_location="http://pool-two.example.com/.../E20110210_ROGMBP.000", ieid="E20110210_ROGMBP">,
      #                         ... ]
      # E20110210_ROIUIC.000  [ #<struct name="E20110210_ROIUIC.000", store_location="http://pool-two.example.com/.../E20110210_ROIUIC.000", ieid="E20110210_ROIUIC">,
      #                         #<struct name="E20110210_ROIUIC.000", store_location="http://pool-six.example.com/.../E20110210_ROIUIC.000", ieid="E20110210_ROIUIC">,
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
      @reports.each { |report| report.done }
      self
    end
  end # of class StoreMasterAnalyser


  # A utility to keep track of how events are recorded - it's possbile the DB won't get capture some of
  # them,  and many 'fixity success' events are redundant and not recorded.

  class EventCounter
    attr_reader :successes, :failures, :unchanged, :double_counts

    def initialize
      @failures      = 0    
      @successes     = 0 
      @unchanged     = 0
      @double_counts = 0
    end


    # Package#integrity_failure_event and Package#fixity_failure_event
    # methods return true if a failure event was saved, false on DB error.
    # Package#fixity_success_event additionally may return nil if the event
    # already exists (and thus wasn't saved as a new even). 
    #
    # Our status= method keeps track of these.


    def status= res
      case res
      when nil;    @unchanged += 1
      when true;   @successes += 1
      when false;  @failures  += 1
      else 
        raise "Unexpected value when recording event save status: #{res.inspect}"
      end
    end

    def double_count
      @double_counts += 1
    end

    def total
      @failures + @successes + @unchanged
    end
  end


  class PoolVsDaitssAnalyzer

    attr_reader :reports

    def initialize  pool_fixity_streams, daitss_fixity_stream, required_copies, expiration_days, no_later_than
      
      @pool_fixity_stream    = Streams::StoreUrlMultiFixities.new(pool_fixity_streams)
      @daitss_fixity_stream  = daitss_fixity_stream

      @cutoff_time         = no_later_than
      @required_copies     = required_copies
      @expiration_days     = expiration_days

      @report_integrity    = Datyl::Reporter.new "Integrity Error", "Package Copies Missing From Silo Pools"
      @report_too_many     = Datyl::Reporter.new "Integrity Error", "Too Many Copies Of Packages"
      @report_fixity       = Datyl::Reporter.new "Fixity Error", "Package Copies With Fixity Errors"
      @report_expired      = Datyl::Reporter.new "Fixity Expiration", "Package Copies With Fixities Over #{expiration_days} Days Old"
      @report_orphaned     = Datyl::Reporter.new "Unexpected Packages", "Pools Contain Packages Not Listed By DAITSS"
      @report_summary      = Datyl::Reporter.new "Summary of DAITSS Package Fixity Checks", "Requiring #{@required_copies} #{FixityUtils.pluralize(@required_copies, 'Copy', 'Copies')} Per Package"

      @reports             = [ @report_summary, @report_fixity, @report_integrity, @report_too_many, @report_orphaned, @report_expired ]
    end

    # the StoreUrlMultiFixities stream provides as a key the storage url for a package; the associated value is an array of pool fixity records for each copy of the package (these may be mixed arities)
    #
    # http://store-master.com/packages/E20110210_ROGMBP.000 [ #<Struct::PoolFixityRecord ...> #<Struct::PoolFixityRecord ...> ]
    # ...

    # the daitss_fixity_stream  provides the same key as the above, and a DataMapper-supplied record of the DAITSS information about the package:
    #
    # http://store-master.com/packages/EZQQYQMC2_6PYZMQ.000 #<Struct::DataMapper ieid="EZQQYQMC2_6PYZMQ", url="http://store-master.com/packages/EZQQYQMC2_6PYZMQ.000", md5="7e45d204d270da0f8aab2a65f59a2429", sha1="e541c693e56edd9a7e04cab94de5740092ae3953", size=4761600>
    # http://store-master.com/packages/EZYNH5CZC_ZP2B9Y.000 #<Struct::DataMapper ieid="EZYNH5CZC_ZP2B9Y", url="http://store-master.com/packages/EZYNH5CZC_ZP2B9Y.000", md5="52076e3d8a9196d365c8381e135b6812", sha1="b046c58503f570ea090b8c5e46cc5f4e0c27f003", size=1962598400>
    # ...


    def indent
      ' '  * 4
    end

    def missing_issues url, pool_data_array
      messages = []

      pool_data_array.each { |rec| messages.push(indent + rec.location + ' not present') if rec.sha1.nil? or rec.sha1.empty? or rec.md5.nil? or rec.md5.empty? }
      return if messages.empty?
      return messages.unshift "#{url} #{messages.length > 1 ? 'has copies that are' : 'has a copy that is'} reported missing by the silo pool:"
    end

    def fixity_issues url, pool_data, daitss_data
      messages = []

      pool_data.each do |rec|
        next if rec.sha1.empty? and rec.md5.empty?   # this indicates a missing package; we'll report it in a separate integrity test

        if rec.sha1 != daitss_data.sha1
          messages.push indent + "DAITSS DB has SHA1 of #{daitss_data.sha1}, but silo at #{rec.location} reports #{rec.sha1}"
        end
        if rec.md5 != daitss_data.md5
          messages.push indent + "DAITSS DB has MD5 of #{daitss_data.md5}, but silo at #{rec.location} reports #{rec.md5}"
        end
      end

      return if messages.empty?
      return messages.unshift "#{url} checksum errors:"        

    end



    def pluralize count, singular, plural
      return singular if count == 1
      return plural
    end

    def anything_interesting? reports
      reports.each { |rep| return true if rep.interesting? }
      return false
    end

    def too_recent pool_data
      return false unless pool_data
      no_later = @cutoff_time.to_utc
      pool_data.each do |pool_record|
        return true if pool_record.put_time > no_later
      end
      return false
    end



    def run
      score_card    = { :orphans => 0, :missing => 0, :checked => 0, :fixity_successes => 0, :fixity_failures => 0, :wrong_number => 0, :expired_fixities => 0, :daitss_packages => 0 }
      event_counter = EventCounter.new

      (@pool_fixity_stream <=> @daitss_fixity_stream).each do |url, pool_data, daitss_data|

        # for example:
        #
        # url:          http://store-master.fcla.edu/packages/EYMZSFV43_8A2KCD.000
        # pool_data:    [ #<struct Struct::PoolFixityRecord location="http...", sha1="4ab..", md5="0d7...", size="131..", fixity_time="2011-04-27T11:38:30Z", put_time="2011-04-20T20:21:33Z", status="ok"> .. more structs .. ]
        # daitss_data:  #<Struct::DataMapper ieid="EYMZSFV43_8A2KCD", url="http://store-master.fcla.edu/packages/EYMZSFV43_8A2KCD.000", md5="06cd2880ad13eed3255706752be8a6b1", sha1="b73aabefe9f98f421047eb66526dc33420e85e04", size=119244800>


        Datyl::Logger.info url
        Datyl::Logger.info pool_data.inspect
        Datyl::Logger.info daitss_data.inspect

        next if too_recent(pool_data)

        if daitss_data
          pkg = Daitss::Package.lookup_from_url(url)
          if pkg.nil?
            Datyl::Logger.err "#{url} isn't in DAITSS DB - did it go away? (this is a temporary work-around for a known problem)"
            next
          end
        end
        

        score_card[:daitss_packages] += 1 if daitss_data
        
        if not pool_data             # ..but we do have daitss_data for this URL, so we have a missing package
          score_card[:missing] += 1

          @report_missing.err  "#{url}: no copies where listed by any of the pools."
          event_counter.status = pkg.integrity_failure_event "No copies were listed by any of the pools."            

        elsif not daitss_data        # ..but we do have pool_data for this URL, so we have some sort of orphan.
          score_card[:orphans] += 1
                    
          pool_data.each do |cp|            
            @report_orphaned.warn indent + cp.location
          end

        else                         # .. we have records for both

          score_card[:checked] += 1
          all_good = true

          case pool_data.length <=> @required_copies              # integrity error
            
          when -1

            messages =  [ "#{url} has too few copies, only:" ]
            @pool_data.each { |rec| messages.push indent + rec.locatation }

            messages.each { |msg| @report_integrity.err msg }

            @report_integrity.err message
            event_counter.status = pkg.integrity_failure_event messages.join

            score_card[:missing] += 1
            all_good = false

          when +1
            messages =  [ "#{url} has too many copies, only:" ]
            @pool_data.each { |rec| messages.push indent + rec.locatation }

            messages.each { |msg| @report_integrity.err msg }

            @report_too_many.err messages.join

            event_counter.status = pkg.integrity_failure_event messages.join

            score_card[:wrong_number] += 1
            all_good = false
          end

          # this version of missing means that the silo reported the 

          missing_issue_messages = missing_issues(url, pool_data)
          fixity_issue_messages  = fixity_issues(url, pool_data, daitss_data) 

          if fixity_issue_messages
            score_card[:fixity_failures] += 1
            fixity_issue_messages.each { |msg| @report_fixity.err(msg) }
            event_counter.status = pkg.fixity_failure_event(fixity_issue_messages.join)
            all_good = false
          end

          if missing_issue_messages
            score_card[:missing] += 1
            missing_issue_messages.each { |msg| @report_integrity.err(msg) }
            event_counter.status = pkg.integrity_failure_event(missing_issue_messages.join)
            all_good = false
          end

          # we're using event_counter to give us total number of packages; in the following
          # case we'd be double counting, so keep track of it

          if missing_issue_messages and fixity_issue_messages
            event_counter.double_count
          end


          if all_good
            score_card[:fixity_successes] += 1
            event_counter.status = pkg.fixity_success_event DateTime.parse(pool_data.map { |rec| rec.fixity_time }.min)
          end
        end
      end

      expiration_date = (DateTime.now - @expiration_days).to_s

      @pool_fixity_stream.rewind
      @daitss_fixity_stream.rewind

      (@pool_fixity_stream <=> @daitss_fixity_stream).each do |url, pool_data, daitss_data|

        next unless daitss_data and pool_data   # we skip reporting expired orphans

        pool_data.each do |fix|
          if fix.fixity_time < expiration_date
            score_card[:expired_fixities] += 1
            @report_expired.warn '#{url} at ' + fix.location + ' last checked at ' + fix.fixity_time
          end
        end

      end

      # We are looking for a report that looks roughly like the following: 
      #
      # Summary of DAITSS Package Fixity Checks
      # :::::::::::::::::::::::::::::::::::::::
      #
      # 1,242 ingested package records as of 2011-12-01 04:15:00
      # 1,242 ingested package records were checked against fixity data.
      #
      # 1,240 correct fixities
      #     1 incorrect fixity
      #     1 missing package
      #     0 packages with wrong number of copies in pools
      # -----
      # 1,242 events, 2 new, 0 failed to be updated
      #
      # Additionally:
      #
      #     1 package had an expired fixity
      #     1 unexpected package (orphan?) in silo pools
      #

      # ...


      len = StoreUtils.commify(score_card.values.max).length

      @report_summary.warn sprintf("%#{len}s ingested package records as of %s", StoreUtils.commify(score_card[:daitss_packages]), @cutoff_time.strftime('%F %T'))
      @report_summary.warn sprintf("%#{len}s of these records were checked against fixity data", StoreUtils.commify(score_card[:checked]))
      @report_summary.warn
      @report_summary.warn sprintf("%#{len}s correct #{pluralize score_card[:fixity_successes], 'fixity', 'fixities'}", StoreUtils.commify(score_card[:fixity_successes]))
      @report_summary.warn sprintf("%#{len}s had missing copies", StoreUtils.commify(score_card[:missing]))
      @report_summary.warn sprintf("%#{len}s incorrect #{pluralize score_card[:fixity_failures], 'fixity', 'fixities'}", StoreUtils.commify(score_card[:fixity_failures]))
      @report_summary.warn sprintf("%#{len}s with the wrong number of copies in pools", StoreUtils.commify(score_card[:wrong_number]))
      @report_summary.warn '-' * len
      @report_summary.warn sprintf("%#{len}s total events, %s new", StoreUtils.commify(event_counter.total), StoreUtils.commify(event_counter.total - event_counter.unchanged))

      @report_summary.warn
      @report_summary.warn 'Additionally:'
      @report_summary.warn sprintf("%#{len}s unexpected package#{pluralize score_card[:orphans], '', 's'} (orphan?) in silo pools", StoreUtils.commify(score_card[:orphans]))
      @report_summary.warn sprintf("%#{len}s package#{pluralize score_card[:expired_fixities], '', 's'} had #{pluralize score_card[:expired_fixities], 'an expired fixity', 'expired fixities'}", StoreUtils.commify(score_card[:expired_fixities]))

      if event_counter.failures > 0      
        n = event_counter.failures
        @report_summary.err "There #{n == 1 ? 'was one failure' : sprintf('were %d failures', n) } writing to the DAITSS DB"
      end

      if event_counter.double_counts > 0
        n = event_counter.double_counts
        @report_summary.warn "Note that there were multiple events recorded for some packages (this can"
        @report_summary.warn "happen when a package has one missing copy and another failing a fixity check)."
        if n == 1
          @report_summary.warn "There was one such double count."
        else
          @report_summary.warn "There were #{n} such doublle counts."
        end      
      end



      # Note that this run method returns self, which has all of the
      # reports on it; while the reports info/warn/err messages have
      # already been sent to the log, the calling program may very
      # well write all of them, in the order the reports were stored
      # on @reports above - @report_summary is first.


      self
    end

  end # of class PoolVsDaitssAnalyzer
end # of module Analyzer
