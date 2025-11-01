module Importers
  module Helpers

    UUID_REGEX = /\.[a-f0-9-]{36}$/

    attr_accessor :operator
    attr_accessor :debug_header

    def Helpers.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      # first argument is the file name mask
      def import_balances *args, &block
        file_name_mask = args.first

        Dir[file_name_mask].sort.reverse.map do |file_name|
          begin
            new_args = args.clone
            new_args[0] = file_name
            rv = new(*new_args, &block)
            rv.import_balances
            rv
          rescue Exception => e
            log e
            rv
          end
        end
      end

      def export *args, &block
        rv = new(*args, &block)
        rv.export
        rv
      end

      def log obj
        puts obj.inspect
        if obj.is_a?(Exception) and !obj.is_a?(Importers::Error)
          puts obj.backtrace.join("\n")
        end
      end
    end

    def log obj
      D obj.inspect
      if obj.is_a?(Exception) and !obj.is_a?(Importers::Error)
        D obj.backtrace.join("\n")
      end
    end

    def db_logger
      @db_logger ||= FileExchangeLogger.new
    end

    def operator_code
      operator.try(:code)
    end

    def build_file_path dir, file_path
      raise "unknown :dir option '#{dir}'" unless Importers::WORKING_SUBDIRECTORIES.include?(dir.to_s)

      dir_name = Importers::ROOT_DIRECTORY
      dir_name += "/#{dir}"
      dir_name += "/#{operator_code}" if operator_code and dir.to_s != 'in_progress'
      FileUtils.mkdir_p dir_name

      new_file_name = dir_name + "/#{File.basename(file_path)}"
      new_file_name += ".#{SecureRandom.uuid}" unless new_file_name =~ UUID_REGEX # add UUID if necessary

      new_file_name
    end

    def strip_uuid file_name
      file_name.gsub(UUID_REGEX, '')
    end

    def move_file dir, file
      return unless file
      file.close if !file.closed?

      new_file_name = build_file_path dir, file.path

      FileUtils.mv file.path, new_file_name
      new_file_name
    end


    protected


    def handle_sql_and_record_exceptions
      yield
    rescue Sequel::UniqueConstraintViolation, PG::UniqueViolation => e
      log e # unique constraint
    rescue Sequel::DatabaseError, PG::InFailedSqlTransaction => e
      log e # failed DB transaction rolled back
    rescue Importers::InvalidRecord, Importers::InvalidTotals => e
      log e # invalid record in file
    end

    def D message
      message.to_s.split("\n").each do |line|
        puts "#{Time.now.to_s} [#{debug_header}] #{line}"
      end
    end

  end
end
