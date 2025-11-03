# constants
COUNTRY_CODES = ["AF", "AL", "DZ", "AS", "AD", "AO", "AI", "AQ", "AG", "AR", "AM", "AW", "AU", "AT", "AZ", "BS", "BH", "BD", "BB", "BY", "BE", "BZ", "BJ", "BM", "BT", "BO", "BQ", "BA", "BW", "BV", "BR", "IO", "BN", "BG", "BF", "BI", "KH", "CM", "CA", "CV", "KY", "CF", "TD", "CL", "CN", "CX", "CC", "CO", "KM", "CG", "CD", "CK", "CR", "HR", "CU", "CW", "CY", "CZ", "CI", "DK", "DJ", "DM", "DO", "EC", "EG", "SV", "GQ", "ER", "EE", "ET", "FK", "FO", "FJ", "FI", "FR", "GF", "PF", "TF", "GA", "GM", "GE", "DE", "GH", "GI", "GR", "GL", "GD", "GP", "GU", "GT", "GG", "GN", "GW", "GY", "HT", "HM", "VA", "HN", "HK", "HU", "IS", "IN", "ID", "IR", "IQ", "IE", "IM", "IL", "IT", "JM", "JP", "JE", "JO", "KZ", "KE", "KI", "KP", "KR", "KW", "KG", "LA", "LV", "LB", "LS", "LR", "LY", "LI", "LT", "LU", "MO", "MK", "MG", "MW", "MY", "MV", "ML", "MT", "MH", "MQ", "MR", "MU", "YT", "MX", "FM", "MD", "MC", "MN", "ME", "MS", "MA", "MZ", "MM", "NA", "NR", "NP", "NL", "AN", "NC", "NZ", "NI", "NE", "NG", "NU", "NF", "MP", "NO", "OM", "PK", "PW", "PS", "PA", "PG", "PY", "PE", "PH", "PN", "PL", "PT", "PR", "QA", "RO", "RU", "RW", "RE", "BL", "SH", "KN", "LC", "MF", "PM", "VC", "WS", "SM", "ST", "SA", "SN", "RS", "SC", "SL", "SG", "SX", "SK", "SI", "SB", "SO", "ZA", "GS", "SS", "ES", "LK", "SD", "SR", "SJ", "SZ", "SE", "CH", "SY", "TW", "TJ", "TZ", "TH", "TL", "TG", "TK", "TO", "TT", "TN", "TR", "TM", "TC", "TV", "UG", "UA", "AE", "GB", "US", "UM", "UY", "UZ", "VU", "VE", "VN", "VG", "VI", "WF", "EH", "YE", "ZM", "ZW", "AX"]
ACCEPTED_CARDS = { visa: "Visa", master: "MasterCard" }
# CURRENCIES = %w(USD EUR XCG)

# devices
POS_DEVICE_MODELS = %w(PAX-D200 PAX-D210 PAX-S900 PAX-S920)
POS_DEVICE_STATUSES = %w(idle assigned failure)
POS_DEVICE_FAILURES = %w(battery keyboard cable lcd printer Wi-Fi GPS other)
# shared data with public
POS_DEVICE_LINKED_BINARIES_FOLDER = "files/pos/binaries/downloads"
POS_DEVICE_BINARY_APP_PREFIX = "mainapp"
POS_DEVICE_BINARY_CACHE_KEY = "download_config"

# user types
USER_TYPES = { basic: "Basic", standard: "Standard" }
DOCUMENT_TYPES = { national_id: "National ID", passport: "Passport", utility_bill: "Utility bill" }

# account types
WALLET_ACCOUNT_TYPES = { personal: "Wallet personal account", business: "Wallet business account" }
BANK_ACCOUNT_TYPES = { current: "Bank current account", savings: "Bank savings account" }
ACCOUNT_TYPES = WALLET_ACCOUNT_TYPES.merge(BANK_ACCOUNT_TYPES)
ACCOUNT_GROUPS = { personal: "Wallet personal accounts", business: "Wallet business accounts", bank: "Bank accounts" }

# mpos services payment methods and types
MPOS_CARD_PAYMENT_METHOD_TYPES = { credit: "Credit card", debit: "Debit card" }
MPOS_CHECK_PAYMENT_METHOD_TYPES = { sft: "SFT bank",
                                    giro: "Girobank",
                                    caribe: "Banko di Caribe",
                                    vida: "Vida Nova Bank",
                                    mcb: "MCB bank",
                                    fcib: "FCIB bank",
                                    orco: "Orco bank",
                                    rbc: "RBC bank" }

# wallet transaction types
WALLET_TRANSACTION_TYPES = { bill: "Bill payment", voucher: "Voucher payment",
                             top_up: "Top up", top_up_reversal: "Top up reversal",
                             prepaid: "Pagatinu payment",
                             sale_wallet: "Wallet sale",
                             transfer: "Wallet to wallet transfer",
                             transfer_wallet_to_bank: "Wallet to bank transfer",
                             transfer_bank_to_wallet: "Bank to wallet transfer" }

# bank transaction types
BANK_TRANSACTION_TYPES = { transfer_bank_to_bank: "Bank to bank transfer",
                           bank_balance_inquiry: "Balance inquiry" }

# card auth types
# authorize, purchase, capture, refund or void -  switch types
CARD_TRANSACTION_TYPES = { card_authorization: "POS card authorization",
                           card_sale: "POS card sale",
                           card_capture: "POS card capture",
                           card_refund: "POS card refund",
                           card_void: "POS card void",
                           card_adjustment: "POS card adjustment",
                           card_reversal: "POS card reversal" }

# services transaction types
MPOS_TRANSACTION_TYPES = { bill_mpos: "POS bill payment", bill_reversal_mpos: "POS bill reversal",
                           voucher_mpos: "POS voucher payment",
                           top_up_mpos: "POS top up", top_up_reversal_mpos: "POS top up reversal",
                           sale_wallet_mpos: "POS wallet sale",
                           prepaid_mpos: "POS pagatinu payment",
                           service_mpos: "POS service payment" }.merge(CARD_TRANSACTION_TYPES)
# fees transaction types
FEES_TRANSACTION_TYPES = { bill_fee: "Bill payment fee", voucher_fee: "Voucher payment fee",
                           top_up_fee: "Top up fee", prepaid_fee: "Pagatinu payment fee",
                           transfer_fee: "Wallet to wallet transfer fee",
                           transfer_wallet_to_bank_fee: "Wallet to bank transfer fee",
                           transfer_bank_to_wallet_fee: "Bank to wallet transfer fee",
                           transfer_bank_to_bank_fee: "Bank to bank transfer fee" }

ALL_TRANSACTION_TYPES = WALLET_TRANSACTION_TYPES.merge(MPOS_TRANSACTION_TYPES).merge(FEES_TRANSACTION_TYPES).merge(BANK_TRANSACTION_TYPES)

TRX_GROUPS = { personal: "Wallet transactions",
               business: "POS transactions",
               bank: "Bank transactions" }

MPOS_SERVICES = { sell_vouchers: "Sell vouchers", sell_prepaids: "Sell pagatinu", top_up: "Wallet top-up", sale_wallet: "Wallet sale",
                  bill_payments: "Bill payments", card_authorization: "Card authorization", service_curgas: "Curgas", service_pagatinu: "Pagatinu" }

CONSTANTS_FOR_SPA = {

  # transactions
  trx_payment_methods: { cash: { name: "Cash", types: {} },
                         card: { name: "Card", types: MPOS_CARD_PAYMENT_METHOD_TYPES },
                         check: { name: "Check", types: MPOS_CHECK_PAYMENT_METHOD_TYPES } },

  trx_transaction_types: { all: ALL_TRANSACTION_TYPES,
                           wallet: { name: "Wallet transaction", types: WALLET_TRANSACTION_TYPES },
                           mpos: { name: "POS transaction", types: MPOS_TRANSACTION_TYPES },
                           bank: { name: "Bank transaction", types: BANK_TRANSACTION_TYPES },
                           fees: { name: "Fee transactions", types: FEES_TRANSACTION_TYPES } },

  trx_statuses: { approved: "Approved", declined: "Declined" },
  trx_types: { debit: "Debit", credit: "Credit" },
  trx_groups: TRX_GROUPS,

  # accounts
  wallet_account_types: WALLET_ACCOUNT_TYPES,
  bank_account_types: BANK_ACCOUNT_TYPES,
  account_types: ACCOUNT_TYPES,
  account_groups: ACCOUNT_GROUPS,

  # terminal options
  mpos_services: MPOS_SERVICES,
  accepted_cards: ACCEPTED_CARDS,

  # devices
  pos_device_models: POS_DEVICE_MODELS,
  pos_device_statuses: POS_DEVICE_STATUSES,
  pos_device_failures: POS_DEVICE_FAILURES,

  # users
  user_types: USER_TYPES,
  user_titles: { mr: "Mr.", ms: "Ms." },
  document_types: DOCUMENT_TYPES,
  document_statuses: { pending: "Pending", approved: "Approved", rejected: "Rejected" },
}

# json settings
# USER_SETTINGS = {accounts: {}, notifications: {}}
ACCOUNT_SETTINGS = { low_stock: {} }

# app env
APP_ENV = {
  build: `git rev-parse HEAD`.chomp[0..6],
  migration: DB[:schema_info].first[:version],
  time: `git log -1 --format=%cd`.chomp,
}

# sequel
require "./db/database"

# input validation
require "d_struct"
require "./models/schema_predicates"

# DB models
# admins that log in
require "./models/admin/admin"

# users
require "./models/user/user"

# accounts i.e. wallets
require "./models/account/account"
require "./models/account/voucher_stock"

# cards
require "./models/card/card"

# nfc writer
require "./models/nfc_writer/nfc_writer"

# file exchange logs
require "./models/file_exchange_log/file_exchange_log"

# terminals
require "./models/terminal/terminal"
require "./models/terminal/cashier"
require "./models/device/device"

# transactions
require "./models/transaction/transaction"

# audits, polymorfic associations to other models
require "./models/audit"

# events, logs errors and suspicious activity
require "./models/event"

# messages
require "./models/message/message"

# uploads
require "./models/document"

# permissions
require "./models/permission"

# roles
require "./models/role/role"

# pages
require "./models/page/page"

# settings
require "./models/setting/setting"
require "./models/memory_cache/cache"

# fees
require "./models/fee/fee"

# limits
require "./models/limit/limit"

# reports
require "./reports/reports"

# operators/services models
require "./models/operator/operator"
require "./models/product/product" # template for vouchers and voucher stock
require "./models/voucher/voucher"
require "./models/customer/customer"
require "./models/services_lodgments"
