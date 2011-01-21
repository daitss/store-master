module StoreMaster

  class HttpError < StandardError;
    def client_message
      "#{status_code} #{status_text} - #{message.chomp('.')}.\n"
    end
  end

  # Most of the following comments are pretty darn obvious - they
  # are included for easy navigation in the generated rdoc html files.

  # Http400Error's group named exceptions as something the client did
  # wrong. It is subclassed from the HttpError exception.

  class Http400Error < HttpError;  end

  # Http400 exception: 400 Bad Request - it is subclassed from Http400Error.

  class Http400 < Http400Error
    def status_code; 400; end
    def status_text; "Bad Request"; end
  end

  # Http401 exception: 401 Unauthorized - it is subclassed from Http400Error.

  class Http401 < Http400Error
    def status_code; 401; end
    def status_text; "Unauthorized"; end
  end

  # Http403 exception: 403 Forbidden - it is subclassed from Http400Error.

  class Http403 < Http400Error
    def status_code; 403; end
    def status_text; "Forbidden"; end
  end

  # Http404 exception:  404 Not Found - it is subclassed from Http400Error.

  class Http404 < Http400Error
    def status_code; 404; end
    def status_text; "Not Found"; end
  end

  # Http405 exception: 405 Method Not Allowed - it is subclassed from Http400Error.

  class Http405 < Http400Error
    def status_code; 405; end
    def status_text; "Method Not Allowed"; end
  end

  # Http406 exception: 406 Not Acceptable - it is subclassed from Http400Error.

  class Http406 < Http400Error
    def status_code; 406; end
    def status_text; "Not Acceptable"; end
  end

  # Http408 exception: 408 Request Timeout - it is subclassed from Http400Error.

  class Http408 < Http400Error
    def status_code; 408; end
    def status_text; "Request Timeout"; end
  end

  # Http409 exception: 409 Conflict - it is subclassed from Http400Error.

  class Http409 < Http400Error
    def status_code; 409; end
    def status_text; "Conflict"; end
  end

  # Http410 exception: 410 Gone - it is subclassed from Http400Error.

  class Http410 < Http400Error
    def status_code; 410; end
    def status_text; "Gone"; end
  end

  # Http411 exception: 411 Length Required - it is subclassed from Http400Error.

  class Http411 < Http400Error
    def status_code; 411; end
    def status_text; "Length Required"; end
  end

  # Http412 exception: 412 Precondition Failed - it is subclassed from Http400Error.

  class Http412 < Http400Error
    def status_code; 412; end
    def status_text; "Precondition Failed"; end
  end

  # Http413 exception: 413 Request Entity Too Large - it is subclassed from Http400Error.

  class Http413 < Http400Error
    def status_code; 413; end
    def status_text; "Request Entity Too Large"; end
  end

  # Http414 exception: 414 Request-URI Too Long - it is subclassed from Http400Error.

  class Http414 < Http400Error
    def status_code; 414; end
    def status_text; "Request-URI Too Long"; end
  end

  # Http415 exception: 415 Unsupported Media Type - it is subclassed from Http400Error.

  class Http415 < Http400Error
    def status_code; 415; end
    def status_text; "Unsupported Media Type"; end
  end

  # Http500Error's group errors that are the server's fault.
  # It is subclassed from the HttpError exception.

  class Http500Error < HttpError;  end

  # Http500 exception: 500 Internal Service Error - it is subclassed from Http500Error.

  class Http500 < Http500Error
    def status_code; 500; end
    def status_text; "Internal Service Error"; end
  end

  # Http501 exception: 501 Not Implemented - it is subclassed from Http500Error.

  class Http501 < Http500Error
    def status_code; 501; end
    def status_text; "Not Implemented"; end
  end

  # Http503 exception: 503 Service Unavailable - it is subclassed from Http500Error.

  class Http503 < Http500Error
    def status_code; 503; end
    def status_text; "Service Unavailable"; end
  end

  # Http505 exception: 505 HTTP Version Not Supported - it is subclassed from Http500Error.

  class Http505 < Http500Error
    def status_code; 505; end
    def status_text; "HTTP Version Not Supported"; end
  end

end # of module StoreMaster
