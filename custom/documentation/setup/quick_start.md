# Quick Start Guide - Custom Code System

**Created:** 2025-06-10 08:46:00 PDT  
**Updated:** 2025-06-10 08:46:00 PDT

## 🚀 Getting Started

### 1. First-Time Setup

```bash
# 1. Verify custom folder structure
ls -la custom/

# 2. Make scripts executable
chmod +x custom/scripts/**/*.rb

# 3. Test health check
ruby custom/scripts/monitoring/health_check.rb
```

### 2. Available Custom Tools

#### Account Management Scripts
```bash
# Clean up duplicate accounts (dry-run first)
ruby custom/scripts/account_management/cleanup_duplicate_accounts.rb --dry-run

# Auto cleanup (no confirmation)
ruby custom/scripts/account_management/cleanup_duplicate_accounts_auto.rb
```

#### Health Monitoring
```bash
# Check system health
ruby custom/scripts/monitoring/health_check.rb

# Schedule regular health checks (add to cron)
# 0 */6 * * * cd /path/to/chatwoot && ruby custom/scripts/monitoring/health_check.rb
```

#### Enhanced Account Service (Ruby)
```ruby
# In Rails console or custom scripts
require_relative 'custom/lib/services/enhanced_account_service'

service = EnhancedAccountService.new('your_api_token')

# Get account statistics
stats = service.get_account_statistics
puts "Total accounts: #{stats[:total_accounts]}"
puts "Duplicates: #{stats[:duplicate_count]}"

# Find duplicates
duplicates = service.find_duplicate_accounts
puts "Found #{duplicates.size} duplicate accounts"

# Get legitimate accounts only
legitimate = service.get_legitimate_accounts
puts "#{legitimate.size} legitimate accounts"
```

## 📁 Current Custom Files

### Scripts
- `custom/scripts/account_management/cleanup_duplicate_accounts.rb` - Interactive cleanup
- `custom/scripts/account_management/cleanup_duplicate_accounts_auto.rb` - Automated cleanup  
- `custom/scripts/monitoring/health_check.rb` - System health checker

### Services
- `custom/lib/services/enhanced_account_service.rb` - Enhanced account management
- `custom/lib/utilities/logger.rb` - Custom logging utility

### Configuration
- `custom/config/integrations/twilio.yml` - Twilio configuration template

### Documentation
- `custom/documentation/troubleshooting/duplicate_accounts_cleanup.md` - Cleanup troubleshooting
- `custom/documentation/setup/deployment_guide.md` - Full deployment guide

## ⚡ Quick Commands Reference

```bash
# Health check
ruby custom/scripts/monitoring/health_check.rb

# Account statistics
curl -s -H "api_access_token: YOUR_TOKEN" \
  "https://your-domain.com/platform/api/v1/accounts" | jq length

# View backups
ls -la custom/backup/

# Check logs (if Rails integration setup)
tail -f custom/logs/custom_$(date +%Y%m%d).log
```

## 🔧 Integration Status

### ✅ Completed
- [x] Custom folder structure created
- [x] Account cleanup scripts functional
- [x] Health monitoring system
- [x] Backup system implemented
- [x] Documentation created

### ⚠️ Needs Configuration
- [ ] Rails autoloading setup (see deployment guide)
- [ ] Custom config initializer (see deployment guide)
- [ ] Environment variables configured
- [ ] SSL certificate issues resolved

### 🎯 Current Issues Found
1. **DNS Routing**: voicelinkai.com points to Chatwoot directly instead of through KrakenD gateway
2. **SSL Certificate**: Self-signed certificate on voicelinkai.com
3. **Account Duplicates**: 18 timestamp-based duplicate accounts still present
4. **Background Jobs**: Sidekiq deletion jobs may not be processing

## 🆘 Quick Troubleshooting

### Scripts Not Running
```bash
# Check permissions
ls -la custom/scripts/**/*.rb

# Make executable
chmod +x custom/scripts/**/*.rb
```

### Health Check Failures
```bash
# Check API connectivity
curl -s -H "api_access_token: YOUR_TOKEN" \
  "https://your-domain.com/platform/api/v1/accounts"

# Check SSL issues
curl -k -I https://voicelinkai.com
```

### Account Issues
```bash
# Check current account count
curl -s -H "api_access_token: YOUR_TOKEN" \
  "https://your-domain.com/platform/api/v1/accounts" | jq length

# View account details
curl -s -H "api_access_token: YOUR_TOKEN" \
  "https://your-domain.com/platform/api/v1/accounts" | jq '.[] | {id: .id, name: .name}'
```

## 📞 Support

For issues with custom code:
1. Check `custom/documentation/troubleshooting/`
2. Run health check: `ruby custom/scripts/monitoring/health_check.rb`
3. Review backup files in `custom/backup/`
4. Check logs if Rails integration is setup

---

**Next Steps:**
1. Set up Rails integration (see deployment guide)
2. Configure environment variables
3. Resolve DNS/SSL issues
4. Complete account cleanup 