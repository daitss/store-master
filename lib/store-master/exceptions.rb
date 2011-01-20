
require 'store-master/http-exceptions'

module StoreMaster

  # SiloUnreachable exception, silo servers fault (subclassed Http500): system failure.

  class SiloUnreachable           < Http500; end

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

  class DriveByError              < StandardError; end

  # Some Precondition failed on storing to a silo, could be a configuration issue like
  # bad username/password

  class SiloStoreError            < Http500;       end

  # No reservation foar a name exists

  class NoReservation             < Http404;       end

  # No IEID was supplied

  class NoIEID                    < Http412;       end 

end # of module
