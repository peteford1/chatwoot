# Custom Code Organization

**Created:** 2025-06-10 08:35:00 PDT  
**Purpose:** Separate custom code from core Chatwoot to enable safe updates  
**Principle:** Keep all custom modifications in this folder to avoid conflicts during Chatwoot updates

## 📁 Folder Structure

```
custom/
├── README.md                    # This file - documentation for custom code
├── scripts/                     # Custom Ruby scripts and utilities
│   ├── account_management/      # Account-related scripts
│   ├── data_migration/          # Data migration and cleanup scripts
│   ├── integrations/            # Integration scripts (Twilio, etc.)
│   └── monitoring/              # System monitoring and health checks
├── config/                      # Custom configuration files
│   ├── environments/            # Environment-specific configs
│   ├── integrations/            # Integration configurations
│   └── overrides/               # Configuration overrides
├── lib/                         # Custom Ruby libraries and modules
│   ├── extensions/              # Rails/Chatwoot extensions
│   ├── services/                # Custom service classes
│   └── utilities/               # Utility modules and helpers
├── templates/                   # Custom templates (email, etc.)
│   ├── email/                   # Email templates
│   ├── webhooks/                # Webhook payload templates
│   └── responses/               # API response templates
├── documentation/               # Custom documentation
│   ├── setup/                   # Setup and deployment guides
│   ├── api/                     # API documentation
│   └── troubleshooting/         # Debug guides and solutions
├── backup/                      # Backup location for replaced files
│   └── [timestamp]/             # Timestamped backup folders
└── deployment/                  # Custom deployment scripts and configs
    ├── azure/                   # Azure-specific deployment files
    ├── docker/                  # Custom Docker configurations
    └── scripts/                 # Deployment automation scripts
```

## 🎯 Core Principles

### 1. **Separation of Concerns**
- Never modify core Chatwoot files directly
- All customizations go in the `custom/` folder
- Use Rails autoloading to extend functionality

### 2. **Backup First**
- Always backup original files before customization
- Store backups in `custom/backup/[timestamp]/`
- Document what was replaced and why

### 3. **Version Control**
- The `custom/` folder can be version controlled separately
- Use `.gitignore` to exclude sensitive configurations
- Track all custom changes with proper commit messages

### 4. **Documentation**
- Document every custom modification
- Include setup instructions and dependencies
- Maintain troubleshooting guides

## 🔧 Usage Patterns

### Custom Scripts
```ruby
# custom/scripts/account_management/cleanup_duplicates.rb
# This script safely removes duplicate accounts
# Place all account management scripts here
```

### Configuration Overrides
```yaml
# custom/config/integrations/twilio.yml
# Custom Twilio configuration that extends the base config
# This won't be overwritten during Chatwoot updates
```

### Service Extensions
```ruby
# custom/lib/services/enhanced_account_service.rb
# Custom service that extends AccountService functionality
# Autoloaded by Rails without modifying core files

# custom/services/sync_accounts_service.rb
# SyncAccounts web service for external system integration
# Provides REST API for user synchronization
```

## 🚀 Rails Integration

### Autoloading Custom Code
Add to `config/application.rb` (one-time setup):
```ruby
# Add custom lib directory to autoload paths
config.autoload_paths += %W(#{config.root}/custom/lib)
config.eager_load_paths += %W(#{config.root}/custom/lib)
```

### Loading Custom Configurations
```ruby
# In config/initializers/custom_configs.rb
Dir[Rails.root.join('custom/config/**/*.yml')].each do |config_file|
  # Load custom configurations
end
```

## 📋 Migration Checklist

When updating Chatwoot:

- [ ] 1. **Backup current state**
- [ ] 2. **Document current customizations**  
- [ ] 3. **Update Chatwoot core**
- [ ] 4. **Test custom code compatibility**
- [ ] 5. **Update custom configurations if needed**
- [ ] 6. **Run custom tests**
- [ ] 7. **Deploy and verify**

## 🛡️ Safety Features

### Backup System
- Automatic timestamped backups
- Never overwrite existing backups
- Include metadata about what was backed up

### Testing
- Custom scripts include dry-run modes
- Verification steps before making changes
- Rollback procedures documented

### Monitoring
- Health checks for custom integrations  
- Log custom operations separately
- Alert on custom code failures

## 📖 Examples

See the following for practical examples:
- `custom/scripts/account_management/` - Account cleanup examples
- `custom/documentation/setup/` - Deployment guides
- `custom/templates/` - Template examples

## 🆘 Support

For issues with custom code:
1. Check `custom/documentation/troubleshooting/`
2. Review backup files in `custom/backup/`
3. Consult individual script documentation
4. Check Rails logs for autoloading issues

---

**Remember:** This folder structure keeps your customizations safe during Chatwoot updates! 