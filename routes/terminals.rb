WebPayAdmin.route 'terminals' do |r|
  r.get ':id/show' do |id|
    puts '=> getting terminal ...'
    terminal = Terminal[id]
    { transactions: {count: terminal.transactions_dataset.count},
      account: terminal.account,
      cashiers: terminal.cashiers_dataset.where(active: true).order(:full_name)}
  end
  r.post ':id/update' do |id|
    puts '=> updating terminal ...'
    UpdateTerminal.call(id, self)
  end

  # manage acquiring data on switch
  r.on ':id/acquiring-data' do |id|
    render_forbidden(:error => 'Feature not enabled') unless FEATURES[:acquiring]
    terminal = Terminal[id]

    r.get do
      puts '=> getting acquiring data ...'
      InfoSwitch::TerminalApi.new.show_terminal(authenticity_token: "Terminal:#{terminal.access_token}").tap do |resp|
        response.status = 404 if resp['status'] == 'declined'
      end
    end
    r.post 'account/:account_id' do |account_id|
      puts '=> managing acquiring data account...'
      AcquiringData::AccountData.call(id, account_id, self)
    end
    r.post do
      puts '=> managing acquiring data terminal ...'
      AcquiringData::TerminalData.call(id, self)
    end
  end

  # reveal voucher
  r.post ':id/reveal-voucher/:trx_id' do |id, trx_id|
    puts '=> revealing voucher ...'
    if voucher_trx = Transaction.where(terminal_id: id, id: trx_id, transaction_type: 'voucher_mpos').first
      voucher = voucher_trx.voucher
      voucher.update(revealed_by: admin_id, revealed_at: Time.now, revealed: true)
      {name: voucher.name, uid: voucher.uid, pin: voucher.decrypted_sensitive_data[:value]} # reveal serial an pin
    end # 404 if no voucher found
  end
  r.post ':page' do |page|
    puts '=> getting terminals ...'
    r.paginated_dataset(*Terminal.paginate(page, params[:search])).to_json(
    include: {account: {only: [:account_number, :exposure_amount, :credit_limit, :currency]}})
  end
end

WebPayAdmin.route 'cashiers' do |r|
  r.post ':page' do |page|
    puts '=> getting cashiers ...'
    r.paginated_dataset(*Cashier.paginate(page, params[:search])).all
  end
end

WebPayAdmin.route 'devices' do |r|

  # files route block is for POS binaries
  r.on 'files' do
    files_dir = POS_DEVICE_LINKED_BINARIES_FOLDER
    file_name_regex = /\A#{POS_DEVICE_BINARY_APP_PREFIX}.\d.\d.\d\z/
    invalid_file_name_error = {'Required file name format' => ["#{POS_DEVICE_BINARY_APP_PREFIX}.MAJOR.MINOR.PATCH"]}

    r.get 'audits' do
      DB[:audits___a]
        .join(:admins___ad, id: :admin_id)
        .where(model_name: 'PosBinary')
        .select(:a__created_at, :a__diff, :ad__first_name, :ad__last_name)
        .all
    end

    r.get 'download/:file_name' do |file_name|
      puts '=> downloading file ...'
      file = open("#{files_dir}/#{file_name}", 'rb')
      response.headers.merge!( "Content-Type" => 'application/octet-stream' )
      response.status = 200
      response.write file.read
      file.close
      Audit.create({model_name: 'PosBinary', admin_id: admin_id, diff: {'message' => "#{file_name} downloaded"}})
    end

    r.get do
      puts '=> geting files ...'
      Dir.entries(files_dir).sort.reverse.reduce([]) do |acc, file_name|
        if file_name.start_with?(POS_DEVICE_BINARY_APP_PREFIX)
          file_path = "#{files_dir}/#{file_name}"
          acc << {name: file_name, time: File.mtime(file_path), size: File.size(file_path)/1024}
        end
        acc
      end
    end

    r.post 'upload' do
      puts '=> uploading file ...'
      file_name = params[:file_name]
      render_error(invalid_file_name_error) unless file_name =~ file_name_regex
      data_regexp = /\Adata:([-\w]+\/[-\w\+\.]+)?;base64,(.*)/m
      data_uri_parts = params[:data].match(data_regexp) || []
      File.open("#{files_dir}/#{file_name}", 'wb'){|file| file.write(Base64.decode64(data_uri_parts[2]))}
      Audit.create({model_name: 'PosBinary', admin_id: admin_id, diff: {'message' => "#{file_name} uploaded"}})
      MemoryStore.delete(POS_DEVICE_BINARY_CACHE_KEY)
      ['ok']
    end

    r.post 'delete/:file_name' do |file_name|
      puts '=> deleting file ...'
      render_error(invalid_file_name_error) unless file_name =~ file_name_regex
      render_error('File name' => ['not found']) unless File.exists?("#{files_dir}/#{file_name}")
      File.delete("#{files_dir}/#{file_name}")
      Audit.create({model_name: 'PosBinary', admin_id: admin_id, diff: {'message' => "#{file_name} deleted"}})
      ['ok']
    end
  end

  # :id block is for device management
  r.post ':id/update' do |id|
    puts '=> updating device ...'
    UpdateDevice.call(id, self)
  end
  r.post ':id/attach' do |id|
    puts '=> attaching device ...'
    AttachDevice.call(id, self)
  end
  r.post ':id/detach' do |id|
    puts '=> detaching device ...'
    DetachDevice.call(id, self)
  end
  r.post ':page' do |page|
    puts '=> getting devices ...'
    r.paginated_dataset(*Device.paginate(page, params[:search], Device.where(type: 'pos').reverse(:id))).to_json(
    include: {terminal: {only: [:merchant_name]}})
  end
end
