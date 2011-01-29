
# A stream, for us, is a sequence of key/value pairs where the keys
# are sorted in ascending order.  The key will typically be a string
# (it must support <, >, ==); the values can be anything, but will
# often be a string or an array of strings.  All streams must support
# the following methods:
#
#    close    - cleans up the stream: it is unavailable for rewind.
#    closed?  - returns true if the stream has been closed.
#    each     - succesively yields key/value pairs off the stream.
#    eos?     - boolean signalling that we're at the End Of the Stream.
#    get      - reads a single key/value pair off the stream. Returns nil when eos? returns true.
#    rewind   - resets the stream to the beginning or the key/value pairs.
#
# Additionally, there should be a good diagnostic #to_s method on all
# stream classes; it will appear in diagnostic log messages.

require 'tempfile'

# DataFileStream takes an opened io object (the object must support
# #gets) and returns a stream. It reads white-space delimited records
# from a text file, one record per line.  Each line should have the
# same number of fields (same arity). The first field is the key; the
# successive fields make up the value.  If there is only one field for
# the value, a simple string will be returned as the value.  When
# there are two or more fields the value will be an array of strings.

class DataFileStream
  include Enumerable

  attr_accessor :io

  def initialize  io
    @io   = io
  end

  def to_s
    "#<#{self.class}##{self.object_id} from #{io.inspect}>"
  end

  def rewind
    raise "Stream #{@io} can't be rewound: it has been closed"  if @io.closed?
    @io.rewind
  end

  def eos?
    @io.eof?
  end

  def get
    return nil if eos?
    arr = _read
    if arr.length > 2
      return arr[0], arr[1..-1]
    else
      return arr[0], arr[1]
    end    
  end

  def each
    while not eos?
      yield get
    end
  end

  def closed?
    return @io.closed?
  end

  def close
    @io.close unless @io.closed?
  end

  # semi-private:

  def _read
    return *@io.gets.split(/\s+/)
  end

end

# UniqueStream takes a stream and filters it so that the returned
# stream's keys are always unique; a UniqueStream returns only the
# first encountered of multiple records in the stream it is given.

class UniqueStream 

  @stream     = nil
  @last_key   = nil
  @last_value = nil

  def initialize stream
    @stream   = stream
    @last_key, @last_value = @stream.get
  end

  def closed?
    @stream.closed?
  end

  def close
    @stream.close
  end
  
  def eos?
    @stream.eos? and @last_key.nil?
  end

  def rewind
    @stream.rewind
  end

  def get    
    key_next, value_next = @stream.get

    return get if key_next == @last_key

    key_last, value_last  = @last_key, @last_value
    @last_key, @last_value = key_next, value_next

    return key_last, value_last
  end

  def each
    while not eos?
      yield get
    end
  end
  
end

# FoldedStream is a stream filter; given a stream, it returns a stream
# that has folded values for identical keys together in an array.
# Thus the values for a FoldedStream are of mixed arity, but will
# always be an array. As for all streams, the keys must be sorted.

class FoldedStream < UniqueStream

  @last_values = nil

  def initialize stream
    @stream = stream
    key, value = @stream.get

    @last_key = key
    @last_values = [ value ]
  end


  def get    
    key_now, value_now = @stream.get

    if key_now == @last_key
      @last_values.push value_now
      return get
    end

    key_last, values_last = @last_key, @last_values

    @last_key    = key_now
    @last_values = [ value_now ]

    return key_last, values_last
  end
  
end

 
# MergedStream is a bit different from the other Stream classes in
# that it is created from two streams and that #each yields three
# objects instead of the usual two. The objects are as follows:
#
#   keys are present in both streams     - yields key, data-1, data-2
#   key exists only on the first stream  - yields key, data-1, nil
#   key exists only on the second stream - yields key, nil,    data-2
#
# The two input streams must have unique and sorted keys.

class MergedStream
  include Enumerable

  attr_accessor :streams
  
  def initialize first_stream, second_stream
    @first_stream  = first_stream
    @second_stream = second_stream
    @first_stack   = []
    @second_stack  = []
    @streams       = [ @first_stream, @second_stream ]   
    rewind
  end

  def to_s
    "#<#{self.class}##{self.object_id} from #{@streams}>"
  end

  def rewind
    @first_stream.rewind
    @second_stream.rewind
  end

  def eos?
    @first_stream.eos? and  @second_stream.eos?
  end

  def close
    @first_stream.close
    @second_stream.close
  end

  def get_first_stream
    if @first_stack.empty?
      return @first_stream.get
    else
      return @first_stack.pop, @first_stack.pop
    end
  end

  def unget_first_stream k, v
    @first_stack.push v
    @first_stack.push k
  end

  def get_second_stream
    if @second_stack.empty?
      return @second_stream.get
    else
      return @second_stack.pop, @second_stack.pop
    end
  end

  def unget_second_stream k, v
    @second_stack.push v
    @second_stack.push k
  end

  def each
    while not eos?
      k1, v1 = get_first_stream
      k2, v2 = get_second_stream

      if    k2.nil?;                              yield k1, v1,  nil
      elsif k1.nil?;                              yield k2, nil, v2
      elsif k1 <  k2; unget_second_stream k2, v2; yield k1, v1,  nil
      elsif k2 <  k1; unget_first_stream  k1, v1; yield k2, nil, v2
      elsif k1 == k2;                             yield k1, v1,  v2
      end
    end
  end
end
