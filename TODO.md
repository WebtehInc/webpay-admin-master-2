# WebPay Admin Master - TODO List

**Date Created**: 2025-11-02
**Component**: webpay-admin-master
**Status**: Active Development

---

## 🔴 HIGH PRIORITY

### 1. Fix Email/SMTP Configuration (Development Environment)

**File**: `env/development.rb`

**Issue**: Incomplete SMTP configuration - missing authentication parameters

**Current Code** (lines ~12-14):
```ruby
Mail.defaults do
  delivery_method :smtp, address: ENV["WP_SMTP_HOST"], port: ENV["WP_SMTP_PORT"]
end
```

**Should Be** (to match webpay-master):
```ruby
Mail.defaults do
  delivery_method :smtp,
    address: ENV["WP_SMTP_HOST"],
    port: ENV["WP_SMTP_PORT"],
    user_name: ENV["WP_SMTP_USERNAME"],
    password: ENV["WP_SMTP_PASSWORD"],
    authentication: :plain,
    enable_starttls_auto: true
end
```

**Impact**:
- ❌ Admin registration emails won't send
- ❌ Password reset emails won't send
- ❌ Activation emails won't send

**Environment Variables Needed** (add to `.env`):
```bash
WP_SMTP_HOST=smtp.gmail.com
WP_SMTP_PORT=587
WP_SMTP_USERNAME=sanchopansayelburro@gmail.com
WP_SMTP_PASSWORD=[app_password_here]
```

**Reference**: See `webpay-master/v2-current/env/development.rb` lines 12-20 for working example

**Estimated Time**: 5 minutes

**Testing**: After fix, test admin registration flow to verify email delivery

---

## 🟡 MEDIUM PRIORITY

### 2. Vue 1.x → 2.7 Migration (If Vue Components Exist)

**Status**: ⏳ Not Started
**Estimated Time**: 8-11 hours

**Check First**:
```bash
# Does webpay-admin-master have Vue components?
find . -name "*.vue" -type f
```

**If YES** (Vue components exist):
- Use automation scripts from `webpay-admin-spa` migration
- Reference: `/Users/igor/ClaudeAI/webpay-admin-spa/v2-current/MIGRATION_LESSONS.md`
- Expected issues: 35-50 (similar to webpay-admin-spa's 154 issues)

**If NO** (No Vue components):
- Skip Vue migration
- This is admin backend API only

---

### 3. Security Audit (Follow webpay-master Pattern)

**Status**: ⏳ Not Started
**Estimated Time**: 4-6 hours

**Areas to Audit**:
- SQL injection vulnerabilities
- XSS protection
- CSRF tokens
- Session management
- Password storage (bcrypt)
- Input validation

**Reference**: `webpay-master/v2-current/SECURITY_FIXES.md`

---

### 4. Deployment Documentation

**Status**: ⏳ Not Started
**Estimated Time**: 2-3 hours

**Create**: `DEPLOYMENT.md`

**Should Include**:
- Production environment setup
- Database migrations
- SMTP configuration for production
- Systemd service files
- Nginx/Apache reverse proxy config
- SSL/TLS certificates
- Environment variables list
- Deployment checklist

**Reference**: `webpay-master/v2-current/DEPLOYMENT.md` (943 lines)

---

## 🟢 LOW PRIORITY

### 5. Logging Best Practices Documentation

**Status**: ✅ Current Setup is Good
**Note**: Already using `Logger.new($stdout)` which is best practice

**Optional Enhancement**:
- Document log levels (DEBUG, INFO, WARN, ERROR)
- Add structured logging (JSON format for production)
- Log rotation policy (if needed)

---

### 6. Test Coverage Improvement

**Status**: ⏳ Not Started

**Check Current Coverage**:
```bash
# If RSpec tests exist:
bundle exec rspec --format documentation
```

**Add Tests For**:
- Email sending functionality
- Admin registration flow
- Password reset flow
- API endpoints
- Authentication/Authorization

---

## 📋 QUICK FIXES

### 7. Update .env.example.txt

**Add Missing Variables**:
```bash
# SMTP Configuration (for emails)
WP_SMTP_HOST=smtp.gmail.com
WP_SMTP_PORT=587
WP_SMTP_USERNAME=your-email@gmail.com
WP_SMTP_PASSWORD=your-app-password
```

**Estimated Time**: 2 minutes

---

## 📝 NOTES

### Related Components:
- **webpay-admin-spa**: Frontend for this backend (Vue 2.7 migration complete)
- **webpay-master**: Similar backend, used as reference pattern

### Contact:
- **Developer**: Igor
- **Date**: 2025-11-02

### Progress Tracking:
- See: `/Users/igor/ClaudeAI/WEBPAY_ECOSYSTEM_PROGRESS.md`
- Ecosystem Status: 75% complete (3/4 components)

---

**Last Updated**: 2025-11-02
**Next Review**: After webpay-admin-spa manual testing complete
