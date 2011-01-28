require 'datyl/streams'

# test_stream - generate the input file for a DataFileStream, and
# return a DataFileStream initialized from it. Examples:
#
#   test_stream([1, :a], [2, :b]) creates a file like:
#   1 a
#   2 b
#
#   test_stream([1, :a, :y], [2, :b, :z]) creates a file like:
#   1 a y
#   2 b z
#


def test_stream *list
  tempfile = Tempfile.new('test-stream-')
  list.each do |a| 
    k = a.shift
    tempfile.puts "#{k} #{a.join(' ')}"
  end
  tempfile.open
  DataFileStream.new(tempfile)
end


describe DataFileStream do

  it "should provide values as strings, when there is only a single value field in the input file" do

    stream = test_stream  [1, :a],  [2, :b], [3, :c]
    k, v   = stream.get

    k.should == '1'
    v.should == 'a'
  end

  it "should provide values as an array of strings, when there are multiple value fields in the input file" do

    stream = test_stream  [1, :a, :x],  [2, :b, :y], [3, :c, :z]
    k, v   = stream.get

    k.should == '1'
    v.should == ['a', 'x']
  end

  it "should yield all keys in a stream" do

    stream = test_stream  [1, :a],  [2, :b], [3, :c]
    keys   = []

    stream.each do |key, value|
      keys.push key
    end

    keys.should   == ['1', '2', '3']
  end

  it "should yield all values in a stream" do

    stream = test_stream  [1, :a],  [2, :b], [3, :c]
    values = []

    stream.each do |key, value|
      values.push value
    end

    values.should == ['a', 'b', 'c']
  end

  it "should yield nothing on a null stream" do

    stream = DataFileStream.new(File.open('/dev/null'))
    keys = []

    stream.each do |key, value|
      keys.push value
    end

    keys.should == []
  end

end  # of describe DataFileStream


describe UniqueStream do

  it "should remove multiple values from a stream, providing only the first-supplied value" do

    stream = UniqueStream.new(test_stream [1, :a], [1, :b], [1, :c], [2, :d])

    k, v = stream.get
    k.should == '1'
    v.should == 'a'

    k, v = stream.get
    k.should == '2'
    v.should == 'd'
  end

  it "should leave unique sequences in a stream intact" do

    stream = UniqueStream.new(test_stream [1, :a], [2, :b], [3, :c])
    keys   = []
    values = []

    stream.each do |k,v|
      keys.push   k
      values.push v
    end

    keys.should   == ['1', '2', '3']
    values.should == ['a', 'b', 'c']
  end

  it "should yield nothing on a null stream" do

    stream = UniqueStream.new(DataFileStream.new(File.open('/dev/null')))
    keys   = []

    stream.each { |key, value|  keys.push value }

    keys.should == []
  end


  it "should properly remove all multiple-keyed sequences in a stream, retaining the first encounted sequence" do

    stream = UniqueStream.new(test_stream [1, :a], [1, :b], [2, :c], [2, :d], [3, :e], [3, :f])
    
    keys   = []
    values = []

    stream.each do |k,v|
      keys.push   k
      values.push v
    end

    keys.should   == ['1', '2', '3']
    values.should == ['a', 'c', 'e']
  end

end  # of describe UniqueStream


describe MergedStream do

  it "should properly merge unique streams" do

    s1 = test_stream             [:b, '1b'], [:c, '1c'], [:d, '1d'], [:e, '1e'], [:f, '1f']
    s2 = test_stream [:a, '2a'], [:b, '2b'],             [:d, '2d'],             [:f, '2f'], [:g, '2g']

    both    = []
    first   = []
    second  = []

    MergedStream.new(s1, s2).each do |key, data1, data2|
      if data1.nil?
        second.push [ data2 ]
      elsif data2.nil?
        first.push  [ data1 ]
      else
        both.push [data1, data2]
      end
    end

    both.should    == [ ['1b', '2b'], ['1d', '2d'], ['1f', '2f'] ]
    first.should   == [ ['1c'], ['1e'] ]
    second.should  == [ ['2a'], ['2g'] ]
  end
    
end # of describe MergedStream



describe FoldedStream do

  it "should fold values for multiple keys into an array" do

    stream = FoldedStream.new(test_stream [1, :a], [1, :b], [2, :c], [2, :d], [3, :e], [3, :f], [4, :g])

    results = {}
    stream.each do |k, vs|
      results[k] = vs
    end

    results['1'].should == ['a', 'b']
    results['2'].should == ['c', 'd']
    results['3'].should == ['e', 'f']
    results['4'].should == ['g']

    results.keys.count.should == 4
  end


end  # of describe FoldedStream

