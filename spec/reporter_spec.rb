require 'datyl/reporter'
require 'tempfile'

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', 'lib')

def output reporter
  output_file = Tempfile.new('rspec-reporter-output')
  output_file.unlink

  reporter.write output_file
  output_file.rewind
  output_file.read
end


describe Reporter do
    
  it "should create a report object with a simple title" do

    report = Reporter.new "Main Title"
    text = output(report)
    text.should =~ /^Main Title$/n
    text.should =~ /^::::::::::$/n
  end

  it "should create a report object with a title and subtitle" do
    report = Reporter.new "Main Title", "Subtitle"
    text = output(report)
    text.should =~ /^Main Title: Subtitle$/n
    text.should =~ /^::::::::::::::::::::$/n
  end

  it "should create a report object with lines of text and a trailing line" do
    report = Reporter.new "Main Title", "Subtitle"
    report.err 'An Error'
    report.warn 'A Warning'
    report.info 'An Info'

    text  = output(report)
    lines = text.split("\n")

    lines[2].should == 'An Error'
    lines[3].should == 'A Warning'
    lines[4].should == 'An Info'

    text[-1].chr.should == "\n"   # indicates blank line
    text[-2].chr.should == "\n"
  end

  it "should not be interesting if it is empty" do
    report = Reporter.new "Main Title", "Subtitle"
    report.interesting?.should == false
  end    

  it "should be interesting if it has content" do
    report = Reporter.new 'Main Title', 'Subtitle'
    report.info 'booga booga'
    report.interesting?.should == true
  end    

  it "should insert blank lines when we 'info' without an argument" do
    Reporter.max_lines_to_write = 10
    report = Reporter.new 'Main Title', 'Subtitle'

    report.info 'this'
    report.info 
    report.info 'a test'
    
    lines = output(report).split("\n")
    lines[2].should == 'this'
    lines[3].should == ''
    lines[4].should == 'a test'
  end

  it "should clip out extra lines" do
    Reporter.max_lines_to_write = 10
    report = Reporter.new 'Main Title', 'Subtitle'

    100.times do |num|
      report.info "Line #{num}"
    end

    text = output(report)

    # We're expecting something along the lines of this:

    # Main Title: Subtitle
    # ::::::::::::::::::::
    # Note: 90 of 100 lines were discarded - see the system log for the complete report.
    # Line 0
    # Line 1
    # Line 2
    # Line 3
    # Line 4
    #  ...
    # Line 95
    # Line 96
    # Line 97
    # Line 98
    # Line 99

    lines = text.split("\n")

    lines.shift.should == 'Main Title: Subtitle'
    lines.shift.should == ':' * 20
    
    lines.shift.should =~ /^Note: 90 of 100 lines were discarded/

    lines[0].should  == 'Line 0'
    lines[4].should  == 'Line 4'
    lines[5].should  == ' ...'
    lines[6].should  == 'Line 95'
    lines[10].should == 'Line 99'

    lines.count.should == 11
  end



end
