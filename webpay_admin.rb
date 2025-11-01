require "roda"
require "sequel"

# faster JSON
require "oj"
Oj.mimic_JSON

# load env settings from file
puts "* Loading env from .dotenv file"
require "dotenv"
Dotenv.load

require "./utils"
require "./env/environment"
require "./models"
require "./mailer"

# libs
require "./lib/common"
require "./lib/gateway"
require "./lib/periodic_cron_task"
require "./lib/importers"

# move to gem
require "./plugins/jwt"

class WebPayAdmin < Roda
  plugin :request_headers
  plugin :json
  plugin :json_parser
  plugin :symbolized_params
  plugin :pass
  plugin :placeholder_string_matchers # placeholder symbol matchers are deprecated by default and will be removed in Roda 3

  # load routes folder
  plugin :multi_route
  Dir["./routes/*.rb"].each { |f| require f }

  # load env settings
  plugin :environments
  include Environment

  # include custom request/response methods
  plugin :module_include
  request_module do

    # login user and render jwt
    def finalize_login(admin, context)
      Admin.update_login_data(admin[:id], old_data = admin.values, self)
      LoginTrail.insert(admin[:id], self)
      context.send_token!(admin[:id], admin: admin.values.except(:password_hash, :otp_code, :password_history, :reset_password_token, :activation_token),
                                      permissions: admin.permissions_dataset.to_hash_groups(:context, :action),
                                      spa_file_name: $SPA_FILE_NAME)
    end

    # return paginated dataset
    def paginated_dataset(per_page, count, dataset)
      response.headers["X-per-page"] = per_page
      response.headers["X-total-count"] = count
      dataset
    end
  end

  # hooks
  plugin :hooks
  after do |res| # instrument request
    puts("Time: #{Time.now - @start_time} sec")
  end

  # error handler
  plugin :error_handler
  error do |error|
    Utils.error_handler(error, self)
    { error: error.class, message: error.message }
  end

  # start routing
  route do |r|
    response["Content-Type"] = "application/json"

    @start_time = Time.now
    # puts "#{@start_time}: #{r.request_method} #{r.path}" # we have similar line from puma
    puts "Params: #{Utils.shallow_hash_filter(params)}" unless params.empty?

    # public
    r.root do
      # returns index.html
      ["It works!"]
    end

    r.post "login" do
      puts "=> logging in ..."
      admin = Login.call(self)
      r.finalize_login(admin, self) if admin
    end

    r.on "activate-account/:token" do |token|
      r.get do
        Admin.find_values_by_attrs([:email, :first_name, :last_name], activation_token: token).try(:to_hash)
      end
      r.post do
        puts "=> activating admin ..."
        r.finalize_login(ActivateAccount.call(self), self)
      end
    end

    r.on "reset-password" do
      puts "=> resetting password ..."

      r.on ":token" do |token|
        puts "=> getting admin by reset password token ..."
        admin = Admin.find_all_values_by_attrs(reset_password_token: token)

        r.get do
          admin.try(:public_values)
        end

        r.post do
          puts "=> token ok, updating password ..."
          r.finalize_login(admin, self) if ResetPassword.call(admin, self)
        end
      end

      # check email and generate reset token
      r.post do
        puts "=> getting admin by email ..."
        admin = Admin.find_values_by_attrs([:id, :email, :first_name, :last_name], email: params[:email]).try(:to_hash)
        if admin
          puts "=> generating reset password token ..."
          token = Utils.generate_random_token
          Admin.update_without_audit(admin[:id], reset_password_token: token)
          admin[:token] = token
          Mailer.sendmail("/login/reset_password", admin)
          render_success(message: "password reset done")
        else
          puts "=> no admin with given email ..."
          render_success # do not reveal non existent email to client
        end
      end
    end

    # for cache on client
    r.get "constants" do
      { pages: DB[:pages].select(:title, :body, :slug).all,
       operators: DB[:operators].select(:name, :code, :type, :currency).all,
       products: DB[:products].select(:id, :name, :operator_code, :type).order(:name).all,
       features: FEATURES,
       constants: CONSTANTS_FOR_SPA.merge(card_bins: WebPayAdmin.opts[:local_card_bins],
                                          card_states: Card::STATES,
                                          card_types: Card::TYPES,
                                          account_states: Account::STATES,
                                          nfc_writers_count: WebPayAdmin.opts[:nfc_writer_access_tokens].size) }
    end

    r.get "info" do
      APP_ENV
    end

    r.on "api" do
      r.on "issuing" do
        r.post "init-nfc-writer" do
          puts "=> initializing nfc writer ..."
          InitNFCWriter.call(self)
        end
        r.post "configure-nfc-writer" do
          puts "=> configuring nfc writer ..."
          ConfigureNFCWriter.call(self)
        end
        r.post "download-card-data" do
          puts "=> issuing card ..."
          DownloadCardData.call(self)
        end

        # TODO: write better handler for deleting cards in dev mode
        r.get "delete-card/:serial" do |serial|
          render_error(["not available in production"]) if WebPayAdmin.environment == :production
          puts "=> deleting card with serial #{serial}..."
          Card.where(serial_number: serial).last.try(:delete).try(:values).try(:to_json)
        end
      end

      r.on "terminal" do
        r.post "init" do
          InitTerminal.call(self)
        end
      end

      r.on "operators/manage-accounts" do
        r.post do
          puts "=> managing operator accounts ..."
          OperatorManageAccounts.call(self)
        end
      end
    end

    # private routes started - 401
    # admin must log in to continue
    authenticate!

    r.post "verify-otp" do
      puts "=> verifying otp ..."
      VerifyOtp.call(self)
    end

    r.post "logout" do
      puts "=> logging out ..."
      Logout.call(self)
    end

    # RBAC routes started based on 3 level context - 405
    # level 1 /:context
    # level 2 /:context/:id_or_action
    # level 3 /:context/:id/:action OR /:context/:action/:id
    admin = Admin[admin_id]
    unless admin.superuser
      r.on ":context" do |context| # level 1 check
        permissions = admin.permissions_dataset.to_hash_groups(:context, :action) # fetch all permissions in groups {"users"=>["show", "update", ...]}
        render_not_allowed unless permissions[context]

        r.on ":id_or_action" do |id_or_action| # level 2 check
          render_not_allowed unless permissions[context].include?(id_or_action) unless id_or_action.to_i.to_s == id_or_action # do not check ids which are numbers

          r.on ":action" do |action| # level 3 check
            render_not_allowed unless permissions[context].include?(action)
            r.pass  # level 3 ok
          end
          r.pass    # level 2 ok
        end
        r.pass      # level 1 ok
      end
    end

    r.on "operators" do
      # OTP not required, TODO: add this to UI
      r.post ":id/generate-api-key" do |id|
        puts "=> generate api key for operator ..."
        UpdateOperator::GenerateApiKey.call(id, self)
      end

      # OTP required, TODO: remove to outher scope
      authorize!
      r.post ":id/update" do |id|
        puts "=> updating operator ..."
        UpdateOperator.call(id, self)
      end
      r.post "add-customer" do
        puts "=> create customer ..."
        CreateCustomer.call(self)
      end
      r.get do
        puts "=> getting operators ..."
        Operator.order(:name).all
      end
    end

    # OTP routes started - 403
    # TODO: move above previous block
    authorize!

    r.on "products" do
      r.post ":id/update" do |id|
        puts "=> updating product ..."
        UpdateProduct.call(id, self)
      end
      r.post ":id/upload-vouchers" do |id|
        puts "=> uploading vouchers ..."
        UploadVouchers.call(id, self)
      end
      r.get do
        puts "=> getting products with available voucher quantities..."
        Product.stock_statistics
      end
    end

    r.on "fees" do
      r.post ":id/update" do |id|
        puts "=> updating fee ..."
        UpdateFee.call(id, self)
      end
      r.get do
        puts "=> getting fees ..."
        Fee.order(:id).all
      end
    end

    r.on "limits" do
      r.post ":id/update" do |id|
        puts "=> updating limit ..."
        UpdateLimit.call(id, self)
      end
      r.get do
        puts "=> getting limits ..."
        Limit.order(:id).all
      end
    end

    r.on "events" do
      r.post ":page" do |page|
        puts "=> getting events ..."
        r.paginated_dataset(*Event.paginate(page, params[:search])).all
      end
    end

    r.get "audits/:page/:model_name/:model_id" do |page, model_name, model_id|
      puts "=> getting audits ..."
      # some records have string primary key - model_string_id
      # [:id, :model_name, :model_id, :diff, :created_at, :updated_at, :user_id, :admin_id, :model_string_id]
      model_attr = /\A[[:digit:]]+\z/i.match(model_id) ? :model_id : :model_string_id
      r.paginated_dataset(*Audit.paginate(page, params[:search],
                                          DB[:audits___a].join(:admins___ad, id: :admin_id).where(model_attr => model_id, model_name: model_name).
        select(:a__created_at, :a__diff, :ad__first_name, :ad__last_name).reverse(:a__id))).all
    end

    r.on "pages" do
      r.post ":id/update" do |id|
        puts "=> updating page ..."
        [Page.update(id, admin_id, params)]
      end
      r.get do
        puts "=> getting all pages ..."
        Page.order(:title).all
      end
    end

    r.on "settings" do
      r.post ":name/update" do |name|
        puts "=> updating setting ..."
        # UpdateSetting.call(id, self)
        [Setting.update(name, admin_id, params)]
      end
      r.get do
        puts "=> getting all settings ..."
        Setting.order(:name).all
      end
    end

    r.on "file-logs" do
      r.post ":page" do |page|
        puts "=> getting file logs ..."
        r.paginated_dataset(*FileExchangeLog.paginate(page, params[:search])).all
      end
    end

    r.on "cards" do
      r.post "prepare-data" do
        puts "=> preparing card data ..."
        PrepareCardData.call(self)
      end
      r.post ":id/toggle-active-flag" do |id|
        puts "=> toggle active flag ..."
        card = Card[id]
        Card.update(id, admin_id, { active: !card.active })&.public_values
      end
      r.post ":page" do |page|
        puts "=> getting cards ..."
        r.paginated_dataset(*Card.paginate(page, params[:search])).all
      end
    end

    r.on "nfc-writer" do
      r.post "prepare-init-data" do
        puts "=> preparing nfc writer init data ..."
        PrepareNFCWriterInitData.call(self)
      end
    end

    r.on "reports" do
      r.get "voucher-stock/:type" do |type|
        puts "=> generating voucher stock #{type} report ..."
        Reports::VoucherStock.generate_pdf.render_pdf(self) if type == "pdf"
        Reports::VoucherStock.new(type).data if type == "json"
      end
      r.get "merchant-exposure/:type" do |type|
        puts "=> generating merchant exposure #{type} report ..."
        Reports::MerchantExposure.generate_pdf.render_pdf(self) if type == "pdf"
        Reports::MerchantExposure.new(type).data if type == "json"
      end
      r.get "merchant-voucher-purchase/:type" do |type|
        puts "=> generating merchant voucher purchase #{type} report ..."
        Reports::MerchantVoucherPurchase.generate_pdf.render_pdf(self) if type == "pdf"
        Reports::MerchantVoucherPurchase.new(type).data if type == "json"
      end
      r.get "merchant-open-batch/:type" do |type|
        puts "=> generating merchant open batch #{type} report ..."
        Reports::MerchantOpenBatch.generate_pdf.render_pdf(self) if type == "pdf"
        Reports::MerchantOpenBatch.new(type).data if type == "json"
      end
    end

    r.multi_route
  end
end

# preserve config options for crypto
WebPayOpts = WebPayAdmin.opts

# load models after roda because WebPayAdmin.opts are available here
# require './models'
