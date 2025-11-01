class Sequel::Model

  def self.serializer( options )
    file_path = options[:file_path] || './db/app_data'
    file_name = options[:file_name]
    primary_key  = options[:primary_key] || :id
    without_fields = options[:without_fields] || []

    file = "#{file_path}/#{file_name}"

    # load from file to memory
    define_singleton_method('load_from_file') do
      ctime = File.ctime(file)
      json = File.read(file)
      {ctime: ctime, data: JSON.parse(json)}
    end

    # save records to file
    define_singleton_method('save_to_file_from_db') do
      File.open( file, "w" ) do |f|
        f.puts self.select(*(self.columns - [:created_at, :updated_at] - without_fields)).order(primary_key).to_json
      end
    end

    # create records from file
    define_singleton_method('save_to_db_from_file!') do |*args|

      self.unrestrict_primary_key
      json = File.read(file)
      records_array = JSON.parse json

      if self.count > 0

          LOGGER.warn "#{self} table is not empty, pass true to force owerwrite"

          if args[0] == true # owerwrite old records
            LOGGER.warn "Trying to delete #{self} records"
            begin
              self.dataset.delete
              LOGGER.warn "#{self} table deleted!"
              import_all_records(records_array, primary_key)
            rescue => e
              LOGGER.warn "#{e.class}"
              LOGGER.warn "#{e.message}"
              LOGGER.warn "Appending new records"
              import_all_records(records_array, primary_key) # append new records
            end
          else # append new records
            import_all_records(records_array, primary_key)
          end
      else
        # import all if table is empty
        import_all_records(records_array, primary_key)
      end

      self.restrict_primary_key

    end

  end

  def self.import_all_records(records_array, primary_key)
    LOGGER.warn "Importing #{self} records ..."
    puts
    DB.transaction do
      records_array.each_with_index do |record|
        if self[record[primary_key.to_s]]
          puts "skipping #{record[primary_key.to_s]}: #{record.inspect}"
          next
        end
        puts "importing #{record[primary_key.to_s]}: #{record.inspect}"
        puts
        self.new(record).tap do |new_instance|
          raise "INVALID RECORD: #{record.inspect}" unless new_instance.save
        end
      end
    end # end transaction
  end

end