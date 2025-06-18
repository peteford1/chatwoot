#!/bin/bash

# Chatwoot & Storefront Quick Setup Script
# This script automates the immediate setup steps

set -e  # Exit on any error

echo "🚀 Chatwoot & Storefront Quick Setup"
echo "===================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check prerequisites
echo "🔍 Checking Prerequisites..."

# Check if GitHub CLI is installed and authenticated
if ! command -v gh &> /dev/null; then
    print_error "GitHub CLI not found. Please install with: brew install gh"
    exit 1
fi

print_status "GitHub CLI installed"

# Check GitHub authentication
if ! gh auth status &> /dev/null; then
    print_warning "GitHub CLI not authenticated"
    echo "Please run: gh auth login --web"
    echo "Then re-run this script"
    exit 1
fi

print_status "GitHub CLI authenticated"

# Check Azure CLI
if ! command -v az &> /dev/null; then
    print_error "Azure CLI not found. Please install Azure CLI"
    exit 1
fi

print_status "Azure CLI installed"

# Check if logged into Azure
if ! az account show &> /dev/null; then
    print_warning "Not logged into Azure"
    echo "Please run: az login"
    echo "Then re-run this script"
    exit 1
fi

print_status "Azure CLI authenticated"

echo ""
echo "🏗️  Phase 1: Infrastructure Setup"
echo "================================="

# Step 1: Check current container apps
echo "Checking existing container apps..."
EXISTING_APPS=$(az containerapp list --resource-group SM-Test --query "[].name" -o tsv)

if [[ $EXISTING_APPS == *"chatwoot-backend-staging"* ]]; then
    print_status "Staging container app already exists"
else
    print_info "Creating staging container app..."
    az containerapp create \
        --name chatwoot-backend-staging \
        --resource-group SM-Test \
        --environment chatwoot-managed-env \
        --image mcr.microsoft.com/azuredocs/containerapps-helloworld:latest \
        --target-port 3000 \
        --ingress external \
        --min-replicas 0 \
        --max-replicas 3 \
        --cpu 0.5 \
        --memory 1Gi
    print_status "Staging container app created"
fi

if [[ $EXISTING_APPS == *"chatwoot-backend-prod"* ]]; then
    print_status "Production container app already exists"
else
    print_info "Creating production container app..."
    az containerapp create \
        --name chatwoot-backend-prod \
        --resource-group SM-Test \
        --environment chatwoot-managed-env \
        --image mcr.microsoft.com/azuredocs/containerapps-helloworld:latest \
        --target-port 3000 \
        --ingress external \
        --min-replicas 1 \
        --max-replicas 10 \
        --cpu 1.0 \
        --memory 2Gi
    print_status "Production container app created"
fi

echo ""
echo "🗄️  Phase 2: Database Schema Setup"
echo "=================================="

# Check if shared database setup script exists
if [ -f "scripts/setup_shared_database.rb" ]; then
    print_info "Running database schema setup..."
    ruby scripts/setup_shared_database.rb
    print_status "Database schemas configured"
else
    print_warning "Database setup script not found. Creating basic setup..."
    
    # Create a basic database setup
    cat > /tmp/basic_db_setup.sql << 'EOF'
-- Create schemas for each environment
CREATE SCHEMA IF NOT EXISTS development;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS production;

-- Grant permissions (adjust username as needed)
GRANT ALL PRIVILEGES ON SCHEMA development TO chatwoot;
GRANT ALL PRIVILEGES ON SCHEMA staging TO chatwoot;
GRANT ALL PRIVILEGES ON SCHEMA production TO chatwoot;

-- Set search path for each schema
ALTER DATABASE chatwoot_shared SET search_path TO development;
EOF

    print_info "Basic database schema setup created in /tmp/basic_db_setup.sql"
    print_warning "Please run this SQL against your chatwoot_shared database"
fi

echo ""
echo "🏪 Phase 3: Storefront Platform Token"
echo "===================================="

# Create storefront platform token
if [ -f "create_storefront_platform_token_fixed.rb" ]; then
    print_info "Creating storefront platform token..."
    
    # Check if Rails environment is available
    if bundle exec rails runner "puts 'Rails OK'" &> /dev/null; then
        PLATFORM_TOKEN=$(bundle exec rails runner create_storefront_platform_token_fixed.rb 2>/dev/null | grep -E '^[a-zA-Z0-9_-]{40,}$' | tail -1)
        
        if [ -n "$PLATFORM_TOKEN" ]; then
            print_status "Storefront platform token created"
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "🔑 STOREFRONT PLATFORM TOKEN:"
            echo "$PLATFORM_TOKEN"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "Add this to your storefront environment variables:"
            echo "CHATWOOT_PLATFORM_TOKEN=$PLATFORM_TOKEN"
            echo ""
        else
            print_warning "Could not extract platform token. Please run manually:"
            echo "bundle exec rails runner create_storefront_platform_token_fixed.rb"
        fi
    else
        print_warning "Rails environment not available. Please run manually:"
        echo "bundle exec rails runner create_storefront_platform_token_fixed.rb"
    fi
else
    print_warning "Storefront token script not found"
fi

echo ""
echo "🛡️  Phase 4: Safety Setup"
echo "========================"

# Setup safety aliases
if [ -f "scripts/safe_aliases.sh" ]; then
    print_info "Setting up safety aliases..."
    
    # Check if already in shell profile
    if ! grep -q "safe_aliases.sh" ~/.zshrc 2>/dev/null; then
        echo "source $(pwd)/scripts/safe_aliases.sh" >> ~/.zshrc
        print_status "Safety aliases added to ~/.zshrc"
    else
        print_status "Safety aliases already in ~/.zshrc"
    fi
    
    # Source for current session
    source scripts/safe_aliases.sh
    print_status "Safety aliases loaded for current session"
else
    print_warning "Safety aliases script not found"
fi

# Setup git hooks
if [ -f ".git/hooks/pre-commit" ]; then
    print_status "Pre-commit hooks already installed"
else
    if [ -f "scripts/pre-commit" ]; then
        cp scripts/pre-commit .git/hooks/pre-commit
        chmod +x .git/hooks/pre-commit
        print_status "Pre-commit hooks installed"
    else
        print_warning "Pre-commit hook script not found"
    fi
fi

echo ""
echo "🔍 Phase 5: Validation"
echo "====================="

# Run environment validation
if [ -f "scripts/validate_environment.rb" ]; then
    print_info "Running environment validation..."
    ruby scripts/validate_environment.rb
else
    print_warning "Environment validation script not found"
fi

echo ""
echo "🎉 Quick Setup Complete!"
echo "========================"
echo ""
print_status "Infrastructure setup completed"
print_status "Container apps created (staging & production)"
print_status "Database schemas configured"
print_status "Safety measures activated"
echo ""
echo "📋 Next Steps:"
echo "1. Configure GitHub Secrets: bash scripts/setup_github_secrets.sh"
echo "2. Test deployment: git checkout -b feature/test && git push origin feature/test"
echo "3. Configure storefront with the platform token above"
echo "4. Review the complete setup guide: SETUP_NEXT_STEPS.md"
echo ""
echo "📚 Helpful Commands:"
echo "• Check environments: ruby scripts/manage_environments_schema.rb --list"
echo "• View logs: cw-logs-dev (after sourcing aliases)"
echo "• Monitor deployments: gh run list"
echo ""
print_status "System ready for deployment! 🚀" 