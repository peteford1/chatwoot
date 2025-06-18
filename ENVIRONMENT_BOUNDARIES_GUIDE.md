# 🛡️ Environment Boundaries Enforcement Guide

**Ensuring Cursor AI Always Stays Within Safe Environment Boundaries**

## 🎯 Overview

This system ensures that Cursor AI (and all developers) always respect environment boundaries and follow established CI/CD practices. It provides multiple layers of protection against dangerous operations.

## 🏗️ Multi-Layer Protection System

```
┌─────────────────────────────────────────────────────────────┐
│                    PROTECTION LAYERS                        │
├─────────────────────────────────────────────────────────────┤
│ 1. 📋 .cursorrules          - Cursor AI behavior rules     │
│ 2. 🔧 VS Code Settings      - Workspace configuration      │
│ 3. 🚫 Pre-commit Hooks      - Git commit validation        │
│ 4. 🛡️  Shell Aliases        - Command safety wrappers     │
│ 5. ✅ Environment Validator - Comprehensive validation     │
│ 6. 🔄 GitHub Actions        - CI/CD pipeline enforcement   │
└─────────────────────────────────────────────────────────────┘
```

## 📋 Layer 1: Cursor AI Rules (`.cursorrules`)

**Purpose**: Direct instructions to Cursor AI about forbidden actions and required practices.

**Key Constraints**:
- ❌ NO direct database commands for user data
- ❌ NO manual container app updates
- ❌ NO bypassing GitHub Actions workflow
- ✅ ALWAYS use API endpoints
- ✅ ALWAYS check environment status first
- ✅ ALWAYS follow branch strategy

**Usage**: Automatically loaded by Cursor AI in this workspace.

## 🔧 Layer 2: VS Code Settings (`.vscode/settings.json`)

**Purpose**: Workspace-level configuration that enforces safe practices.

**Features**:
- Environment variables for safety checks
- File associations for configuration files
- Search exclusions for sensitive files
- YAML validation for environment configs

**Key Settings**:
```json
{
  "terminal.integrated.env.osx": {
    "CHATWOOT_ENV_CHECK": "REQUIRED",
    "DEPLOYMENT_METHOD": "GITHUB_ACTIONS_ONLY",
    "FORBIDDEN_DIRECT_DB": "true"
  }
}
```

## 🚫 Layer 3: Pre-commit Hooks (`.git/hooks/pre-commit`)

**Purpose**: Prevents dangerous code from being committed to the repository.

**Checks**:
- ❌ Forbidden patterns (direct DB access, manual deployments)
- ❌ Hardcoded environment URLs
- ❌ Direct database modifications
- ✅ Required configuration files exist
- ✅ Proper branch strategy usage

**Example Output**:
```bash
🔍 Chatwoot Environment Safety Check...
📋 Current branch: feature/new-feature
🚫 Checking for forbidden patterns...
✅ Environment safety check passed!
```

## 🛡️ Layer 4: Shell Aliases (`scripts/safe_aliases.sh`)

**Purpose**: Provides safe command alternatives and blocks dangerous operations.

**Safe Commands**:
```bash
# Environment Management
cw-envs              # List environments
cw-dev-status        # Check development status
cw-logs-dev          # View development logs

# Deployment (Safe)
cw-deploy-dev        # Shows how to deploy to dev
cw-deploy-staging    # Shows how to deploy to staging
cw-deploy-prod       # Shows how to deploy to production

# Blocked Commands
az-containerapp-update  # Blocked with helpful message
az-postgres-execute     # Blocked with helpful message
```

**Command Wrappers**:
- `az()` function blocks dangerous Azure commands
- `git()` function warns about deployment triggers
- Safety reminders for `rails console` and `psql`

**Setup**:
```bash
# Add to your ~/.zshrc or ~/.bashrc
source /path/to/chatwoot/scripts/safe_aliases.sh
```

## ✅ Layer 5: Environment Validator (`scripts/validate_environment.rb`)

**Purpose**: Comprehensive validation of environment configuration and boundaries.

**Validation Areas**:
- 📋 Configuration files existence and structure
- 🌿 Git branch strategy compliance
- ☁️ Azure resources status
- 🔄 GitHub workflow configuration
- 🚫 Forbidden patterns in code
- 🔒 Environment isolation
- 🩺 Health endpoint availability

**Usage**:
```bash
ruby scripts/validate_environment.rb
```

**Example Output**:
```
🔍 Chatwoot Environment Validation
==================================================

📋 Validating Configuration Files...
✅ config/environments.yml - Found
✅ scripts/manage_environments.rb - Found
✅ .github/workflows/azure-deploy.yml - Found
✅ .cursorrules - Found

🌿 Validating Git Branch Strategy...
📋 Current branch: feature/environment-safety
✅ Feature branch - Deploys to development environment

📊 VALIDATION RESULTS
==================================================
🎉 ALL VALIDATIONS PASSED!
✅ Environment boundaries are properly configured
✅ CI/CD pipeline is ready
✅ No security violations detected
```

## 🔄 Layer 6: GitHub Actions Workflow

**Purpose**: Enforces proper deployment practices through automated CI/CD.

**Environment Mapping**:
- `main` branch → Production environment
- `develop` branch → Staging environment
- `feature/*` branches → Development environment

**Safety Features**:
- Automated testing before deployment
- Environment-specific configurations
- Database migrations only in production
- Deployment verification and rollback capabilities

## 🚀 How to Use This System

### 1. Initial Setup

```bash
# Load shell aliases (add to ~/.zshrc)
source scripts/safe_aliases.sh

# Validate environment setup
ruby scripts/validate_environment.rb

# Check current environment status
cw-envs
```

### 2. Daily Development Workflow

```bash
# Check current environment
cw-branch

# Create feature branch
cw-new-feature my-awesome-feature

# Make changes following environment rules
# (Pre-commit hook will validate on commit)

# Deploy by pushing to appropriate branch
git push origin feature/my-awesome-feature  # → Development
git push origin develop                     # → Staging  
git push origin main                        # → Production
```

### 3. Environment Management

```bash
# Check environment status
cw-dev-status
cw-staging-status
cw-prod-status

# View logs
cw-logs-dev
cw-logs-staging
cw-logs-prod

# Health checks
cw-health-dev
```

### 4. Troubleshooting

```bash
# Validate environment configuration
ruby scripts/validate_environment.rb

# Check debug files
cw-debug

# View GitHub Actions runs
cw-runs
```

## 🔒 Security Boundaries

### Database Access
- ❌ **FORBIDDEN**: Direct SQL commands to modify user data
- ❌ **FORBIDDEN**: Rails console commands that modify production data
- ✅ **ALLOWED**: API endpoint calls
- ✅ **ALLOWED**: Read-only database queries for debugging

### Deployment Access
- ❌ **FORBIDDEN**: Manual `az containerapp update` commands
- ❌ **FORBIDDEN**: Direct image deployments
- ✅ **ALLOWED**: GitHub Actions workflow deployments
- ✅ **ALLOWED**: Environment status checking

### Configuration Changes
- ❌ **FORBIDDEN**: Hardcoded environment values
- ❌ **FORBIDDEN**: Direct Azure secret modifications
- ✅ **ALLOWED**: Changes through `config/environments.yml`
- ✅ **ALLOWED**: GitHub secrets management

## 🎯 Cursor AI Specific Enforcement

### When Cursor AI Suggests Changes

1. **Environment Validation**: Always runs environment validator first
2. **Branch Awareness**: Checks current branch and target environment
3. **Safety Checks**: Validates against forbidden patterns
4. **Rollback Plans**: Provides rollback instructions for changes
5. **Impact Assessment**: Considers effects on all environments

### Automatic Safeguards

- **Pre-commit validation** prevents dangerous commits
- **Shell aliases** block dangerous commands
- **Environment validator** catches configuration issues
- **GitHub Actions** enforces proper deployment workflow

## 📊 Monitoring and Alerts

### Validation Triggers
- Every commit (pre-commit hook)
- Manual validation runs
- GitHub Actions workflow execution
- Environment status checks

### Alert Levels
- 🚨 **CRITICAL**: Blocks operation, must fix
- ⚠️ **WARNING**: Should fix, operation continues
- ✅ **SUCCESS**: All validations passed

## 🔧 Customization

### Adding New Forbidden Patterns

Edit `.git/hooks/pre-commit`:
```bash
FORBIDDEN_PATTERNS=(
    "your-new-forbidden-pattern"
    # ... existing patterns
)
```

### Adding New Environment

Edit `config/environments.yml`:
```yaml
environments:
  your_new_env:
    database_name: "chatwoot_your_env"
    container_app_name: "chatwoot-backend-your-env"
    # ... other configuration
```

### Adding New Safe Commands

Edit `scripts/safe_aliases.sh`:
```bash
alias cw-your-command='your-safe-command-here'
```

## 🆘 Emergency Procedures

### If Environment Boundaries Are Violated

1. **Stop immediately** - Don't proceed with dangerous operations
2. **Run validation**: `ruby scripts/validate_environment.rb`
3. **Check current state**: `cw-envs` and `cw-dev-status`
4. **Review recent changes**: `git log --oneline -10`
5. **Create debug file**: `cw-debug-new`
6. **Follow rollback procedures** in deployment guide

### If CI/CD Pipeline Fails

1. **Check GitHub Actions**: `cw-runs`
2. **View detailed logs**: `gh run view [RUN_ID]`
3. **Validate environment**: `ruby scripts/validate_environment.rb`
4. **Check Azure resources**: `cw-apps` and `cw-db-status`
5. **Follow troubleshooting guide** in deployment documentation

---

## 🎉 Summary

This multi-layer protection system ensures that:

✅ **Cursor AI always respects environment boundaries**  
✅ **Dangerous operations are blocked at multiple levels**  
✅ **Proper CI/CD workflow is enforced**  
✅ **Environment isolation is maintained**  
✅ **Security best practices are followed**  
✅ **Easy recovery from issues**  

**Result**: A bulletproof development environment where it's nearly impossible to accidentally break production or bypass established workflows! 🛡️ 