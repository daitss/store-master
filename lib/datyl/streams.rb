  # A stream, for us, is a sequence of key/value pairs where the keys
  # are sorted in ascending order.  The key will typically be a string
  # (it must support <, >, ==); the values can be anything, but will
  # often be a string or an array of strings.  All streams must support
  # the following methods:

  #    new      - specialized processing for your constructor
  #    read     - return key, value pair, or nil if at end of stream
  #    eos?     - true if at end of stream
  #    rewind   - resets the stream to the beginning and returns the stream
  #
  # 
  # Then include CommonStreamMethods, which give you:
  #
  #    each do |key, value| - successively yields key/value pairs off the stream after applying filters
  #    filters              - a list of procs (takes k, v; returns true/false) that will filter the stream provided by each (not get)
  #    get                  - reads a single key/value pair off the stream. Returns nil when there is no unget pending and your provided eos? is true.
  #    unget                - push the last read key/value pair back on the stream, we'll get it on next pass - only one level deep allowed
  #    ungetting?           - for use in your eos? method, means there's a datum pending from a prior unget.
  #    <=> stream           - returns a specialized comparison stream between self and second stream
  #
  # Additionally, there should be a good diagnostic #to_s method on
  # all stream classes; that string will often appear in log messages.


module CommonStreamMethods

  def filters
    @_filters ||= []
  end

  def _passes_filters k, v      
    return false if k.nil?   
    filters.each do |proc|
      return false unless proc.call(k, v)
    end
    return true
  end

  def unget
    raise "streams error: cannot unget twice in a row" if @_handle_unget
    @_handle_unget = true
  end

  def ungetting?
    @_handle_unget
  end

  def get
    if ungetting?
      @_handle_unget = false
      return @_last
    elsif eos?
      return
    else
      return @_last = read
    end
  end

  def each
    while not eos?
      k, v = get
      yield k, v if _passes_filters(k, v)
    end
  end

   def <=> stream
     Streams::ComparisonStream.new(self, stream)
   end

end


module Streams

  require 'tempfile'

  # DataFileStream takes an opened io object (the object must support
  # #gets) and returns a stream. It reads white-space delimited records
  # from a text file, one record per line.  Each line should have the
  # same number of fields (same arity). The first field is the key; the
  # successive fields make up the value.  If there is only one field for
  # the value, a simple string will be returned as the value.  When
  # there are two or more fields the value will be an array of strings.

  class DataFileStream 

    include CommonStreamMethods

    def initialize  io
      @io = io
    end

    def to_s
      "#<#{self.class} from io #{@io}>"
    end

    def rewind
      raise "Stream #{@io} can't be rewound: it has been closed"  if @io.closed?
      @io.rewind
      self
    end

    def eos?
      @io.eof? and not ungetting?
    end

    def read
      return if @io.eof?
      head, *tail = @io.gets.strip.split(/\s+/)
      return unless head
      tail = if tail.empty?
               nil
             elsif tail.length == 1
               tail[0]
             else
               tail
             end
      return head, tail
    end

  end # of class DataFileStream

  # UniqueStream takes a stream and filters it so that the returned
  # stream's keys are always unique; if a UniqueStream encounters two
  # identical keys, it returns the key/value pair of the first of
  # them, discarding the subsequent ones.


  class UniqueStream 

    include CommonStreamMethods

    def initialize stream
      @stream  = stream
    end

    def to_s
      "#<#{self.class} wrapping #{@stream.to_s}>"
    end

    def eos?
      @stream.eos?
    end

    def rewind
      @stream.rewind
    end

    def read
      return unless upcoming = @stream.get

      loop do
        next_record = @stream.get

        if next_record.nil?
          return upcoming
        end

        if next_record[0] != upcoming[0]
          @stream.unget
          return upcoming
        end

      end
    end

  end # of class UniqueStream


  # FoldedStream is initialized from stream, returning a stream that
  # has folded the values for identical keys together in an array.
  # Thus the values for a FoldedStream are always an array, possibly
  # of mixed arity. As for all streams, the keys must be sorted.
 
  class FoldedStream 

    include CommonStreamMethods

    def initialize stream
      @stream  = stream
    end

    def to_s
      "#<#{self.class} folding #{@stream}>"
    end

    def eos?
      @stream.eos?
    end

    def rewind
      @stream.rewind
    end

    def read
      return unless upcoming = @stream.get
      vals = [ upcoming[1] ]

      loop do
        next_record = @stream.get

        if next_record.nil?
          return upcoming[0], vals
        end

        if next_record[0] == upcoming[0]
          vals.push next_record[1]
        else
          @stream.unget
          return upcoming[0], vals
        end
      end
    end

  end # of class FoldedStream


  # The MultiStream constructor takes an arbitrary number of streams.
  # The get method returns the next key/container pair from a list of streams; the
  # container holds values found on the streams for a given key, thus
  # is of mixed arity.

  class MultiStream 

    include CommonStreamMethods

    attr_reader   :streams

    def initialize *streams
      @values_container = Array   # you can subclass MultiStream to use a specialized container for assembling the merged values - it must support '<<'
      @streams = streams
    end

    def to_s
      "#<#{self.class} wrapping #{@streams.map{ |stream| stream.to_s }.join(', ')}>"
    end

    def eos?
      @streams.inject(true) { |sum, stream|  sum and stream.eos? }
    end

    def rewind
      @streams.each { |s| s.rewind }
      self
    end

    def read
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

      return key, vals
    end
  end # of class MultiStream 



  # ComparisonStream is a bit different from the other Stream classes in
  # that
  #    - it is created from exactly two streams
  #    - ComparisonStream#each always yields the key and two data values:
  #
  #   keys are present in both streams     - yields key,  data-1, data-2
  #   key exists only on the first stream  - yields key,  data-1, nil
  #   key exists only on the second stream - yields key,  nil,    data-2
  #
  # Note: the two input streams must have unique and sorted keys.
  #
  # All basic streams support the <=> method,  which provides a
  # comparison stream.

  class ComparisonStream 

    attr_accessor :streams

    def initialize first_stream, second_stream
      @first_stream  = first_stream
      @second_stream = second_stream
      @streams       = [ @first_stream, @second_stream ]
    end

    def each
      while not eos?
        yield get
      end
    end

    def to_s
      "#<#{self.class} comparing stream #{@first_stream} with #{@second_stream}"
    end

    def rewind
      @first_stream.rewind
      @second_stream.rewind
      self
    end

    def eos?
      @first_stream.eos? and  @second_stream.eos?
    end

    def get
      return if eos?

      k1, v1 = @first_stream.get
      k2, v2 = @second_stream.get

      if    k2.nil?;                        return k1,   v1, nil
      elsif k1.nil?;                        return k2,  nil,  v2
      elsif k1 <  k2; @second_stream.unget; return k1,   v1, nil
      elsif k1 >  k2; @first_stream.unget;  return k2,  nil,  v2
      elsif k1 == k2;                       return k1,   v1,  v2
      end
    end


  end # of class ComparisonStream

end # of module Streams
