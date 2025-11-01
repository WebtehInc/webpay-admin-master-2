module Importers

  class FileExchangeLogger

    attr_accessor :log

    def start direction, type, file_path, options = {}
      file_name = File.basename(file_path) rescue nil
      scope = options.delete(:scope)

      if scope
        stats = scope.unordered.select{[min(:id), max(:id), count(1), sum(:amount)]}.first.values

        trx_min_id = stats[:min]
        trx_max_id = stats[:max]
        trx_count =  stats[:count]
        trx_sum_amount = stats[:sum]
      end

      self.log = FileExchangeLog.new(
        direction: direction,
        file_path: file_path,
        file_name:  file_name,
        file_type: type.to_s,
        started_at: Time.now,

        trx_min_id: trx_min_id,
        trx_max_id: trx_max_id,
        trx_count:  trx_count,
        trx_sum_amount: trx_sum_amount,

        file_reference_number: options.delete(:file_reference_number),
        company_id: options.delete(:company_id),

        status: 'new'
      )

      log.save
    end

    def announce_processed_header operator_code, file_timestamp, receiver_of_file, sender_of_file
      log.update(
        operator_code: operator_code,
        file_timestamp: file_timestamp,
        sender_id: sender_of_file,
        receiver_id: receiver_of_file,
        status: 'in_progress'
      )
      log.save
    end

    def announce_finished attrs = {}
      insert_count = attrs.delete(:insert_count)
      update_count = attrs.delete(:update_count)

      log.update(
        insert_count: insert_count,
        update_count: update_count,
        time_elapsed: Time.now-log.started_at,
        finished_at: Time.now,
        status: 'processed'
      )
      log.save
    end

    def announce_error e, attrs = {}
      return unless log
      insert_count = attrs.delete(:insert_count)
      update_count = attrs.delete(:update_count)

      if e.is_a?(Importers::Error)
        log.update(
          insert_count: insert_count,
          update_count: update_count,
          time_elapsed: Time.now-log.started_at,
          finished_at: Time.now,
          status: 'invalid'
        )
      else
        log.update(
          insert_count: insert_count,
          update_count: update_count,
          time_elapsed: Time.now-log.started_at,
          finished_at: Time.now,
          status: 'error'
        )
      end

      log.save
    end

  end

end
