# CLAUDE.md - AI Assistant Guide for WebPay Admin

**Version:** 1.0
**Last Updated:** 2025-11-15
**Repository:** webpay-admin-master-2

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Tech Stack](#tech-stack)
4. [Directory Structure](#directory-structure)
5. [Development Setup](#development-setup)
6. [Key Concepts](#key-concepts)
7. [Common Development Tasks](#common-development-tasks)
8. [Testing Strategy](#testing-strategy)
9. [Code Conventions](#code-conventions)
10. [Security Considerations](#security-considerations)
11. [AI Assistant Guidelines](#ai-assistant-guidelines)

---

## Project Overview

**WebPay Admin** is a Ruby-based payment processing administration system that provides backend API services for an online banking platform with mobile Point of Sale (mPOS) capabilities.

### What This System Does

- **User & Account Management**: Manages end-users, business accounts, and wallet systems
- **Transaction Processing**: Handles wallet, bank, POS/mPOS, card, voucher, and bill payments
- **Terminal Management**: Administers POS terminals for merchants with acquiring data
- **Card Issuing**: Issues and manages payment cards for users
- **Operator Services**: Integrates with telecom and utility service providers
- **Admin Portal Backend**: RESTful JSON API for the admin SPA (Single Page Application)

### Current Status

This is the **webpay-admin-master** component in Phase 1 of a larger modernization effort. See `WEBPAY_MASTER_CONTEXT.md` for the complete modernization plan.

**Critical Context:**
- Ruby version: 2.6.8 (scheduled for upgrade to 3.3)
- Security fixes in progress (Nokogiri, Rack, dry-validation)
- Production system handling real financial transactions
- High security and auditability requirements

---

## Architecture

### Application Architecture Pattern

```
┌─────────────────────────────────────────────────────────────┐
│                      config.ru (Rack Entry)                 │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  Middleware Stack                           │
│  ┌────────────────────────────────────────────────────┐    │
│  │ Rack::SecureHeaders (HSTS, XSS, etc.)             │    │
│  └────────────────────────────────────────────────────┘    │
│  ┌────────────────────────────────────────────────────┐    │
│  │ Rack::Cors (Cross-origin requests)                 │    │
│  └────────────────────────────────────────────────────┘    │
│  ┌────────────────────────────────────────────────────┐    │
│  │ Rack::Static (Asset serving)                       │    │
│  └────────────────────────────────────────────────────┘    │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              WebPayAdmin (Roda Application)                 │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │ Routing Layer (Multi-Route Plugin)                 │    │
│  │  • Public routes (login, activation)               │    │
│  │  • Authenticated routes (JWT required)             │    │
│  │  • OTP-protected routes (2FA required)             │    │
│  │  • RBAC-protected routes (Permission-based)        │    │
│  └───────────────────┬────────────────────────────────┘    │
│                      │                                       │
│                      ▼                                       │
│  ┌────────────────────────────────────────────────────┐    │
│  │ Service Objects (DStruct pattern)                  │    │
│  │  • Input validation (dry-validation)               │    │
│  │  • Business logic execution                        │    │
│  │  • Response rendering                              │    │
│  └───────────────────┬────────────────────────────────┘    │
│                      │                                       │
│                      ▼                                       │
│  ┌────────────────────────────────────────────────────┐    │
│  │ Models (Sequel ORM)                                │    │
│  │  • Database operations                             │    │
│  │  • Audit trail tracking                            │    │
│  │  • Business entity logic                           │    │
│  └───────────────────┬────────────────────────────────┘    │
│                      │                                       │
└──────────────────────┼─────────────────────────────────────┘
                       │
                       ▼
        ┌──────────────────────────────┐
        │   PostgreSQL Database        │
        └──────────────────────────────┘
```

### Request Flow

```
1. HTTP Request → config.ru
2. Middleware Processing (CORS, Security Headers, Static Assets)
3. Roda Routing Tree (webpay_admin.rb)
4. Authentication Check (JWT validation) → 401 if failed
5. Authorization Check (OTP verification) → 403 if required
6. RBAC Permission Check (3-level context) → 405 if denied
7. Route Handler Execution
8. Service Object Call (validation + business logic)
9. Model Interaction (database operations with audit)
10. JSON Response Rendering
```

### Authentication & Authorization Hierarchy

```
Level 1: Public Routes
  └─ No authentication required
     Examples: /login, /activate-account/:token, /reset-password

Level 2: Authenticated Routes (JWT)
  └─ Requires valid JWT in Authorization header
     401 Unauthorized if missing/invalid

Level 3: OTP-Protected Routes (2FA)
  └─ Requires JWT + valid OTP code in memcached
     403 Forbidden if OTP not verified
     Examples: Sensitive operations, financial transactions

Level 4: RBAC-Protected Routes
  └─ Requires JWT + role-based permissions
     405 Not Allowed if permission denied
     3-level context: /:context/:id_or_action/:action
     Examples: /users/:id/update, /terminals/:id/reveal-voucher/:trx_id
```

---

## Tech Stack

### Core Framework & Server

| Component | Version | Purpose |
|-----------|---------|---------|
| Ruby | 2.6.8 | Programming language |
| Roda | ~3.x | Lightweight routing tree web framework |
| Rack | 2.2.6.4 | Web server interface |
| Puma | ~5.6 | Multi-threaded web server |

### Database & ORM

| Component | Version | Purpose |
|-----------|---------|---------|
| PostgreSQL | (varies) | Primary database |
| Sequel | latest | ORM and database toolkit |
| sequel_pg | latest | PostgreSQL adapter |
| Philtre | latest | Database filtering/search |

### Authentication & Security

| Component | Version | Purpose |
|-----------|---------|---------|
| JWT | latest | JSON Web Tokens for auth |
| BCrypt | latest | Password hashing (cost: 12 prod, 1 test) |
| ROTP | 3.3.1 | TOTP/OTP for 2FA (⚠️ upgrade scheduled) |
| Rack::SecureHeaders | latest | Security headers (HSTS, XSS, etc.) |
| Rack::Cors | ~1.1 | Cross-origin request handling |

### Validation & Data

| Component | Version | Purpose | Status |
|-----------|---------|---------|--------|
| dry-validation | 0.7.4 | Input validation | ⚠️ Ancient, upgrade to 1.10+ planned |
| dry-types | 0.7.1 | Type system | ⚠️ Needs upgrade |
| dry-logic | 0.2.2 | Predicate logic | ⚠️ Needs upgrade |
| d_struct | latest | Struct with validation | Depends on dry-* |
| Oj | latest | Fast JSON parsing | ✅ Production-ready |
| ActiveSupport | 6.1.7.3 | Core Ruby extensions | ✅ Secure |

### External Services

| Component | Version | Purpose |
|-----------|---------|---------|
| Faraday | 1.10.3 | HTTP client for APIs |
| Mail | latest | Email sending (SMTP) |
| Dalli | latest | Memcached client (sessions, OTP) |

### Development & Testing

| Component | Purpose |
|-----------|---------|
| Minitest | Primary testing framework |
| Rack::Test | HTTP request/response testing |
| VCR | HTTP interaction recording/replay |
| Timecop | Time manipulation for tests |
| Dotenv | Environment variable management |
| Pry | Interactive debugging |
| Foreman | Process management (Procfile) |
| Rerun | Auto-reload development server |

### Utilities

| Component | Purpose |
|-----------|---------|
| Prawn / Prawn-Table | PDF report generation |
| RQRCode | QR code generation (for TOTP) |
| Ibanizator | IBAN validation |
| XMLHasher | XML parsing |
| Concurrent-Ruby | Concurrency primitives |
| Filelock | File-based locking for jobs |
| TTY-Prompt / TTY-Command | Interactive console tools |

---

## Directory Structure

```
webpay-admin-master-2/
│
├── config.ru                    # Rack entry point
├── webpay_admin.rb              # Main Roda application class
├── Gemfile / Gemfile.lock       # Ruby dependencies
├── Rakefile                     # Rake tasks (testing, DB tasks)
├── Procfile                     # Foreman process definitions
├── puma.rb                      # Puma web server config
├── .ruby-version                # Ruby version (2.6.8)
├── .env.example.txt             # Environment variables template
├── console.rb                   # Interactive admin console
│
├── models.rb                    # Model loader (loads all models)
├── models/                      # Sequel models (business entities)
│   ├── admin/                   # Admin model + service objects
│   │   ├── admin.rb             # Admin model
│   │   ├── login.rb             # Login service
│   │   ├── create.rb            # CreateAdmin service
│   │   └── ...                  # Other admin services
│   ├── user/                    # User model + services
│   ├── account/                 # Account model + services
│   ├── transaction/             # Transaction model + services
│   ├── terminal/                # Terminal model + services
│   ├── card/                    # Card model + services
│   ├── operator/                # Operator model + services
│   ├── product/                 # Product/Voucher model + services
│   ├── role/                    # Role model + services
│   ├── device/                  # Device model + services
│   ├── nfc_writer/              # NFC writer model + services
│   ├── message/                 # Message model + services
│   └── ...                      # Other domain models
│
├── routes/                      # Roda route files (multi_route plugin)
│   ├── users.rb                 # User management endpoints
│   ├── accounts.rb              # Account management endpoints
│   ├── transactions.rb          # Transaction endpoints
│   ├── terminals.rb             # Terminal management endpoints
│   ├── permissions.rb           # Role/permission management
│   └── service_lodgments.rb     # Bill payment batch processing
│
├── utils.rb                     # Utility functions (error handling, filtering, etc.)
├── mailer.rb                    # Email sending functionality
├── secure_headers.rb            # Rack security headers configuration
│
├── env/                         # Environment configuration
│   ├── environment.rb           # Environment loader
│   ├── development.rb           # Development config
│   ├── test.rb                  # Test config
│   └── features.rb              # Feature flags
│
├── db/                          # Database utilities
│   ├── database.rb              # Database connection & extensions
│   ├── serializer.rb            # JSON serialization helpers
│   └── app_data/                # Application seed data
│       └── permissions.json     # RBAC permissions definition
│
├── lib/                         # Libraries and modules
│   ├── common/                  # Shared utilities
│   ├── gateway/                 # Payment gateway integration
│   ├── periodic_cron_task.rb    # Scheduled job framework
│   ├── importers/               # Data import utilities
│   └── tasks/                   # Rake tasks
│
├── plugins/                     # Custom Roda plugins
│   └── jwt.rb                   # JWT authentication plugin
│
├── test/                        # Test suite
│   ├── integration/             # End-to-end API tests
│   ├── unit/                    # Model and service unit tests
│   ├── integration_helper.rb    # Integration test setup
│   ├── unit_helper.rb           # Unit test setup
│   └── fixtures/                # Test data
│       ├── operators.json       # Test operator data
│       ├── settings.json        # Test settings
│       └── vcr_cassettes/       # Recorded HTTP interactions
│
├── reports/                     # Report generation
│   └── pdf/                     # PDF report templates
│
├── scripts/                     # Utility scripts
│
├── public/                      # Static assets (served by Rack::Static)
│   ├── index.html               # SPA entry point
│   ├── static/                  # JS/CSS bundles
│   ├── favicon.ico
│   └── icons.svg
│
├── docs/                        # Documentation
│
├── README.md                    # Basic setup instructions
├── WEBPAY_MASTER_CONTEXT.md     # Modernization project context
└── CLAUDE.md                    # This file - AI assistant guide
```

### Key Files to Understand

1. **config.ru** - Application entry point, middleware stack
2. **webpay_admin.rb** - Main Roda app, routing tree root, plugins
3. **models.rb** - Loads all model files in dependency order
4. **env/environment.rb** - Database connection, environment setup
5. **db/database.rb** - Sequel plugins, custom model extensions
6. **plugins/jwt.rb** - JWT authentication logic
7. **utils.rb** - Error handling, parameter filtering, logging
8. **console.rb** - Interactive admin console for management

---

## Development Setup

### Prerequisites

```bash
# Ruby version manager (rbenv or rvm)
# PostgreSQL 9.6+ (10+ recommended)
# Memcached (for sessions and OTP)
# Git
```

### Initial Setup

```bash
# 1. Clone repository (if not already done)
cd /path/to/webpay-admin-master-2

# 2. Install Ruby version
rbenv install 2.6.8
rbenv local 2.6.8

# 3. Install Bundler
gem install bundler

# 4. Install dependencies
bundle install

# 5. Configure environment
cp .env.example.txt .env
# Edit .env with your settings (see Environment Variables section)

# 6. Create databases
createdb webpay_dev
createdb webpay_test

# 7. Run migrations
rake db:migrate
# Note: Migration files may be in a separate repository or managed externally

# 8. Load seed data (via console)
./console.rb
# Choose option 1: Create superuser admin
# Follow prompts to create initial admin account
```

### Environment Variables

**Critical Variables** (from `.env` file):

```bash
# Application
WP_ENV=development                          # development/test/production

# Database
WP_DEV_DATABASE_URL=postgres://user:pass@localhost/webpay_dev
WP_TEST_DATABASE_URL=postgres://user:pass@localhost/webpay_test
WP_PROD_DATABASE_URL=postgres://user:pass@localhost/webpay_prod

# JWT Authentication
JWT_KEY=your-secret-key-here-min-32-chars   # CRITICAL: Use strong random key
JWT_TTL=3600                                # Token expiration (seconds)

# OTP/2FA
OTP_TTL=300                                 # OTP code expiration (5 minutes)

# CORS (SPA)
WP_SPA_HOST_URL=http://localhost:8080       # Frontend application URL

# Memcached
MEMCACHED_URL=localhost:11211               # Session and OTP storage

# Email (SMTP)
WP_SMTP_HOST=smtp.example.com
WP_SMTP_PORT=587
WP_SMTP_USER=notifications@example.com
WP_SMTP_PASS=password
ERROR_EMAIL=errors@example.com              # Exception notifications

# External Services
ISO_SWITCH_URL=http://switch:8080           # Payment switch endpoint
CRYPTO_INTERFACE=http://crypto:9090         # Encryption service
INFOSWITCH_MODULE=http://acquiring:7070     # Acquiring module

# Card Issuing
NFC_WRITER_ACCESS_TOKENS=token1,token2      # NFC writer device tokens
LOCAL_CARD_BINS=123456,654321               # Card BIN numbers

# File Uploads
UPLOADS_ROOT_FROM_WEBPAY=/path/to/uploads   # Document storage path

# Feature Flags
ACQUIRING=true                              # Enable acquiring data management
```

### Running the Application

**Development Server (with auto-reload):**
```bash
rerun -- puma -v -t 1:1 -b tcp://127.0.0.1:5555
```

**Using Foreman (recommended):**
```bash
foreman start
# Reads Procfile: web: RUBYOPT=-W0 bundle exec puma -v -C puma.rb
```

**Directly with Puma:**
```bash
bundle exec puma -v -C puma.rb
# Binds to tcp://0.0.0.0:5555 by default
```

**Access the application:**
```bash
# Health check
curl http://localhost:5555/

# Login endpoint
curl -X POST http://localhost:5555/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","password":"password123"}'
```

### Interactive Console

```bash
./console.rb

# Console menu options:
# 1. Create superuser admin
# 2. Import permissions from JSON
# 3. Import devices from JSON
# 4. Exit

# Or use IRB with app loaded:
irb -r ./webpay_admin.rb
# Access: DB, models (Admin, User, Transaction, etc.)
```

---

## Key Concepts

### 1. Service Object Pattern

Service objects encapsulate business logic using the `DStruct` pattern:

```ruby
# Example: models/admin/login.rb
class Login < DStruct::DStruct
  def self.call(context)
    obj = new(context.params)
    obj.add_validation_schema LoginSchema  # Dry-validation schema

    return context.render_error(obj.errors) unless obj.valid?

    # Business logic
    admin = Admin.find_by_email(obj.email)
    return context.render_error("Invalid credentials") unless admin
    return context.render_error("Account locked") if admin.locked?

    # Verify password
    unless BCrypt::Password.new(admin.password_hash) == obj.password
      admin.increment_failed_attempts!
      return context.render_error("Invalid credentials")
    end

    # Success
    admin.reset_failed_attempts!
    admin  # Return admin object
  end
end
```

**Pattern Usage:**
- Always validate input first
- Return early on errors
- Use `context.render_error(errors)` for validation failures
- Use `context.render_success(data)` for success responses
- Service objects are stateless (use class methods)

### 2. Authentication System (Multi-Layer)

**Layer 1: JWT Authentication**
```ruby
# In route handlers
authenticate!  # Raises 401 if JWT missing/invalid

# Sets @current_admin from JWT payload
# Access via: @current_admin[:id], @current_admin[:email], etc.
```

**Layer 2: OTP Verification (2FA)**
```ruby
# For sensitive operations
authorize!  # Raises 403 if OTP not verified

# OTP stored in memcached after POST /verify-otp
# Key: "admin:#{admin_id}:otp"
# TTL: ENV['OTP_TTL'] (default 300 seconds)
```

**Layer 3: RBAC Permissions**
```ruby
# 3-level context system
# Format: /:context/:id_or_action/:action
# Examples:
#   /users/:id/update        → context=users, id=123, action=update
#   /terminals/:id/close-day → context=terminals, id=456, action=close-day

# Check permission
has_permission?(context: 'users', action: 'update')  # Returns true/false

# Raise 405 if denied
check_permission!(context: 'users', action: 'update')
```

### 3. Audit Trail System

All model changes are automatically tracked:

```ruby
# Create with audit
Admin.create_with_audit(current_admin_id, {
  email: 'new@example.com',
  first_name: 'John'
})

# Update with audit (preferred method)
Admin.update(user_id, current_admin_id, {
  first_name: 'Jane'
})

# Without audit (system operations only)
Admin.update_without_audit(user_id, {
  last_login_at: Time.now
})

# Query audit trail
admin.audits_dataset.order(:created_at)
# Returns: id, admin_id, auditable_type, auditable_id, diff, created_at
```

**Audit Entry Structure:**
```ruby
{
  id: 12345,
  admin_id: 99,                    # Who made the change
  auditable_type: 'Admin',         # Model class name
  auditable_id: 456,               # Record ID
  diff: {                          # What changed
    'first_name' => ['John', 'Jane'],
    'updated_at' => [old_time, new_time]
  },
  created_at: timestamp
}
```

### 4. Pagination System

```ruby
# In route handler
per_page = 25
filtered = Dataset.filter_by_philtre(params)  # Apply Philtre filters
count = filtered.count
dataset = filtered.paginate(params[:page].to_i, per_page)

r.paginated_dataset(per_page, count, dataset)
# Sets response headers: X-per-page, X-total-count
# Returns paginated results
```

**Response Headers:**
```
X-per-page: 25
X-total-count: 1247
```

### 5. Validation Schemas (Dry-Validation)

```ruby
# Example schema
LoginSchema = Dry::Validation.Schema do
  required(:email).filled(:str?, :email?)
  required(:password).filled(:str?, min_size?: 8)
end

# Custom predicates (defined in db/database.rb)
predicate(:email?) { |value| value =~ /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i }
predicate(:alpha?) { |value| value =~ /\A[a-zA-Z]+\z/ }
predicate(:strong_password?) { |value|
  value.length >= 8 &&
  value =~ /[A-Z]/ &&
  value =~ /[a-z]/ &&
  value =~ /[0-9]/
}
```

### 6. Response Rendering

**Success:**
```ruby
context.render_success(data)
# HTTP 200, body: { "key": "value" }
```

**Validation Error:**
```ruby
context.render_error(errors)
# HTTP 422, body: { "error": { "email": ["is required"], ... } }
```

**Unauthorized:**
```ruby
context.render_unauthorized("Invalid token")
# HTTP 401, body: { "error": "Invalid token" }
```

**Forbidden:**
```ruby
context.render_forbidden("OTP required")
# HTTP 403, body: { "error": "OTP required" }
```

**Not Allowed:**
```ruby
context.render_not_allowed("Insufficient permissions")
# HTTP 405, body: { "error": "Insufficient permissions" }
```

### 7. Domain Models (Key Entities)

**Admin** - System administrators
```ruby
Admin.find_by_email('admin@example.com')
admin.permissions_dataset  # Associated permissions
admin.roles_dataset        # Associated roles
admin.audits_dataset       # Changes made by this admin
```

**User** - End users
```ruby
user.accounts_dataset      # Financial accounts
user.transactions_dataset  # Transaction history
user.cards_dataset         # Payment cards
user.documents_dataset     # KYC documents
```

**Account** - Financial accounts
```ruby
account.user               # Owner
account.transactions       # Transaction history
account.balance            # Current balance
account.exposure           # Credit/debit exposure
```

**Transaction** - Payments
```ruby
transaction.user           # Payer/payee
transaction.account        # Source/dest account
transaction.terminal       # POS terminal (if applicable)
transaction.type           # wallet/bank/pos/card/voucher/bill
```

**Terminal** - POS terminals
```ruby
terminal.account           # Merchant account
terminal.transactions      # Terminal transactions
terminal.cashiers          # Authorized operators
terminal.devices           # Associated devices
```

---

## Common Development Tasks

### 1. Adding a New API Endpoint

**Step 1: Create route handler** (in `routes/resource.rb`)
```ruby
# routes/users.rb
WebPayAdmin.route 'users' do |r|
  authenticate!  # Require JWT

  r.post ':id/new-action' do |id|
    authorize!   # Require OTP if sensitive
    check_permission!(context: 'users', action: 'new-action')

    user = User[id]
    return render_error('User not found') unless user

    result = User::NewAction.call(self, user)
    render_success(result)
  end
end
```

**Step 2: Create service object** (in `models/user/new_action.rb`)
```ruby
class User::NewAction < DStruct::DStruct
  def self.call(context, user)
    obj = new(context.params)
    obj.add_validation_schema NewActionSchema

    return context.render_error(obj.errors) unless obj.valid?

    # Business logic here
    user.update_without_audit(some_field: obj.value)

    # Return result
    { success: true }
  end
end

NewActionSchema = Dry::Validation.Schema do
  required(:value).filled(:str?)
end
```

**Step 3: Add permission** (in `db/app_data/permissions.json`)
```json
{
  "context": "users",
  "action": "new-action",
  "description": "Description of what this action does"
}
```

**Step 4: Test**
```ruby
# test/integration/test_users.rb
class TestUserNewAction < IntegrationHelper
  def test_new_action_success
    admin = create_admin
    user = create_user
    login_admin(admin)
    authorize_with_otp(admin)

    post "/users/#{user[:id]}/new-action", { value: 'test' }

    assert last_response.ok?
    assert_equal 'test', JSON.parse(last_response.body)['value']
  end
end
```

### 2. Adding a New Model

**Step 1: Create model file** (in `models/resource/resource.rb`)
```ruby
class Resource < Sequel::Model
  plugin :json_serializer
  plugin :timestamps
  plugin :dirty

  # Associations
  many_to_one :admin
  one_to_many :audit, as: :auditable, class: :Audit

  # Constants
  STATUSES = %w[active inactive]

  # Public attributes (exclude sensitive data)
  PUBLIC_ATTRS = %i[id name status created_at updated_at]

  # Class methods
  def self.create_with_audit(admin_id, attrs)
    DB.transaction do
      resource = create(attrs)
      Audit.create(
        admin_id: admin_id,
        auditable: resource,
        diff: attrs
      )
      resource
    end
  end

  # Instance methods
  def active?
    status == 'active'
  end
end
```

**Step 2: Add to models.rb**
```ruby
# models.rb
require_relative "models/resource/resource"
```

**Step 3: Create migration** (external tool or Sequel migration)
```ruby
Sequel.migration do
  change do
    create_table(:resources) do
      primary_key :id
      String :name, null: false
      String :status, default: 'active'
      foreign_key :admin_id, :admins
      DateTime :created_at
      DateTime :updated_at

      index :name
      index :status
    end
  end
end
```

### 3. Running Tests

```bash
# All tests
rake test

# Unit tests only (faster, no HTTP)
rake test:unit

# Integration tests only (full stack)
rake test:integration

# Single test file
m test/integration/test_users.rb

# Single test method
m test/integration/test_users.rb:25  # Line number of test method
```

### 4. Database Operations

```bash
# Console
./console.rb

# IRB with models
irb -r ./webpay_admin.rb

# In IRB:
DB.tables                          # List all tables
Admin.count                        # Count records
Admin.first                        # Get first record
Admin.where(email: 'test@x.com')   # Query
```

### 5. Adding a Permission

**Edit `db/app_data/permissions.json`:**
```json
{
  "context": "resource_name",
  "action": "action_name",
  "description": "Human-readable description"
}
```

**Import via console:**
```bash
./console.rb
# Choose option 2: Import permissions
```

**Assign to role:**
```ruby
# In console
role = Role.find(name: 'admin')
permission = Permission.find(context: 'resource_name', action: 'action_name')
role.add_permission(permission)
```

### 6. Debugging

**Add breakpoint:**
```ruby
require 'pry'
binding.pry  # Execution stops here
```

**Logging:**
```ruby
puts "=> Debug message"           # Visible in console
LOGGER.info "Info message"        # Logged to stdout
LOGGER.error "Error: #{e.message}" # Error logging
```

**Inspect request:**
```ruby
# In route handler
puts "Headers: #{request.headers}"
puts "Params: #{params}"
puts "Body: #{request.body.read}"
```

---

## Testing Strategy

### Test Structure

```
test/
├── integration_helper.rb    # Setup for integration tests
├── unit_helper.rb           # Setup for unit tests
├── integration/             # Full HTTP request/response tests
│   ├── test_permissions.rb
│   ├── test_users.rb
│   └── ...
├── unit/                    # Model and service logic tests
│   ├── test_admin_model.rb
│   └── ...
└── fixtures/                # Test data
    ├── operators.json
    └── vcr_cassettes/       # Recorded HTTP interactions
```

### Integration Tests

**Purpose:** Test full HTTP request/response cycle with authentication

```ruby
# test/integration/test_example.rb
require_relative '../integration_helper'

class TestExample < IntegrationHelper
  def test_authenticated_endpoint
    # Setup
    admin = create_admin(email: 'test@example.com')
    login_admin(admin)  # Sets Authorization header

    # Request
    get '/some-endpoint'

    # Assertions
    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal 'expected', data['key']
  end

  def test_otp_protected_endpoint
    admin = create_admin
    login_admin(admin)
    authorize_with_otp(admin)  # Verifies OTP

    post '/sensitive-action', { param: 'value' }

    assert last_response.ok?
  end

  def test_permission_denied
    admin = create_admin  # No permissions
    login_admin(admin)

    post '/protected-action'

    assert_equal 405, last_response.status  # Not Allowed
  end
end
```

**Helper Methods:**
- `create_admin(attrs = {})` - Creates admin with defaults
- `login_admin(admin)` - Logs in and sets JWT header
- `authorize_with_otp(admin)` - Simulates OTP verification
- `last_response` - Rack::Test response object
- `ok?`, `not_allowed?`, etc. - Status assertions

### Unit Tests

**Purpose:** Test model behavior and business logic without HTTP

```ruby
# test/unit/test_admin_model.rb
require_relative '../unit_helper'

class TestAdminModel < UnitHelper
  def test_password_validation
    admin = Admin.new(
      email: 'test@example.com',
      password: 'weak'
    )

    refute admin.valid?
    assert admin.errors[:password]
  end

  def test_failed_login_attempts
    admin = create_admin

    3.times { admin.increment_failed_attempts! }

    assert admin.locked?
  end
end
```

### VCR Cassettes (HTTP Recording)

**Purpose:** Record external HTTP requests for deterministic testing

```ruby
# In test
VCR.use_cassette('test_external_api') do
  response = Faraday.get('https://external-api.com/endpoint')
  assert_equal 200, response.status
end

# First run: Records HTTP interaction to test/fixtures/vcr_cassettes/test_external_api.yml
# Subsequent runs: Replays from recording (no actual HTTP request)
```

### Running Tests

```bash
# All tests
rake test

# Unit tests (fast, no HTTP)
rake test:unit

# Integration tests (slower, full stack)
rake test:integration

# Single file
m test/integration/test_users.rb

# Single test
m test/integration/test_users.rb:42
```

### Test Configuration

**BCrypt cost reduced for speed:**
```ruby
# test/integration_helper.rb
BCrypt::Engine.cost = 1  # Default 12 in production
```

**Database cleaned between tests:**
```ruby
# In test helpers
DB.tables.each { |table| DB[table].delete }
```

---

## Code Conventions

### Ruby Style

**1. Naming Conventions**
```ruby
# Classes: PascalCase
class CreateAdmin; end

# Methods: snake_case
def update_password; end

# Constants: SCREAMING_SNAKE_CASE
JWT_TTL = 3600

# Predicates: question mark suffix
def active?; end

# Dangerous methods: bang suffix
def save!; end
```

**2. File Organization**
```ruby
# One class per file (except small related classes)
# models/user/user.rb
class User < Sequel::Model
end

# models/user/create.rb
class User::Create < DStruct::DStruct
end
```

**3. Method Organization**
```ruby
class Example
  # 1. Constants
  STATUSES = %w[active inactive]

  # 2. Class methods
  def self.find_active
  end

  # 3. Instance methods (public)
  def public_method
  end

  # 4. Instance methods (private)
  private

  def private_method
  end
end
```

**4. Conditional Returns**
```ruby
# Prefer early returns
def process
  return error unless valid?
  return error unless authorized?

  # Happy path
  success
end

# Avoid deep nesting
# BAD:
if valid?
  if authorized?
    success
  else
    error
  end
else
  error
end
```

### Roda Routing Conventions

**1. Route Organization**
```ruby
# Organize by resource
WebPayAdmin.route 'users' do |r|
  authenticate!  # Apply to all sub-routes

  # List/search
  r.post ':page' do |page|
    # Paginated list
  end

  # Show
  r.get ':id/show' do |id|
    # Single resource
  end

  # Update
  r.post ':id/update' do |id|
    # Update resource
  end

  # Custom actions
  r.post ':id/custom-action' do |id|
    # Custom action
  end
end
```

**2. Route Naming**
```ruby
# Use verb-noun for actions
r.post ':id/send-message'
r.post ':id/reveal-voucher/:trx_id'
r.post ':id/close-day'

# Standard CRUD actions
r.get ':id/show'       # Read
r.post 'create'        # Create
r.post ':id/update'    # Update
r.post ':id/delete'    # Delete
```

### Sequel Model Conventions

**1. Plugins**
```ruby
class MyModel < Sequel::Model
  plugin :json_serializer  # to_json method
  plugin :timestamps       # created_at, updated_at
  plugin :dirty            # Track changes
end
```

**2. Associations**
```ruby
class User < Sequel::Model
  one_to_many :accounts
  many_to_one :role
  many_to_many :permissions, join_table: :user_permissions
  one_to_many :audits, as: :auditable, class: :Audit
end
```

**3. Dataset Methods**
```ruby
# Chainable queries
User
  .where(status: 'active')
  .order(:created_at)
  .limit(10)
  .all

# Custom dataset methods
User.dataset_module do
  def active
    where(status: 'active')
  end
end

User.active.all
```

### Service Object Conventions

**1. Structure**
```ruby
class Resource::Action < DStruct::DStruct
  def self.call(context, *args)
    # 1. Initialize
    obj = new(context.params)

    # 2. Validate
    obj.add_validation_schema ActionSchema
    return context.render_error(obj.errors) unless obj.valid?

    # 3. Business logic
    result = perform_action(obj, args)

    # 4. Return result
    result
  end
end

ActionSchema = Dry::Validation.Schema do
  required(:field).filled(:str?)
end
```

**2. Naming**
```ruby
# Verb-based names
User::Create
User::Update
Terminal::RevealVoucher
Account::AdjustExposure
```

### Security Conventions

**1. Parameter Filtering**
```ruby
# Always filter sensitive params in logs
puts "Params: #{Utils.shallow_hash_filter(params)}"

# Filters: password, token, digest, otp, image, file, data
```

**2. Public Attributes**
```ruby
class Admin < Sequel::Model
  PUBLIC_ATTRS = %i[id email first_name last_name created_at]

  def to_public_hash
    values.slice(*PUBLIC_ATTRS)
  end
end

# NEVER expose: password_hash, otp_code, reset_password_token, etc.
```

**3. Audit Trail**
```ruby
# Always use audit methods for user-initiated changes
Admin.update(id, current_admin_id, attrs)

# Use without_audit only for system operations
Admin.update_without_audit(id, { last_login_at: Time.now })
```

---

## Security Considerations

### Critical Security Rules

**1. NEVER Expose Sensitive Data**

Sensitive fields that must NEVER be exposed in API responses:
- `password_hash`
- `password_history`
- `otp_code`
- `reset_password_token`
- `activation_token`
- `api_key` (for operators)
- Card numbers (except masked: `****1234`)
- Voucher codes (unless explicitly revealed with permission)

**2. ALWAYS Validate Input**

```ruby
# BAD: Direct parameter usage
User.create(params)

# GOOD: Validation first
obj = new(params)
obj.add_validation_schema UserCreateSchema
return render_error(obj.errors) unless obj.valid?
User.create(obj.to_hash)
```

**3. ALWAYS Check Permissions**

```ruby
# For any data access or modification
check_permission!(context: 'users', action: 'update')

# For sensitive operations
authorize!  # Requires OTP verification
```

**4. ALWAYS Audit Changes**

```ruby
# Use audit-enabled methods
Admin.update(id, current_admin_id, attrs)
Admin.create_with_audit(current_admin_id, attrs)

# System operations (rare cases only)
Admin.update_without_audit(id, { last_login_at: Time.now })
```

### Known Vulnerabilities (In Progress)

**⚠️ CRITICAL - Being Fixed in Phase 1:**

1. **Nokogiri** (Currently: not specified, Target: ~1.16.7)
   - CVE-2022-23476 (CVSS 9.8): RCE via XML parsing
   - CVE-2024-34459 (CVSS 8.1): XSS in HTML parsing

2. **Rack** (Currently: 2.2.6.4, Target: 2.2.9)
   - CVE-2024-25126 (CVSS 7.5): ReDoS attack

3. **dry-validation** (Currently: 0.7.4, Target: 1.10+)
   - Ancient version with breaking changes
   - Security improvements in newer versions

4. **ROTP** (Currently: 3.3.1, Target: 6.3+)
   - Deprecated version
   - Security improvements in v6.x

See `WEBPAY_MASTER_CONTEXT.md` for full modernization plan.

### Security Best Practices

**1. Authentication**
- Use strong JWT secrets (min 32 characters)
- Configure appropriate JWT_TTL (default 3600s)
- Never log JWT tokens
- Validate token signature and expiration

**2. Passwords**
- Minimum 8 characters
- Require uppercase, lowercase, and number
- BCrypt cost: 12 (production), 1 (test)
- Password history tracking (prevent reuse)
- Account lockout after 3 failed attempts

**3. OTP/2FA**
- Required for sensitive operations (financial transactions, user deletion, etc.)
- OTP TTL: 300 seconds (5 minutes)
- Stored in memcached (not database)
- QR code generation for TOTP apps

**4. CORS**
- Whitelist specific origins (WP_SPA_HOST_URL)
- Explicit allowed methods
- Expose only necessary headers

**5. Secure Headers**
- HSTS: 1 year, includeSubdomains
- X-Content-Type-Options: nosniff
- X-Frame-Options: SAMEORIGIN
- X-XSS-Protection: 1; mode=block

**6. SQL Injection Prevention**
- Sequel ORM handles parameterization
- Never use string interpolation in queries
- Use dataset methods, not raw SQL

**7. XSS Prevention**
- JSON API (not HTML rendering)
- Parameter filtering
- Content-Type: application/json

**8. CSRF Protection**
- JWT-based (stateless)
- No cookies (no CSRF vulnerability)

---

## AI Assistant Guidelines

### Working on This Codebase

**1. Always Read Context First**

Before starting work:
1. Read `WEBPAY_MASTER_CONTEXT.md` for project status
2. Read this file (`CLAUDE.md`) for technical details
3. Understand which component you're working on
4. Check current phase and priorities

**2. Security-First Mindset**

This is a **production financial system**. Security is paramount:
- Never skip validation
- Never expose sensitive data
- Never bypass authentication/authorization
- Always use audit trails for user changes
- Test security implications of changes

**3. Understanding the Domain**

Key business concepts:
- **Admin**: System administrators (not end users)
- **User**: End users with accounts and cards
- **Account**: Financial accounts (wallet, bank)
- **Terminal**: POS devices for merchants
- **Transaction**: Payments (wallet, bank, POS, card, voucher, bill)
- **Operator**: Service providers (telecom, utilities)
- **Voucher**: Prepaid products (recharge codes, etc.)

**4. Code Changes**

When making changes:
- Follow existing patterns (service objects, validation, etc.)
- Add tests for new functionality
- Update relevant documentation
- Consider backward compatibility
- Check audit trail implications

**5. Testing Requirements**

All changes must include:
- Unit tests for model logic
- Integration tests for API endpoints
- Security tests (auth, permissions)
- Consider VCR for external APIs

**6. Git Workflow**

- Work on designated branch (see task context)
- Commit with clear, descriptive messages
- Reference CVEs in security fixes
- Document testing performed
- Push to correct branch

**7. Communication Style**

- Be concise and technical
- Ask clarifying questions if requirements unclear
- Explain security implications
- Highlight breaking changes
- Document assumptions

### Common Pitfalls to Avoid

**❌ DON'T:**
- Skip input validation
- Expose password_hash, otp_code, tokens in responses
- Use `params` directly without validation
- Bypass authentication/authorization checks
- Make database changes without migrations
- Skip audit trail for user-initiated changes
- Use string interpolation in SQL queries
- Log sensitive data (passwords, tokens, etc.)
- Modify multiple components simultaneously
- Push to wrong branch or main/master

**✅ DO:**
- Use service object pattern for business logic
- Validate all input with dry-validation schemas
- Check permissions before data access
- Use audit-enabled model methods
- Filter sensitive params in logs
- Follow 3-level authentication hierarchy
- Test thoroughly (unit + integration)
- Document breaking changes
- Work on one component at a time
- Push to designated feature branch

### Emergency Rollback

If a change causes issues:

```bash
# Stop application
kill $(lsof -ti:5555)

# Rollback code
git reset --hard HEAD~1  # Or specific commit

# Restore Gemfile if changed
cp Gemfile.backup.YYYYMMDD Gemfile
cp Gemfile.lock.backup.YYYYMMDD Gemfile.lock
bundle install

# Restore database if needed
# (Use database backups - outside scope of this document)

# Restart application
bundle exec puma -v -C puma.rb
```

### Getting Help

**Documentation:**
- `README.md` - Basic setup
- `WEBPAY_MASTER_CONTEXT.md` - Project context and modernization plan
- `CLAUDE.md` - This file (technical guide)
- Code comments - In-line documentation

**Code Examples:**
- `models/admin/` - Reference implementation of model + services
- `routes/users.rb` - Reference route implementation
- `test/integration/test_permissions.rb` - Reference tests

**External Resources:**
- Roda documentation: https://roda.jeremyevans.net/
- Sequel documentation: https://sequel.jeremyevans.net/
- Dry-validation: https://dry-rb.org/gems/dry-validation/

---

## Appendix

### Technology Decision Log

**Why Roda?**
- Lightweight, fast routing tree
- Plugin-based architecture
- Low memory footprint
- Better performance than Rails for API-only apps

**Why Sequel?**
- Powerful ORM with dataset methods
- Better performance than ActiveRecord
- Flexible query building
- Plugin system for extensibility

**Why DStruct for Service Objects?**
- Integrates with dry-validation
- Immutable by default
- Type-safe with dry-types
- Clear separation of concerns

**Why JWT instead of sessions?**
- Stateless authentication
- Works with SPA frontend
- Scalable (no server-side session storage)
- Mobile-friendly

**Why Memcached for OTP?**
- TTL support (automatic expiration)
- Fast in-memory storage
- Distributed (multi-server support)
- Simple key-value interface

### Performance Considerations

**Database:**
- Use eager loading to prevent N+1 queries
- Index foreign keys and frequently queried columns
- Use Philtre for efficient filtering
- Paginate large result sets (25 per page default)

**Caching:**
- Memcached for sessions and OTP
- Consider caching frequent queries
- Cache constants/configuration

**Connection Pooling:**
- Puma: Multi-threaded (1:1 in dev, 5:5 in prod)
- Database: max_connections: 10
- Memcached: Connection pool managed by Dalli

### Troubleshooting

**Common Issues:**

1. **"Database connection failed"**
   - Check WP_ENV is set
   - Verify DATABASE_URL in .env
   - Ensure PostgreSQL is running
   - Test: `psql $WP_DEV_DATABASE_URL`

2. **"JWT decode error"**
   - Check JWT_KEY matches between sessions
   - Verify Authorization header format: `Bearer <token>`
   - Check token expiration (JWT_TTL)

3. **"OTP required" (403 error)**
   - Call `POST /verify-otp` first
   - Check Memcached is running
   - Verify OTP_TTL not expired

4. **"Permission denied" (405 error)**
   - Check admin has required permission
   - Import permissions: `./console.rb` → option 2
   - Assign permission to admin's role

5. **Tests failing**
   - Check test database exists: `createdb webpay_test`
   - Set WP_ENV=test
   - Clear test database: `rake db:reset` (if task exists)

---

## Version History

- **v1.0** (2025-11-15) - Initial CLAUDE.md created
  - Comprehensive codebase analysis
  - Architecture documentation
  - Development workflows
  - AI assistant guidelines

---

**END OF CLAUDE.md**

For updates to this document, increment version and add entry to Version History.

**Last Updated:** 2025-11-15
**Maintainer:** AI-assisted documentation
**Status:** ✅ Active - Keep updated with codebase changes
