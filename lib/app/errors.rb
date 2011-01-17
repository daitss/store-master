# -*- coding: utf-8 -*-
#
# TODO, maybe: if we get a message with embedded newlines, break them out for the logging.

error do
  e = @env['sinatra.error']

  # Passenger phusion complains to STDERR about the dropped body data
  # unless we rewind.

  request.body.rewind if request.body.respond_to?('rewind')  

  # The StoreMastrer::HttpError classes carry along their own messages and
  # HTTP status codes.

  if e.is_a? StoreMaster::Http400Error
    Logger.warn e.client_message, @env
    [ halt e.status_code, { 'Content-Type' => 'text/plain' }, e.client_message ]
    
  # Next are known errors with perfectly reasonable diagnostic
  # messages; they won't need backtraces.  It seems reasonable to move
  # these into subclasses of StoreMaster::Http500Error.  It is important,
  # though, that they not leak too much information if users can cause
  # them (e.g., probing for file paths)

  elsif e.is_a? StoreMaster::ConfigurationError
    Logger.err e.client_message, @env
    [ halt 500, { 'Content-Type' => 'text/plain' }, e.client_message ]


  elsif e.is_a? StoreMaster::HttpError
    Logger.err e.client_message, @env
    [ halt e.status_code, { 'Content-Type' => 'text/plain' }, e.client_message ]
    
  # Anything else we raise, log a back trace as well.  In the limit, we'll classify and catch
  # all of these above. (Wherever you find "raise 'message...'" sprinked in the code now, it 
  # awaits your shrewd refactoring.)

  else
    Logger.err "Internal Server Error - #{e.message}", @env
    e.backtrace.each { |line| Logger.err line, @env }
    [ halt 500, { 'Content-Type' => 'text/plain' }, "500 Internal Service Error\n" ]
  end
end

# Urg.  The not_found method grabs *my* ( [ halt(404), ... ], a Bad
# Thing (© G R Fischer, 1956).  Repeat the code above for this special
# case.

not_found  do
  e = @env['sinatra.error']
  request.body.rewind if request.body.respond_to?(:rewind)  

  message = if e.is_a? StoreMaster::Http404 
              e.client_message
            else
              "404 Not Found - #{request.url} doesn't exist.\n"
            end
  Logger.warn message, @env
  content_type 'text/plain'
  message
end
