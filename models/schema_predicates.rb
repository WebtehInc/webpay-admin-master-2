require 'uri'

module RFC822
  ATOM      = "[^\\x00-\\x20\\x22\\x28\\x29\\x2c\\x2e\\x3a-\\x3c\\x3e\\x40\\x5b-\\x5d\\x7f-\\u00ff]+"
  QTEXT     = "[^\\x0d\\x22\\x5c\\u0080-\\u00ff]"
  QPAIR     = "\\x5c[\\x00-\\x7f]"
  QSTRING   = "\\x22(?:#{QTEXT}|#{QPAIR})*\\x22"
  WORD      = "(?:#{ATOM}|#{QSTRING})"
  LOCAL_PT  = "#{WORD}(?:\\x2e#{WORD})*"
  ADDRESS   = "#{LOCAL_PT}\\x40(?:#{URI::REGEXP::PATTERN::HOSTNAME})?#{ATOM}"
  EMAIL    = /\A#{ADDRESS}\z/
end

module SchemaPredicates
  include Dry::Logic::Predicates

  # custom predicates
  predicate(:email?) do |value|
    !RFC822::EMAIL.match(value).nil?
  end

  predicate(:alpha?) do |value|
    !/\A[[:alpha:]]|[[:blank:]]+\z/i.match(value).nil?
  end

  predicate(:numeric?) do |value|
    !/\A[[:digit:]]+\z/i.match(value).nil?
  end

  predicate(:strong?) do |value|
    # test if a given string contains at least a lowercase letter, a uppercase, a digit, a special char and 8+ chars
    ! /^(?=.*[a-zA-Z])(?=.*[0-9])(?=.*[\W]).{8,}$/.match(value).nil?
  end

  predicate(:positive?) do |value|
   value > 0
  end

  predicate(:positive_or_zero?) do |value|
   value >= 0
  end
end
