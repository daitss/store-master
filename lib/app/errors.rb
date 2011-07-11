# -*- coding: utf-8 -*-
#
# TODO, maybe: if we get a message with embedded newlines, break them out for the logging.

error do
  e = @env['sinatra.error']

  # Phusion passenger complains to STDERR about the dropped body data
  # unless we rewind.

  request.body.rewind if request.body.respond_to?('rewind')

  if e.is_a? StoreMaster::Http401
    Logger.warn e.client_message, @env
    response['WWW-Authenticate'] = "Basic realm=\"Password-Protected Area for Storage Master\""

    halt e.status_code, { 'Content-Type' => 'text/plain' },  e.client_message

  # The StoreMastrer::HttpError classes carry along their own messages and
  # HTTP status codes; it's safe to return these to a client.  These will
  # not need backtraces, since they are reasonably diagnostic.

  elsif e.is_a? StoreMaster::HttpError

    if e.status_code >= 500
      Logger.err e.client_message, @env
    else
      Logger.warn e.client_message, @env   # 4xx and 207 both get logged this way
    end

    halt e.status_code, { 'Content-Type' => 'text/plain' }, e.client_message

  # ConfigurationErrors are usually fatal errors, reported when
  # something hasn't been set up correctly. They have sensitive
  # information,  but are transient by nature, pre-production

  elsif e.is_a? StoreMaster::ConfigurationError
    Logger.err e.client_message, @env
    halt 500, { 'Content-Type' => 'text/plain' }, e.client_message

  # Anything else we raise is unexpected and likely to have sensitive
  # information, so we don't return the messages to the client - just
  # log it (and a back trace as well).  In the limit, we'll classify
  # and catch all of these above. (Wherever you find "raise
  # 'message...'" sprinked in the code now, it awaits your shrewd
  # refactoring.)

  else
    Logger.err "Internal Server Error - #{e.class} #{e.message}", @env
    e.backtrace.each { |line| Logger.err line, @env }
    halt 500, { 'Content-Type' => 'text/plain' }, "Internal Service Error - See system logs for more information\n"
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
