source "https://rubygems.org"

# ruby version
ruby "2.6.8"

# tools
gem "rake", "~> 13.0", ">= 13.0.6"
gem "foreman"
gem "rerun"
gem "irb"

# server
gem "puma", "~> 5.6"
gem "puma_worker_killer"

# db
gem "sequel"
gem "sequel_pg", require: "sequel"
gem "philtre"
gem "pg"

# faster JSON
gem "oj"

# web
gem "rack", "2.2.6.4"
gem "rack-cors", "~> 1.1", ">= 1.1.1"
gem "roda"
gem "roda-symbolized_params"
gem "tilt"
gem "useragent"

# jwt
gem "jwt"
gem "bcrypt"

# totp
gem "rotp", "3.3.1" # v4.0 will break otp codes
gem "rqrcode"

# memcached
gem "dalli"

# validation, THESE ARE ANCIENT
# d_struct should be updated
gem "dry-configurable", "0.1.4"
gem "dry-equalizer", "0.2.0"
gem "dry-logic", "0.2.2"
gem "dry-container", "0.3.1"
gem "dry-types", "0.7.1"
gem "dry-validation", "0.7.4"
gem "d_struct" # depends on above dry gems

# console
gem "tty-prompt"
gem "tty-command"

# iban
gem "ibanizator"

# for HTTP apis
gem "faraday", "1.10.3"
gem "xmlhasher"
gem "activesupport", "6.1.7.3"

# file lock functions (prevents multiple import/export jobs of same kind)
gem "filelock"

# for concurrency, TODO: remove me with sidekiq, or something
gem "concurrent-ruby"

# reporting
gem "prawn"
gem "prawn-table"

# mail
gem "mail"

group :development_dependencies do
  gem "dotenv"
  gem "pry"

  # testing
  gem "minitest"
  gem "vcr"
  gem "timecop"
  gem "rack-test"
  gem "m" # run tests individually
end
