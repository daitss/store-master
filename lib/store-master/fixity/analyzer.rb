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

  # A utility to keep track of how events are recorded - it's possbile the DB won't get capture some of
  # them,  and many 'fixity success' events are redundant and not recorded.

  class StatCounter

    attr_accessor :packages_double_counted, :packages_orphaned, :packages_missing, :packages_fixity_success, :packages_fixity_failure, :packages_wrong_number, :packages_expired, :packages_total, :packages_fixity_unchanged
    attr_accessor :events_new, :events_old, :events_err
    def initialize

      @events_err   = 0 
      @events_new   = 0    
      @events_old   = 0 

      @packages_double_counted   = 0
      @packages_expired          = 0
      @packages_fixity_failure   = 0
      @packages_fixity_success   = 0
      @packages_fixity_unchanged = 0  # implies successful fixity
      @packages_missing          = 0
      @packages_orphaned         = 0
      @packages_total            = 0      
      @packages_wrong_number     = 0
    end

    def events_total
      @events_err + @events_new + @events_old
    end

    def format_max_width

      StoreUtils.commify([ @events_new, @events_old, @events_err, @packages_double_counted,
                           @packages_orphaned, @packages_missing,
                           @packages_fixity_success, @packages_fixity_failure,
                           @packages_fixity_unchanged, @packages_wrong_number, @packages_expired,
                           @packages_total ].max).length    
    end
  end


  class PoolVsDaitssAnalyzer

    attr_reader :reports

    def initialize  pool_fixity_streams, daitss_fixity_stream, required_copies, expiration_days, stale_days, no_later_than
      
      @pool_fixity_stream    = Streams::StoreUrlMultiFixities.new(pool_fixity_streams)
      @daitss_fixity_stream  = daitss_fixity_stream

      @cutoff_time         = no_later_than
      @required_copies     = required_copies
      @expiration_days     = expiration_days

      @report_integrity    = Datyl::Reporter.new "Integrity Errors",    "Package Copies Missing From Silo Pools"
      @report_too_many     = Datyl::Reporter.new "Integrity Errors",    "Too Many Copies Of Packages"
      @report_fixity       = Datyl::Reporter.new "Fixity Errors",       "Package Copies With Fixity Errors"
      @report_expired      = Datyl::Reporter.new "Fixity Expirations",  "Package Copies With Fixities Over #{expiration_days} Days Old"
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

      pool_data_array.each { |rec| messages.push(indent + rec.location) if rec.status == "missing" }

      return if messages.empty?
      return messages.unshift "#{url} missing #{messages.length} #{messages.length == 1 ? 'copy' : 'copies'}:"
    end

    def fixity_issues url, pool_data, daitss_data
      messages = []

      pool_data.each do |rec|
        next if rec.status == "missing"   # this indicates a missing package; we'll report it as an integrity error elsewhere

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

    def get_package url
      pkg = Daitss::Package.lookup_from_url(url)
      if pkg.nil?
        Datyl::Logger.info "#{url} is no longer in the DAITSS DB; it was deleted by DAITSS during fixity record reconciliation."
      end
      return pkg
    end

    def run
      counter = StatCounter.new

      (@pool_fixity_stream <=> @daitss_fixity_stream).each do |url, pool_data, daitss_data|

        # for example
        #
        # url:          http://store-master.fcla.edu/packages/EYMZSFV43_8A2KCD.000
        # pool_data:    [ #<struct Struct::PoolFixityRecord location="http...", sha1="4ab..", md5="0d7...", size="131..", fixity_time="2011-04-27T11:38:30Z", put_time="2011-04-20T20:21:33Z", status="ok"> .. more structs .. ]>,
        # daitss_data:  #<struct ieid="E101W4TQQ_VGD9QW", url="http://storemaster.fda.fcla.edu:70/packages/E101W4TQQ_VGD9QW.000", last_successful_fixity_time="2011-10-02T03:38:38Z", package_store_time="2011-09-19T18:19:52Z", md5="f1b797725b64c4a06a81bcfac0c1f077", sha1="1a6f80fd868cda45e6f8413f8fc9dbd9c081f3f9", size=9256960>
                
        if not pool_data             # ..but we do have daitss_data for this URL, so we have a missing package of which the silo is unaware

          next unless pkg = get_package(url) # double check: is it still there in the DAITSS DB?  The deletion may have been in progress, and invisible, just as we started

          counter.packages_total += 1
          counter.packages_missing += 1
          @report_integrity.err  "#{url}: no copies where listed by any of the pools."

          pkg.integrity_failure_event("No copies were listed by any of the pools.") ? counter.events_new += 1 : counter.events_err += 1
          
        elsif not daitss_data        # ..but we do have pool_data for this URL, so we may have some sort of 'orphan'.

          counter.packages_orphaned += 1
          @report_orphaned.warn *(pool_data.map { |cp| cp.location })

        else                         # .. we have records for both

          all_good = true

          case             
          when pool_data.length < @required_copies

            next unless pkg = get_package(url)    # Has it dissappeared from DAITSS due to an in-progress delete, perhaps from a refresh?

            counter.packages_total += 1
            counter.packages_missing += 1

            messages =  [ "#{url} has too few copies, only:" ] + pool_data.map { |rec| indent + rec.location }

            @report_integrity.err *messages
            
            pkg.integrity_failure_event(messages.join) ? counter.events_new += 1 : counter.events_err += 1
            all_good = false

          when pool_data.length > @required_copies

            next unless pkg = get_package(url)   

            counter.packages_total += 1
            counter.packages_wrong_number += 1

            messages =  [ "#{url} has too many copies:" ] + pool_data.map { |rec| indent + rec.location }

            @report_too_many.err *messages

            pkg.integrity_failure_event(messages.join) ? counter.events_new += 1 : counter.events_err += 1

            all_good = false
          end

          # Pools may sometimes be aware of missing packages and directly report them:

          missing_issue_messages = missing_issues(url, pool_data)

          # Compare fixities:

          fixity_issue_messages  = fixity_issues(url, pool_data, daitss_data) 

          if fixity_issue_messages
            
            next unless pkg = get_package(url)

            counter.packages_total += 1
            counter.packages_fixity_failure += 1

            @report_fixity.err *(fixity_issue_messages + [ '' ])

            pkg.fixity_failure_event(fixity_issue_messages.join) ? counter.events_new += 1 : counter.events_err += 1

            all_good = false
          end

          if missing_issue_messages

            next unless pkg = get_package(url)

            counter.packages_total += 1
            counter.packages_missing += 1

            @report_integrity.err *(missing_issue_messages + [ '' ])

            pkg.integrity_failure_event(missing_issue_messages.join) ? counter.events_new += 1 : counter.events_err += 1

            all_good = false
          end

          # we're using counter to keep track of the total number of
          # packages; in the following very unlikely case we'd be
          # double counting, so let's subtract one from total count
          # and flag that missing + fixity errors will be off by one.

          if missing_issue_messages and fixity_issue_messages
            counter.packages_double_counted += 1
            counter.packages_total -= 1
          end

          if all_good

            pool_fixity_time   = pool_data.map { |rec| rec.fixity_time }.min
            daitss_fixity_time = daitss_data.last_successful_fixity_time

            # count success if we've got a match

            if pool_fixity_time == daitss_fixity_time
              counter.packages_fixity_unchanged += 1
              counter.events_old += 1
              counter.packages_total += 1
              next
            end

            next unless pkg = get_package(url)

            pkg.fixity_success_event(pool_fixity_time) ? counter.events_new += 1 : counter.events_err += 1
            counter.packages_fixity_success += 1
            counter.packages_total += 1
          end
        end  # end of if .. elsif .. else   # .. we have records for both
      end

      expiration_date = (DateTime.now - @expiration_days).to_s

      @pool_fixity_stream.rewind
      @daitss_fixity_stream.rewind

      (@pool_fixity_stream <=> @daitss_fixity_stream).each do |url, pool_data, daitss_data|

        next unless daitss_data and pool_data   # we skip reporting expired orphans

        pool_data.each do |fix|
          if fix.fixity_time < expiration_date
            counter.packages_expired += 1
            @report_expired.warn fix.location + " last checked at " + fix.fixity_time
          end
        end

      end

      # We are looking for a report that looks roughly like the following: 
      #
      # Summary of DAITSS Package Fixity Checks
      # :::::::::::::::::::::::::::::::::::::::
      #
      # 1,242 ingested package records as of 2011-12-01 04:15:00
      #
      # 1,240 correct fixities
      #     1 incorrect fixity
      #     2 missing packages
      #     0 packages with wrong number of copies in pools
      # -----
      # 1,242 events, 3 new
      #
      # Additionally:
      #
      #     1 package had an expired fixity
      #     1 unexpected package (orphan?) in silo pools
      #

      # ...
      
      width = counter.format_max_width

      @report_summary.warn sprintf("%#{width}s ingested package records as of %s", StoreUtils.commify(counter.packages_total), @cutoff_time.strftime('%F %T'))
      @report_summary.warn
      @report_summary.warn sprintf("%#{width}s new correct #{pluralize counter.packages_fixity_success, 'fixity', 'fixities'}", StoreUtils.commify(counter.packages_fixity_success))
      @report_summary.warn sprintf("%#{width}s old correct #{pluralize counter.packages_fixity_success, 'fixity', 'fixities'}", StoreUtils.commify(counter.packages_fixity_unchanged))
      @report_summary.warn sprintf("%#{width}s incorrect #{pluralize counter.packages_fixity_failure, 'fixity', 'fixities'}", StoreUtils.commify(counter.packages_fixity_failure))
      @report_summary.warn sprintf("%#{width}s had missing copies", StoreUtils.commify(counter.packages_missing))
      @report_summary.warn sprintf("%#{width}s with the wrong number of copies in pools", StoreUtils.commify(counter.packages_wrong_number))
      @report_summary.warn '-' * width
      @report_summary.warn sprintf("%#{width}s total events, %s of which are new", StoreUtils.commify(counter.events_total), StoreUtils.commify(counter.events_total - counter.events_old))

      @report_summary.warn
      @report_summary.warn 'Additionally:'
      @report_summary.warn sprintf("%#{width}s unexpected package#{pluralize counter.packages_orphaned, '', 's'} (orphaned?) in silo pools", StoreUtils.commify(counter.packages_orphaned))
      @report_summary.warn sprintf("%#{width}s package#{pluralize counter.packages_expired, '', 's'} had #{pluralize counter.packages_expired, 'an expired fixity', 'expired fixities'}", StoreUtils.commify(counter.packages_expired))

      if (n = counter.events_err) > 0      
        @report_summary.err "There #{n == 1 ? 'was one failure' : sprintf('were %d failures', n) } writing new events to the DAITSS DB"
      end

      if (n = counter.packages_double_counted) > 0
        @report_summary.warn "Note that there were multiple events recorded for some packages (this can"
        @report_summary.warn "happen when a package has a copy failing a fixity check, with the other missing)."
        if n == 1
          @report_summary.warn "There was one such double count."
        else
          @report_summary.warn "There were #{n} such double counts."
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
