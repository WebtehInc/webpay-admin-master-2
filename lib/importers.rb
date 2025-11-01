module Importers

  ROOT_DIRECTORY = (ENV['WP_FILE_EXCHANGE_DIR'] || '/tmp') + "/webpay/file_exchange"

  WORKING_SUBDIRECTORIES = ['error', 'invalid', 'in_progress', 'processed']


  class Error < RuntimeError; end

  class AlreadyProcessed < Error; end
  class InvalidRecord < Error; end
  class InvalidTotals < Error; end
  class UnknownOperator < Error; end

  class ValidationError < Error; end

end

# TODO: extract?
require_relative "file_processing"

require_relative "importers/helpers"
require_relative "importers/quick_book_helpers"
require_relative "importers/balance_helpers"
require_relative "importers/transaction_helpers"
Dir["./lib/importers/*.rb"].each {|file| require file }