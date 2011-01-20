# require 'store/tables'
require 'digest/md5'
require 'digest/sha1'
require 'fileutils'
require 'socket'
require 'yaml'

def my_host
  Socket.gethostname
end

@@base = Time.now.strftime("%Y%m%d_AAAAAA")

def some_name
  (@@base.succ!).clone
end

def some_data
  data = "Some test data: " + rand(100000000).to_s + "\n"
end

def some_sha1
  Digest::SHA1.hexdigest("Some test data: " + rand(100000000).to_s + "\n")
end

def some_md5
  Digest::MD5.hexdigest("Some test data: " + rand(100000000).to_s + "\n")
end

# sh = SubtractableHash.new(1 => :a, 2 => :b, 3 => :c)  # returns { 1 => :a, 3 => :c, 2 => :b }, say.
# Then sh.minus(2) # returns { 1 => :a, 3 => :c }  without modifying the 'sh' object.

class SubtractableHash < Hash
  def initialize *args
    super
    self.merge! *args unless args.empty?
  end

  def minus key
    partial = self.clone
    partial.delete key
    partial
  end
end

def some_attributes
  hash = SubtractableHash.new  :sha1 => some_sha1, :md5 => some_md5, :timestamp => DateTime.now - rand(100), :size => rand(10000), :type => 'x-application/tar'
end

def ieid
  range = 26 ** 6
  sleep (60.0 * 60.0 * 24.0) / range   # make sure we're unique, and we pause

  now  = Time.now
  mid  = Time.mktime(now.year.to_s, now.month.to_s, now.day.to_s)
  point_in_day  = ((now.to_i - mid.to_i) + now.usec/1_000_000.0) / 86400.0  # fraction of day to microsecond resolution
  point_in_ieid = (point_in_day * range).to_i    # fraction of day in fixed point, base 26: 'AAAAAA' .. 'ZZZZZZ'

  # horner's algorithm on point_in_ieid

  letters = ('A'..'Z').to_a
  frac = ''
  6.times do |i|
    point_in_ieid, rem = point_in_ieid / 26, point_in_ieid % 26
    frac += letters[rem]
  end
  sprintf('E%04d%02d%02d_%s', now.year, now.month, now.day, frac.reverse)
end
