require 'datyl/logger'
require 'tempfile'

class Reporter
  include Enumerable


  @counter  = nil
  @title    = nil
  @tempfile = nil
  
  def initialize title
    @counter  = 0
    @title    = title
    @tempfile = Tempfile.new("report-#{title.split(/\s+/).map{ |word| word.gsub(/[^a-zA-Z0-9]/, '').downcase }.join('-')}-")
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

end # of class Reporter



# Reporter.new('this is a test') do |report|
#   report.info "This is a test,"
#   report.warn "a warning,"
#   report.err  "an error."
#   report.each do |line|
#     puts line
#   end
# end
