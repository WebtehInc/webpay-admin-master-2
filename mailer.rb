require 'tilt/erb'
require 'rqrcode'

class Mailer < Roda

  plugin :mailer
  plugin :render

  route do |r|
    from_email = MemoryCache.fetch_setting('email_from_address')[0]

    # admin activation email
    r.on 'admin' do
      r.mail 'activate' do |admin|
        puts '=> sending admin activation email ...'
        from from_email
        to admin[:email]
        subject "[#{WebPayAdmin.opts[:app_name]}] - activate your account"
        html_part render('admin/activate', locals: {admin: admin, qr_code: generate_qr_code(admin[:otp_code], admin[:email])})
      end

      r.mail 'qr-code' do |admin|
        puts '=> sending qr code email ...'
        from from_email
        to admin[:email]
        subject "[#{WebPayAdmin.opts[:app_name]}] - Two factor authentication code"
        html_part render('admin/qr_code', locals: {admin: admin, qr_code: generate_qr_code(admin[:otp_code], admin[:email])})
      end
    end

    # password reset email
    r.on 'login' do
      r.mail 'reset_password' do |user|
        puts "=> sending email to #{user[:email]} for password reset ..."
        from from_email
        to user[:email]
        subject "[#{WebPayAdmin.opts[:app_name]}] - password reset request"
        html_part render('login/reset_password', locals: {user: user})
      end
    end

    r.on 'app' do
      puts '=> sending exception email ...'
      r.mail 'exception' do |e, context, time_spent|
        from from_email
        to Mailer.opts[:error_email]
        subject "ERROR: [#{WebPayAdmin.opts[:app_name]}] #{time_spent} sec - #{e.class}: #{e.message}"
        html_part render('app/exception', locals: {e: e, context: context})
      end
    end

    r.on 'user' do
      puts '=> sending document status ...'
      r.mail 'document_status' do |user, document|
        from from_email
        to user[:email]
        subject "[#{WebPayAdmin.opts[:app_name]}] - document status update"
        html_part render('user/document_status', locals: {user: user, document: document})
      end

      r.mail 'qr-code' do |user|
        puts '=> sending qr code email ...'
        from from_email
        to user[:email]
        subject "[#{WebPayAdmin.opts[:app_name]}] - Two factor authentication code"
        html_part render('user/qr_code', locals: {user: user, qr_code: generate_qr_code(user[:otp_code], user[:email])})
      end
    end

    r.on 'operator' do
      r.mail 'export' do |operator, date|
        puts '=> sending export stats ...'
        from from_email
        to operator.email # operator[:email] is string, its not serialized to array
        subject "[#{WebPayAdmin.opts[:app_name]}] - #{operator.name}: batch export statistics for #{date}"

        fels = FileExchangeLog.where(operator_code: operator.code, finished_at: date...(date+1), status: 'processed')
        stats = {
          file_logs: fels.all,
          totals: {
            payment_count:   fels.where(file_type: 'payment').sum(:trx_count),
            payment_amount:  fels.where(file_type: 'payment').sum(:trx_sum_amount),
            reversal_count:  fels.where(file_type: 'refund').sum(:trx_count),
            reversal_amount: fels.where(file_type: 'refund').sum(:trx_sum_amount),
          }
        }
        html_part render('operator/export_stats', locals: {operator: operator, date: date, stats: stats})
      end
    end
  end

  def generate_qr_code(otp_code, email)
    # change size based on uri length
    otp_uri = ROTP::TOTP.new(otp_code).provisioning_uri("#{WebPayAdmin.opts[:app_name].gsub(' ', '-')}:#{email}")
    qr_size = 8
    qr_code = nil

    while qr_code == nil
      begin
        qr_code = RQRCode::QRCode.new(otp_uri, :size => qr_size, :level => :l)
      rescue RQRCode::QRCodeRunTimeError => e
        qr_size += 1
      end
    end
    qr_code
  end
end
