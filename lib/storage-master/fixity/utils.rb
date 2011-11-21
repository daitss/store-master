require 'fileutils'
require 'optparse'

module FixityUtils

  # pluralize selects one of two phrases depending on the count passed to it
  #
  # @param [Fixnum|String] count, a number or string such as 'one'
  # @param [String] word, a singular phrase
  # @param [String] plural, a plural phrase
  # @return [String] one of the phrases

  def FixityUtils.pluralize count, word, plural
    return word if count.to_s == '1' or count.to_s.downcase == 'one'
    return plural
  end


end # of module FixityUtils
