module CurrentEnvironment
  def current_environment!

    self.environment  = :test
    LOGGER.level      = :debug # :debug, :info, :warn, :error, :fatal, :unknown

    # log sql
    DB.loggers << LOGGER

    # mail catcher
    Mail.defaults do
      delivery_method :smtp, address: ENV["WP_SMTP_HOST"], port: ENV["WP_SMTP_PORT"]
      delivery_method :test # do not send emails
    end

    # jwt
    WebPayAdmin.opts[:jwt_hmac_secret]  = 'test_key'
    WebPayAdmin.opts[:jwt_leeway]       = 60 # 60 sec
    WebPayAdmin.opts[:jwt_ttl]          = 600
    WebPayAdmin.opts[:jwt_algorithm]    = 'HS256'

    # app settings
    WebPayAdmin.opts[:app_name] = 'WebPay Administration'
    WebPayAdmin.opts[:bank_name] = 'My Bank'
    WebPayAdmin.opts[:default_curency] = 'USD'
    WebPayAdmin.opts[:failed_login_leeway] = 60 * 5
    WebPayAdmin.opts[:otp_ttl] = 3600
    WebPayAdmin.opts[:access_code_ttl] = 60 # trasient data for card issuing and devices init

    # constants for mailer
    spa_host_url = ENV['WP_SPA_HOST_URL']
    Mailer.opts[:spa_constants] = { activate_admin_path: "#{spa_host_url}/activate",
                                    reset_password_path: "#{spa_host_url}/forgotten-password"}

    # mailer constants
    Mailer.opts[:error_email] = 'damir@webteh.us' # send exceptions here

    # issuing
    WebPayAdmin.opts[:local_card_bins] = ENV["LOCAL_CARD_BINS"].split(',')
    WebPayAdmin.opts[:nfc_writer_access_tokens] = ENV["NFC_WRITER_ACCESS_TOKENS"].split(',')
    WebPayAdmin.opts[:nfc_writer_api_key] = ENV['NFC_WRITER_API_KEY']
    WebPayAdmin.opts[:mifare_new_card_key_token] = 'tmk_test:imUVOSqSv3iKZRU5KpK/eA==' # TODO: Gemalto

    ########## SERVICES ##########

    # TODO: ISO switch doesn't exist, we have jSecModule & InfoSwitch
    # ISO switch
    WebPayAdmin.opts[:iso_switch_url] = ENV['ISO_SWITCH_URL']
    WebPayAdmin.opts[:infoswitch_url] = ENV['INFOSWITCH_URL'] || 'http://tpsb-switch:17403'
    WebPayAdmin.opts[:nfc_writer_transport_key] = ENV['NFC_WRITER_TRANSPORT_KEY'] || 'tmk_test'
    WebPayAdmin.opts[:terminal_transport_key] = ENV['TERMINAL_TRANSPORT_KEY'] || 'tmk_test'

    # crypto service
    WebPayAdmin.opts[:crypto_client] = JsecModule::Crypto
  end
end
