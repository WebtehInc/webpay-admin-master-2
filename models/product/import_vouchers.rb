require 'csv'

module Importers
  module ImportVouchers

    # :data, :name, :size, :operator_code
    def self.call(context, operator, params)
      file_name = "#{Time.now.strftime("%d-%m-%y %H:%M:%S")} -  #{params[:file_name]}"
      file_directory = File.path("#{WebPayAdmin.opts[:vouchers_upload_path]}/#{operator.name}/")

      # save file
      data = Importers.save_file_from_base64(file_name, file_directory, context.params[:data])

      # import vouchers
      import context, operator, "#{file_directory}/#{file_name}"
    end

    def self.import(context, operator, file_path)

      import_status = {}  # return value
      import_count = 0    # for client info

      begin
        # products hash
        # {1000=>{:id=>2, :name=>"Chippie 10", :price=>1000, :currency=>"XCG", :type=>"voucher", :operator_code=>"ch",
        # :info=>nil, :quantity=>1415, :notify_quantity=>10, :replenished_at=>nil, uploaded_count: 0, :uploaded_amount: 0} ...
        products = DB[:products].where(operator_code: operator.code).as_hash(:price)

        # add stats fields
        products.values.each{|v| v[:uploaded_count] = 0; v[:uploaded_amount] = 0}

        DB.transaction :rollback => :reraise do
          CSV.foreach(file_path, headers: false, col_sep: ',') do |row|

            # pagafasil csv format
            # H,10,160419,11,224655,27,UTS_SO70025875
            # D,2,1000,18,826,20,321,25,1229697046284,26,14571.100000,24,31122018
            # D,2,1000,18,826,20,321,25,2917100845053,26,14571.100001,24,31122018
            # T,28,2,29,2000

            # header record - skip
            next if row.size == 7

            # Trailer record - check totals
            if row.size == 5
              total_rows      = row[2].to_i
              total_amount    = row[4].to_i
              uploaded_count  = 0
              uploaded_amount = 0

              products.values.each do |product|
                uploaded_amount = uploaded_amount + product[:uploaded_amount]
                uploaded_count  = uploaded_count + product[:uploaded_count]
              end

              if total_rows != uploaded_count || total_amount != uploaded_amount
                DB.after_rollback{import_status = {error: 'Trailer record check failed.'}}
                raise Sequel::Rollback
              end
              break # dont parse this one
            end

            # row values
            parsed_price            = row[2].to_i
            parsed_currency_code    = row[4]
            parsed_institution_id   = row[6]
            parsed_value            = row[8]
            parsed_serial           = row[10]
            parsed_expiration_date  = Date.strptime(row[12], '%d%m%Y')

            product_name  = products.dig(parsed_price, :name)
            product_id    = products.dig(parsed_price, :id)

            # update totals
            begin
              products[parsed_price][:uploaded_count] = products[parsed_price][:uploaded_count] + 1
              products[parsed_price][:uploaded_amount] = products[parsed_price][:uploaded_amount] + parsed_price
            rescue
              DB.after_rollback{import_status = {error: "Error parsing file: no product with price of #{parsed_price}"}}
              raise Sequel::Rollback
            end

            # {:id=>36380, :operator_code=>"dc", :terminal_id=>204, :uid=>1, :name=>"Digicell 100",
            # :value=>"kjhtxm477gzfrtyr", :batch_number=>1, :status=>"available", :price=>10000, :currency=>"USD"}
            v = Voucher.new(operator_code: operator.code,
                            name: product_name,
                            status: 'available',
                            price: parsed_price,
                            currency: WebPayAdmin.opts[:default_curency],
                            product_id: product_id,
                            expiration_date: parsed_expiration_date,
                            institution_id: parsed_institution_id,
                            uid: parsed_serial)

            # encrypt voucher
            encrypted_data = v.encrypted_sensitive_data(value: parsed_value)
            v.value = encrypted_data[:value]
            v.default_key_label = encrypted_data[:key_label]

            # save voucher
            v.save

            # increment counter
            import_count = import_count + 1

            DB.after_commit{import_status = {quantity: import_count}}
          end # CSV loop

          # update product count
          puts "products after: #{products}"
          products.values.each do |product|
            if product[:uploaded_count] > 0
              Product[product[:id]].update(quantity: Sequel.+(:quantity, product[:uploaded_count]), replenished_at: Time.now)
            end
          end
        end # db commit

        return import_status # all is fine

      rescue Sequel::Rollback => e
        # catch rollback raise - import_status is set in rollback hook
        Utils.error_handler(e, context)
      rescue => e
        # catch other (parsing) errors
        import_status = {error: "Error parsing file: #{e.class} - #{e.message}"}
        Utils.error_handler(e, context)
      ensure
        return import_status
      end
    end

  end

  # save uploaded file
  def self.save_file_from_base64(file_name, file_path, base64_data)
    regexp = /\Adata:([-\w]+\/[-\w\+\.]+)?;base64,(.*)/m
    data_uri_parts = base64_data.match(regexp) || []
    data = Base64.decode64(data_uri_parts[2])

    # create dir on path if any doesn't exists
    FileUtils.mkdir_p file_path

    File.open("#{file_path}/#{file_name}", 'wb'){ |file| file.write(data)}
    data
  end
end
