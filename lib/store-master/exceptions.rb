require 'store-master/http-exceptions'

# Most of the named exceptions in the service libraries we here assign
# to one of the HTTP exception classes.  Libraries are designed
# specifically to be unaware of this mapping: they should use their
# specific low level exceptions classes, and never the HttpError ones.
#
# In general, if we catch an HttpError at our top level sinatra error
# handler, we can blindly return the error message to the client as a
# diagnostic and log it.  The fact that we're subclassing the
# following exceptions from the Http ones means we're being careful
# not to leak information, and still be helpful to the client.  Since
# they provide very specific messages, tracebacks will not be
# required.
#
# When we get an un-named exception or a named exception that is not
# subclassed from the HttpErrors, however, the appropriate thing to do
# at the top level is to just supply a very terse message to the
# client (i.e., we wouldn't like to expose errors from an ORM that
# said something like "password 'topsecret' failed in mysql open").
# We *will* want to log the full error message, and probably the
# traceback to boot.

module StoreMaster

  # SiloUnreachable exception, silo servers fault (subclassed Http500): system failure.

  class SiloUnreachable            < Http500; end

  # ConfigurationError exception, server's fault (subclasses Http500): Something wasn't set up correctly

  class ConfigurationError         < Http500; end            

  # Database error, server's fault (subclasses Http500): general DB failure.

  class DataBaseError              < Http500; end

  # General storage problem, server's fault (subclasses Http500).  Normally subclassed to something more informative

  class DiskStoreError             < Http500; end

  # Client tried to create a package that already exists, subclasses 409 Conflict.

  class DiskStoreResourceExists    < Http409; end

  # Client tried to create a package using an invalid name, subclasses 409 Conflict.

  class BadName                    < Http412; end

  # DriveByError is just meant to be caught so the message logged somewhere appropriate; the
  # error is non-fatal and should not be percolated to the top...

  class DriveByError               < StandardError; end

  # Some Precondition failed on storing to a silo, could be a configuration issue like
  # bad username/password

  class SiloStoreError             < Http500;       end

  # No reservation foar a name exists

  class NoReservation              < Http404;       end

  # No IEID was supplied

  class NoIEID                     < Http412;       end 

end # of module

