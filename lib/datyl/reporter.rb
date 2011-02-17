require 'datyl/logger'
require 'tempfile'

# TODO:  rspec tests

class Reporter

  DEFAULT_MAX_LINES = 1000    # abbreviated will only write this many lines of data - first half, '...', second half.
  
  attr_reader   :title
  attr_accessor :max_lines

  def initialize title
    @max_lines = DEFAULT_MAX_LINES
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

  def info str
    @counter += 1
    Logger.info str
    @tempfile.puts str    
  end

  def warn str
    @counter += 1
    Logger.warn str
    @tempfile.puts 'Warning: ' + str
  end

  def err str
    @counter += 1
    Logger.err str
    @tempfile.puts 'ERROR: ' + str
  end

  def rewind
    @tempfile.rewind
  end

  def interesting?
    @counter > 1
  end

  def each 
    yield @title
    yield @title.gsub(/./, ':')
    yield ''
    @tempfile.rewind
    while not @tempfile.eof
      yield @tempfile.gets
    end
    yield '' if interesting?
  end

  def write io = STDERR
    each do |line|
      io.puts line
    end
  end


  #### TODO:  add abbreviated method - like write, but does:
  #
  #  data
  #  data
  #   ... N lines removed: see logs for full report ...
  #  data
  #  data
  #
  # when there's too much to write -

  def abbreviated io = STDERR
    return write(io) if @counter <= @max_lines

    io.puts @title
    io.puts @title.gsub(/./, ':')
    io.puts ''    
    io.puts "Note: #{@counter - @max_lines} lines were truncated - see logs for complete report."
    io.puts ''

    # ....

  end


end # of class Reporter
