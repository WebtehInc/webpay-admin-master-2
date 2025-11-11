# WebPay Admin Master - Deployment Guide

**Version**: v2.0.0-uat-stable
**Date**: 2025-11-11
**Ruby**: 3.3.0
**Database**: Aurora PostgreSQL 16.9

---

## 🚨 UAT Server Quick Deploy

**For UAT server deployment (Amazon Linux 2023):**

```bash
# 1. Clone and checkout uat-stable
cd /home/deploy
git clone https://github.com/WebtehInc/webpay-admin-master-2.git webpay-admin-master
cd webpay-admin-master
git checkout uat-stable

# 2. Setup environment
cp .env.example .env
vim .env  # Configure UAT-specific values

# 3. Install dependencies
bundle install

# 4. Start service
/home/deploy/bin/webpay-ctl start admin-master
```

---

## UAT Server Deployment

### Prerequisites

- AWS access (uat-vidanova profile)
- Access to i-0a10891e7609c86de via SSM
- Database credentials
- Redis and Memcached access

### Quick Start

```bash
# Connect to UAT
aws ssm start-session --profile uat-vidanova --target i-0a10891e7609c86de

# Switch to deploy user
sudo su - deploy

# Clone repo (if not exists)
cd /home/deploy
git clone https://github.com/WebtehInc/webpay-admin-master-2.git webpay-admin-master
cd webpay-admin-master
git checkout uat-stable

# Setup environment
cp .env.example .env

# Edit .env with real credentials:
# - WP_DEV_DATABASE_URL (Aurora password)
# - SESSION_SECRET (openssl rand -hex 64)
# - JWT_KEY (openssl rand -base64 32)
# - NFC_WRITER_API_KEY (if using NFC writer)
vim .env

# Install dependencies
bundle install

# Start service
/home/deploy/bin/webpay-ctl start admin-master

# Verify
/home/deploy/bin/webpay-ctl status admin-master
tail -f /var/log/webpay/admin-master.log
```

### UAT Environment Variables

**Required in .env:**
- `WP_DEV_DATABASE_URL` - Aurora PostgreSQL connection
- `REDIS_URL` - ElastiCache Redis
- `MEMCACHED_URL` - ElastiCache Memcached
- `SESSION_SECRET` - Session encryption key
- `JWT_KEY` - JWT token signing key
- `CORS_ALLOWED_ORIGINS` - Admin SPA URL
- `WP_SPA_HOST_URL` - Admin SPA URL

See `.env.example` for full configuration template.

---

## Update Deployment

```bash
cd /home/deploy/webpay-admin-master/v2-current

# Stop service
/home/deploy/bin/webpay-ctl stop admin-master

# Pull latest code
git fetch origin
git checkout uat-stable
git pull origin uat-stable

# Update dependencies
bundle install

# Start service
/home/deploy/bin/webpay-ctl start admin-master

# Verify
/home/deploy/bin/webpay-ctl status admin-master
tail -f /var/log/webpay/admin-master.log
```

---

## Troubleshooting

### Service Won't Start

```bash
# Check Ruby version
ruby --version  # Should be 3.3.0

# Check database connectivity
psql -h uat-aurora-pg16.cluster... -U postgres -d webpay_development -c "SELECT 1;"

# Check Redis connectivity
redis-cli -h uat-webpay-redis.ray4je.ng.0001.use1.cache.amazonaws.com ping

# Check logs
tail -50 /home/deploy/webpay-admin-master/v2-current/log/puma.stderr.log
```

### Port Already in Use

```bash
# Find process using port 5555
lsof -i :5555

# Kill if needed
kill <PID>
```

---

## Related Documentation

- **UAT Freeze:** [UAT-FREEZE-v2.0.0.md](../../UAT-FREEZE-v2.0.0.md)
- **Infrastructure:** [AWS_UAT_Deployment/UAT-INFRASTRUCTURE-DISCOVERY.md](../../AWS_UAT_Deployment/UAT-INFRASTRUCTURE-DISCOVERY.md)

---

**Last Updated:** November 11, 2025
**Version:** v2.0.0-uat-stable
