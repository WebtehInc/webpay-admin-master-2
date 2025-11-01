module FileProcessing
  class CsvGenerator

    require 'csv'

    def initialize format, separators
      @format = format.dup.freeze
      @separators = separators.dup.freeze

      @col_sep = @separators[:col_sep] || validation_error(':col_sep is undefined in separators')
    end

    def build_header
      rv = @format.map do |key|
        raise "you can't have '#{@col_sep}' chars in the field definitions" if key =~ /#{@col_sep}/
        key
      end.to_csv(@separators)

      rv
    end

    def build_record(hash)
      rv = @format.map do |key|
        raise "record does not define field #{key}" unless hash.has_key?(key)
        hash.delete(key).to_s.gsub(/#{@col_sep}/, "_")
      end.to_csv(@separators)

      raise "unconsumed fields left: #{hash}" unless hash.empty?

      rv
    end


    private

    def validation_error str
      raise str
    end
  end
end