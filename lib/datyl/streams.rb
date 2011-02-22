module Streams

  # A stream, for us, is a sequence of key/value pairs where the keys
  # are sorted in ascending order.  The key will typically be a string
  # (it must support <, >, ==); the values can be anything, but will
  # often be a string or an array of strings.  All streams must support
  # the following methods:
  #
  #    close          - cleans up the stream: it is unavailable for rewind.
  #    closed?        - returns true if the stream has been closed.
  #    each do |k,v|  - succesively yields key/value pairs off the stream.
  #    eos?           - boolean signalling that we're at the End Of the Stream.
  #    k, v = get     - reads a single key/value pair off the stream. Returns nil when eos? is true.
  #    rewind         - resets the stream to the beginning or the key/value pairs; returns the stream
  #
  # Optionally, it may support
  #
  #    unget          - forget that we've read the last key/value pair
  #
  # Additionally, there should be a good diagnostic #to_s method on
  # all stream classes; that string will often appear in diagnostic
  # log messages.

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

    def initialize  io
      @io            = io
      @last_key      = nil
      @last_val      = nil
      @unget_pending = false
    end

    def to_s
      "#<#{self.class}##{self.object_id} from #{io.to_s}>"
    end

    def rewind
      raise "Stream #{@io} can't be rewound: it has been closed"  if @io.closed?
      @io.rewind
      self
    end

    def eos?
      @io.eof? and not @unget_pending
    end

    def get
      return if eos?

      if @unget_pending
         @unget_pending = false
         return @last_key, @last_val
      end

      @last_key, *tail = read
      @last_val = tail.length > 1 ? tail : tail[0]

      return @last_key, @last_val
    end

    def unget
      raise "The unget method only supports one level of unget; unfortunately, two consecutitve ungets have been called on #{self.to_s}" if @unget_pending
      @unget_pending = true
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

    def read
      return *@io.gets.split(/\s+/)
    end

  end # of class DataFileStream

  # UniqueStream takes a stream and filters it so that the returned
  # stream's keys are always unique; if a UniqueStream encounters two
  # identical keys, it returns the key/value pair of the first of
  # them, discarding the second.
  #
  # It supports unget

  class UniqueStream

    def initialize stream
      @stream = stream
      @unbuff = []
      @ungot  = false
    end

    def to_s
      "#<#{self.class}##{self.object_id} wrapping #{@stream.to_s}>"
    end

    def closed?
      @stream.closed?
    end

    def close
      @stream.close
    end

    def eos?
      @stream.eos? and not @ungot
    end

    def rewind
      @stream.rewind
      @stream
    end

    # we only support one level of unget

    def unget
      raise "The unget method only supports one level of unget; unfortunately, two consecutitve ungets have been called on #{self.to_s}" if @ungot
      @ungot = true
    end

    def get
      return if eos?

      if @ungot
         @ungot = false
         return @unbuff[0], @unbuff[1]
      end

      ku, vu = @stream.get

      loop do
        break if eos?
        k, v = @stream.get
        if k != ku
          @stream.unget
          break
        end
      end

      @unbuff = [ ku, vu ]
      return ku, vu
    end

    def each
      while not eos?
        yield get
      end
    end

  end # of class UniqueStream

  # FoldedStream is a stream filter; given a stream, it returns a stream
  # that has folded values for identical keys together in an array.
  # Thus the values for a FoldedStream are of mixed arity, but will
  # always be an array. As for all streams, the keys must be sorted.
  #
  # It subclasses UniqueStream and supports one level of unget

  class FoldedStream < UniqueStream

    def get
      return if eos?

      if @ungot
         @ungot = false
         return @unbuff[0], @unbuff[1]
      end

      ku, vu = @stream.get

      @vals = Array.new
      @vals << vu

      loop do
        break if eos?
        k, v = @stream.get
        if k != ku
          @stream.unget
          break
        else
          @vals << v
        end
      end

      @unbuff = [ ku, @vals ]
      return ku, @vals
    end

  end # of class FoldedStream


  # ComparisonStream is a bit different from the other Stream classes in
  # that
  #    - it is created from exactly two streams
  #    - ComparisonStream#each always yields the key and two data values:
  #
  #   keys are present in both streams     - yields key,  data-1, data-2
  #   key exists only on the first stream  - yields key,  data-1, nil
  #   key exists only on the second stream - yields key,  nil,    data-2
  #
  # The two input streams must have unique and sorted keys.

  class ComparisonStream
    include Enumerable

    attr_accessor :streams

    def initialize first_stream, second_stream
      @first_stream  = first_stream
      @second_stream = second_stream
      @streams       = [ @first_stream, @second_stream ]
    end

    def to_s
      "#<#{self.class}##{self.object_id} wrapping #{@streams.map{ |stream| stream.to_s }.join(', ')}>"
    end

    def rewind
      @first_stream.rewind
      @second_stream.rewind
      self
    end

    def eos?
      @first_stream.eos? and  @second_stream.eos?
    end

    def close
      @first_stream.close
      @second_stream.close
    end

    def closed?
      @first_stream.closed? and @second_stream.closed?
    end

    def get
      return if eos?

      k1, v1 = @first_stream.get
      k2, v2 = @second_stream.get

      if    k2.nil?;                        return k1,   v1, nil
      elsif k1.nil?;                        return k2,  nil,  v2
      elsif k1 <  k2; @second_stream.unget; return k1,   v1, nil
      elsif k2 <  k1; @first_stream.unget;  return k2,  nil,  v2
      elsif k1 == k2;                       return k1,   v1,  v2
      end
    end

    def each
      while not eos?
        yield get
      end
    end
  end # of class MergedStream


  # Return the next key/container pair from a list of streams; the
  # container holds values found on the streams for a given key, thus
  # is of mixed arity.

  class MultiStream
    include Enumerable

    attr_reader   :streams

    def initialize *streams
      @values_container = Array   # subclass MultiStream to use a specialized container for assembling the merged values - it must support '<<'
      @streams = streams
      @ungot   = false
      @last    = nil
    end

    def to_s
      "#<#{self.class}##{self.object_id} wrapping #{@streams.map{ |stream| stream.to_s }.join(', ')}>"
    end

    def closed?
      @streams.inject(true) { |sum, stream|  sum and stream.closed? }
    end

    def close
      @streams.each { |s| s.close }
    end

    def eos?
      not @ungot and @streams.inject(true) { |sum, stream|  sum and stream.eos? }
    end

    def rewind
      @streams.each { |s| s.rewind }
      self
    end

    def unget
      raise "The unget method only supports one level of unget; unfortunately, two consecutitve ungets have been called on #{self.to_s}" if @ungot
      @ungot = true
    end

    # Sort the keys from the the set of values returned by a GET on
    # all streams to find the smallest key; assemble a container of
    # the values that match the smallest key; push all other key/value
    # pairs back onto their associated streams for later processing.
    # Returns the key/container pair.

    def get
      if @ungot
        @ungot = false
        return @last[0], @last[1]
      end

      scorecard = []

      @streams.each do |s|
        k, v = s.get
        scorecard.push [ s, k, v ] unless k.nil?
      end

      return if scorecard.empty?

      key  = scorecard.map{ |s, k, v|  k  }.sort[0]
      vals = @values_container.new

      scorecard.each do |s, k, v|
        if k == key
          vals << v
        else
          s.unget
        end
      end

      @last = [ key, vals ]
      return    key, vals
    end


    def each
      while not eos?
        yield get
      end
    end

  end # of class MultiStream 
end # of module Streams
