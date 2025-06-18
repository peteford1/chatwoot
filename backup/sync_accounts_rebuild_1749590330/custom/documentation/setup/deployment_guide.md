# Custom Code Deployment Guide

**Created:** 2025-06-10 08:38:00 PDT  
**Purpose:** Guide for deploying custom code with Chatwoot  
**Environment:** Azure Container Apps

## 🚀 Initial Setup

### 1. Rails Autoloading Configuration

Add to `config/application.rb` (one-time setup):

```ruby
# Add custom lib directory to autoload paths (around line 20)
# Added: 2025-06-10 - Custom code autoloading
config.autoload_paths += %W(#{config.root}/custom/lib)
config.eager_load_paths += %W(#{config.root}/custom/lib)
```

### 2. Custom Configuration Loader

Create `config/initializers/custom_configs.rb`:

```ruby
# Custom Configuration Loader
# Created: 2025-06-10 08:38:00 PDT
# Purpose: Load custom configurations from custom/ folder

Rails.application.configure do
  # Load custom YAML configurations
  custom_config_path = Rails.root.join('custom/config')
  
  if Dir.exist?(custom_config_path)
    Dir[File.join(custom_config_path, '**', '*.yml')].each do |config_file|
      begin
        config_name = File.basename(config_file, '.yml')
        config_data = YAML.load_file(config_file)
        
        # Make configurations available as Rails.application.config.custom
        config.custom ||= ActiveSupport::OrderedOptions.new
        config.custom[config_name] = config_data[Rails.env] if config_data[Rails.env]
        
        Rails.logger.info "Loaded custom config: #{config_name}"
      rescue => e
        Rails.logger.error "Failed to load custom config #{config_file}: #{e.message}"
      end
    end
  end
end
```

## 🔧 Azure Container Apps Deployment

### 1. Docker Configuration

Update `Dockerfile` to include custom folder:

```dockerfile
# Add after line copying app files (around line 40)
# Copy custom code
COPY custom/ /app/custom/

# Ensure custom scripts are executable
RUN chmod +x /app/custom/scripts/**/*.rb
```

### 2. Environment Variables

Add to Azure Container App environment:

```bash
# Custom code configuration
CUSTOM_CODE_ENABLED=true
CUSTOM_CONFIG_PATH=/app/custom/config

# Twilio custom configuration
TWILIO_ACCOUNT_SID=your_account_sid
TWILIO_AUTH_TOKEN=your_auth_token
TWILIO_TEST_ACCOUNT_SID=test_account_sid
TWILIO_TEST_AUTH_TOKEN=test_auth_token
```

### 3. Azure CLI Deployment Commands

```bash
# Deploy with custom code
az containerapp revision copy \
  --name chatwoot-backend-test \
  --resource-group SM-Test \
  --from-revision chatwoot-backend-test--latest

# Update environment variables
az containerapp update \
  --name chatwoot-backend-test \
  --resource-group SM-Test \
  --set-env-vars CUSTOM_CODE_ENABLED=true
```

## 📂 File Organization During Updates

### Before Chatwoot Update

1. **Backup current custom folder:**
   ```bash
   tar -czf custom_backup_$(date +%Y%m%d_%H%M%S).tar.gz custom/
   ```

2. **Document current customizations:**
   ```bash
   echo "Current customizations:" > custom_inventory.txt
   find custom/ -type f -name "*.rb" -o -name "*.yml" >> custom_inventory.txt
   ```

### After Chatwoot Update

1. **Restore custom folder:**
   ```bash
   # Custom folder should be preserved, but verify
   ls -la custom/
   ```

2. **Test custom integrations:**
   ```bash
   # Run custom scripts in dry-run mode
   ruby custom/scripts/account_management/cleanup_duplicates.rb --dry-run
   ```

3. **Update configurations if needed:**
   - Check if new Chatwoot version requires config updates
   - Update `custom/config/` files accordingly

## 🛠️ Script Execution Examples

### Account Management
```bash
# Run account cleanup (dry-run first)
ruby custom/scripts/account_management/cleanup_duplicate_accounts.rb --dry-run

# Run actual cleanup
ruby custom/scripts/account_management/cleanup_duplicate_accounts_auto.rb
```

### Integration Testing
```bash
# Test Twilio integration
ruby custom/scripts/integrations/test_twilio_connection.rb

# Test webhook endpoints
curl -X POST https://voicelinkai.com/twilio/callback \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "From=+15005550006&To=+19795412927&Body=Test"
```

## 🔍 Monitoring Custom Code

### Health Check Script
Create `custom/scripts/monitoring/health_check.rb`:

```ruby
#!/usr/bin/env ruby
# Health check for custom integrations

require 'net/http'
require 'json'

# Check custom endpoints
endpoints = [
  'https://voicelinkai.com/twilio/callback',
  'https://voicelinkai.com/api/custom/health'
]

endpoints.each do |endpoint|
  begin
    uri = URI(endpoint)
    response = Net::HTTP.get_response(uri)
    puts "#{endpoint}: #{response.code}"
  rescue => e
    puts "#{endpoint}: ERROR - #{e.message}"
  end
end
```

### Log Monitoring
```bash
# Monitor custom code logs
az containerapp logs show \
  --name chatwoot-backend-test \
  --resource-group SM-Test \
  --follow \
  | grep -i "custom\|voicelink"
```

## 🚨 Troubleshooting

### Common Issues

1. **Autoloading not working:**
   - Check `config/application.rb` has custom paths
   - Restart Rails server/container
   - Verify file naming conventions (CamelCase classes)

2. **Custom configs not loading:**
   - Check `config/initializers/custom_configs.rb` exists
   - Verify YAML syntax in custom config files
   - Check Rails logs for loading errors

3. **Scripts not executable:**
   - Check file permissions: `chmod +x custom/scripts/**/*.rb`
   - Verify shebang line: `#!/usr/bin/env ruby`

### Debug Commands
```bash
# Check custom code loading
rails runner "puts Rails.application.config.custom"

# Test custom service loading
rails runner "puts CustomAccountService.new"

# Check file permissions
find custom/ -name "*.rb" -exec ls -la {} \;
```

## 📋 Deployment Checklist

- [ ] Custom folder structure created
- [ ] Rails autoloading configured
- [ ] Custom config initializer added
- [ ] Dockerfile updated
- [ ] Environment variables set
- [ ] Scripts tested in development
- [ ] Backups created
- [ ] Health checks passing
- [ ] Documentation updated

---

**Next:** See `custom/documentation/troubleshooting/` for specific issue solutions 