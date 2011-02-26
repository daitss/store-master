require 'datyl/logger'
require 'tempfile'
require 'time'

# TODO:  rspec tests

class Reporter

  @@max_lines = 1000    # abbreviated will only write this many lines of data - first half, '...', second half.

  attr_reader   :title, :counter

  def initialize title
    @start     = Time.now
    @done      = nil
    @counter   = 0
    @title     = title
    @tempfile  = Tempfile.new("report-#{title.split(/\s+/).map{ |word| word.gsub(/[^a-zA-Z0-9]/, '').downcase }.join('-')}-")
    yield self if block_given?
    self
  rescue => e
    Logger.error "Fatal error in Reporter module; #{e.class}: #{e.message}"
  ensure
    @tempfile.unlink
  end

  def self.max_lines_to_write
    @@max_lines
  end

  def self.max_lines_to_write= num
    @@max_lines = num
  end

  # for debugging - if you call 'done' the report will add to the title its total runtime - from the creation time of the constructor to the point 'done' was called'
  def done
    @done = Time.now
  end


  def info str
    @counter += 1
    Logger.info @title + ': ' + str
    @tempfile.puts str
  end

  def warn str
    @counter += 1
    Logger.warn  @title + ': ' + str
    @tempfile.puts str
  end

  def err str
    @counter += 1
    Logger.err  @title + ': ' + str
    @tempfile.puts str
  end

  def rewind
    @tempfile.rewind
  end

  def interesting?
    @counter > 0
  end

  def top_lines
    @@max_lines / 2 + (@@max_lines.odd? ? 1 : 0)
  end

  def bottom_lines
    @@max_lines / 2
  end

  def each
    title = @title + (@done ? sprintf(" (%3.2f seconds)", @done - @start) : '')
    yield title
    yield title.gsub(/./, ':')

    @tempfile.rewind

    if @counter > @@max_lines
      yield "Note: #{@counter - @@max_lines} of #{@counter} lines were discared - see the associated log for the complete report."

      top_lines.times  { yield @tempfile.gets }           # print first half

      @tempfile.rewind

      (@counter - bottom_lines).times { @tempfile.gets }  # discard middle

      yield " ..."

      while not @tempfile.eof                             # print last half
        yield @tempfile.gets
      end

    else                     # we can print everything
      @tempfile.rewind
      while not @tempfile.eof
        yield @tempfile.gets
      end
    end

    yield ''
  end


  def write io = STDOUT
    each do |line|
      io.puts line
    end
  end

end # of class Reporter
