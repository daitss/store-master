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

include Streams

def test_stream *list
  tempfile = Tempfile.new('test-stream-')
  list.each do |a|
    k = a.shift
    tempfile.puts "#{k} #{a.join(' ')}"
  end
  tempfile.open
  DataFileStream.new(tempfile)
end

def dump_stream stream
  stream.rewind
  puts ''
  puts stream.to_s
  stream.each do |k,v|
    puts "#{k} => #{v.inspect}"
  end
  stream.rewind
end


describe DataFileStream do

  it "should provide values as strings, when there is only a single value field in the input file" do

    stream = test_stream  ['1', 'a'],  ['2', 'b'], ['3', 'c']
    k, v   = stream.get

    k.should == '1'
    v.should == 'a'
  end

  it "should provide values as an array of strings, when there are multiple value fields in the input file" do

    stream = test_stream  ['1', 'a', 'x'],  ['2', 'b', 'y'], ['3', 'c', 'z']
    k, v   = stream.get

    k.should == '1'
    v.should == ['a', 'x']
  end

  it "should yield all keys in a stream" do

    stream = test_stream  ['1', 'a'], ['2', 'b'], ['3', 'c']
    keys   = []

    stream.each do |key, value|
      keys.push key
    end

    keys.should   == [ '1', '2', '3']
  end


  it "should yield all values in a stream" do

    stream = test_stream  ['1', 'a'],  ['2', 'b'], ['3', 'c']
    values = []

    stream.each do |key, value|
      values.push value
    end

    values.should == ['a', 'b', 'c']
  end

  it "should allow us to create and return a filter" do

    stream = test_stream  ['1', 'a'], ['2', 'b'], ['3', 'c']

    proc = lambda{ |k,v| k != '3' }
    stream.filters.push proc
    
    stream.filters.include?(proc).should == true
  end


  it "should allow us to filter a stream by key" do

    stream = test_stream  ['1', 'a'], ['2', 'b'], ['3', 'c']
    keys   = []

    stream.filters.push lambda{ |k,v| k != '3' }

    stream.each do |key, value|
      keys.push key
    end
    keys.should   == [ '1', '2']
  end


  it "should allow us to filter a stream by value" do

    stream = test_stream  ['1', 'a'], ['2', 'b'], ['3', 'c']
    keys   = []

    def a_or_b  val
      val == 'a' or val == 'b'
    end

    stream.filters.push lambda{ |k,v| a_or_b(v) }

    stream.each do |key, value|
      keys.push key
    end

    keys.should   == [ '1', '2']
  end


  it "should yield nothing on a null stream" do

    stream = DataFileStream.new(File.open('/dev/null'))
    keys = []

    stream.each do |key, value|
      keys.push value
    end

    keys.should == []
  end

  it "should allow ungets on scalar-valued values" do

    stream = test_stream  ['1', 'a'], ['2', 'b'], ['3', 'c']

    k1, v1 = stream.get
    stream.unget
    k2, v2 = stream.get

    k1.should == k2
    v1.should == v2

    k1.should == '1'
    v1.should == 'a'

    k1, v1 = stream.get
    stream.unget
    k2, v2 = stream.get

    k1.should == k2
    v1.should == v2

    k1.should == '2'
    v1.should == 'b'
  end

  it "should allow ungets on array-valued values" do

    stream = test_stream  ['1', 'a0', 'a1'], ['2', 'b0', 'b1'], ['3', 'c0', 'c1']

    k1, v1 = stream.get
    stream.unget
    k2, v2 = stream.get

    k1.should == k2
    v1.should == v2

    k1.should == '1'
    v1.should == [ 'a0', 'a1' ]

    k1, v1 = stream.get
    stream.unget
    k2, v2 = stream.get

    k1.should == k2
    v1.should == v2

    k1.should == '2'
    v1.should == [ 'b0', 'b1' ]
  end



end  # of describe DataFileStream


describe UniqueStream do


  it "should yield all values in an already-uniquely-keyed stream" do

    stream = UniqueStream.new(test_stream  ['1', 'a'],  ['2', 'b'], ['3', 'c'])
    values = []

    stream.each do |key, value|
      values.push value
    end

    values.should == ['a', 'b', 'c']
  end

  it "should remove multiple keys from a scalar-valued stream, providing only the first-supplied value" do

    stream = UniqueStream.new(test_stream ['1', 'a'], ['1', 'b'], ['1', 'c'], ['2', 'd'])

    k, v = stream.get
    k.should == '1'
    v.should == 'a'

    k, v = stream.get
    k.should == '2'
    v.should == 'd'
  end

  it "should remove multiple keys from an array-valued stream, providing only the first-supplied value" do

    stream = UniqueStream.new(test_stream ['1', 'a', 'aa'], ['1', 'b', 'bb'], ['1', 'c', 'cc'], ['2', 'd', 'dd'])

    k, v = stream.get
    k.should == '1'
    v.should == [ 'a', 'aa' ]

    k, v = stream.get
    k.should == '2'
    v.should == [ 'd', 'dd' ]
  end

  it "should leave unique sequences in a stream intact" do

    stream = UniqueStream.new(test_stream ['1', 'a'], ['2', 'b'], ['3', 'c'])
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

    stream = UniqueStream.new(test_stream ['1', 'a'], ['1', 'b'], ['2', 'c'], ['2', 'd'], ['3', 'e'], ['3', 'f'])

    keys   = []
    values = []

    stream.each do |k,v|
      keys.push   k
      values.push v
    end

    keys.should   == ['1', '2', '3']
    values.should == ['a', 'c', 'e']
  end


  it "should allow unget from a stream with mulitple keys" do

    stream = UniqueStream.new(test_stream ['1', 'a'], ['1', 'b'], ['2', 'c'], ['2', 'd'], ['3', 'e'], ['3', 'f'], ['4', 'g'])

    k, v = stream.get

    k.should == '1'
    v.should == 'a'

    stream.unget

    k, v = stream.get

    k.should == '1'
    v.should == 'a'

    k, v = stream.get

    k.should == '2'
    v.should == 'c'

    stream.unget
    stream.get    # 2 again
    stream.get    # 3 ...

    k, v = stream.get

    k.should == '4'
    v.should == 'g'
  end

end  # of describe UniqueStream


describe FoldedStream do

  it "should always return values of type array" do

    stream = FoldedStream.new(test_stream ['1', '1a'], ['2', '2a', '2b'], ['3', '3a', '3b'], ['3', '3c', '3d'])
    k, vs = stream.get

    k.should  == '1'
    vs.should == [ '1a' ]

    k, vs = stream.get

    k.should  == '2'
    vs.should == [ ['2a', '2b'] ]

    k, vs = stream.get

    k.should  == '3'
    vs.should == [ ['3a', '3b'], ['3c', '3d'] ]
  end

  it "should fold values for multiple keys into an array" do

    stream = FoldedStream.new(test_stream ['1', '1a'], ['1', '1b'], ['2', '2a'], ['2', '2b'], ['3', '3a'], ['3', '3b'], ['4', '4a'])

    results = {}
    stream.each do |k, vs|
      results[k] = vs
    end

    results['1'].should == ['1a', '1b']
    results['2'].should == ['2a', '2b']
    results['3'].should == ['3a', '3b']
    results['4'].should == ['4a']

    results.keys.count.should == 4
  end

end  # of describe FoldedStream


describe MultiStream do

  it "should combine keys from multiple streams, returning the associated values as an array" do

    s1 = test_stream  ['1', 's1:k1'], ['2', 's1:k2' ],                  ['4', 's1:k4' ]
    s2 = test_stream                  ['2', 's2:k2' ], ['3', 's2:k3' ], ['4', 's2:k4' ], ['5', 's2:k5' ]
    s4 = test_stream                                   ['3', 's4:k3' ], ['4', 's4:k4' ], ['5', 's4:k5' ], ['6', 's4:k6' ]
    s3 = DataFileStream.new(File.open('/dev/null'))

    ms = MultiStream.new(s1, s2, s3, s4)

    keys = []
    vals = []

    ms.each do |k, v|
      keys.push k
      vals.push v
    end

    keys.should == [ '1',
                     '2',
                     '3',
                     '4',
                     '5',
                     '6' ]

    vals.should == [ ['s1:k1'],
                     ['s1:k2', 's2:k2'],
                     ['s2:k3', 's4:k3'],
                     ['s1:k4', 's2:k4', 's4:k4'],
                     ['s2:k5', 's4:k5'],
                     ['s4:k6'] ]
  end

  it "should allow an unget" do

    s1 = test_stream  ['1', 's1:k1'], ['2', 's1:k2' ],                  ['4', 's1:k4' ]
    s2 = test_stream                  ['2', 's2:k2' ], ['3', 's2:k3' ], ['4', 's2:k4' ], ['5', 's2:k5' ]
    s4 = test_stream                                   ['3', 's4:k3' ], ['4', 's4:k4' ], ['5', 's4:k5' ], ['6', 's4:k6' ]
    s3 = DataFileStream.new(File.open('/dev/null'))

    ms = MultiStream.new(s1, s2, s3, s4)

    k, v = ms.get
    k.should == '1'
    v.should == ['s1:k1']

    k, v = ms.get
    k.should == '2'
    v.should == ['s1:k2','s2:k2']

    ms.unget

    k, v = ms.get
    k.should == '2'
    v.should == ['s1:k2','s2:k2']

    k, v = ms.get
    k.should == '3'
    v.should == ['s2:k3', 's4:k3']

  end

end # of describe MultiStream


describe ComparisonStream do

  it "should properly merge simple streams" do

    s1 = test_stream              ['b', '1b'], ['c', '1c'], ['d', '1d'], ['e', '1e'], ['f', '1f']
    s2 = test_stream ['a', '2a'], ['b', '2b'],              ['d', '2d']

    in_both         = []
    only_in_first   = []
    only_in_second  = []

    ms = ComparisonStream.new(s1, s2)
    ms.each do |key, data1, data2|
      if data1.nil?
        only_in_second.push [ data2 ]
      elsif data2.nil?
        only_in_first.push  [ data1 ]
      else
        in_both.push        [ data1, data2 ]
      end
    end


    in_both.should         == [ ['1b', '2b'], ['1d', '2d'] ]
    only_in_first.should   == [ ['1c'], ['1e'], ['1f'] ]
    only_in_second.should  == [ ['2a'] ]
  end


  it "should be produced by the streams spaceship operator" do

    s1 = test_stream              ['b', '1b'], ['c', '1c']
    s2 = test_stream ['a', '2a'], ['b', '2b'],

    keys  = []

    values_in_both         = []
    values_only_in_first   = []
    values_only_in_second  = []

    (s1 <=> s2).each do | k, v1, v2 |
      keys.push k

      if v1.nil?
        values_only_in_second.push v2
      elsif v2.nil?
        values_only_in_first.push  v1
      else
        values_in_both.push        v1
        values_in_both.push        v2
      end
    end

    keys.should == [ 'a', 'b', 'c' ]

    values_in_both.should         == [ '1b', '2b' ]
    values_only_in_first.should   == [ '1c' ]
    values_only_in_second.should  == [ '2a' ]
  end

end # of describe ComparisonStream

