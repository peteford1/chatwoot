#!/bin/bash

# GitHub Secrets Setup Script for Chatwoot Azure Deployment
# Updated: $(date) - Created automated GitHub secrets configuration

set -e

echo "🔧 Setting up GitHub Secrets for Chatwoot Azure Deployment"
echo "=========================================================="

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed. Please install it first:"
    echo "   brew install gh"
    exit 1
fi

# Check if user is logged in to GitHub
if ! gh auth status &> /dev/null; then
    echo "🔐 Please login to GitHub CLI first:"
    gh auth login
fi

# Get current repository
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
echo "📁 Repository: $REPO"

echo ""
echo "🔑 Setting up GitHub Secrets..."
echo "================================"

# Azure Credentials
echo "1. Azure Service Principal Credentials"
echo "   You need to create a service principal with Contributor access to your resource group."
echo "   Run: az ad sp create-for-rbac --name 'chatwoot-github-actions' --role contributor --scopes /subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/SM-Test --sdk-auth"
echo ""
read -p "Enter the JSON output from the above command: " AZURE_CREDENTIALS
gh secret set AZURE_CREDENTIALS --body "$AZURE_CREDENTIALS"

# Container Registry Credentials
echo ""
echo "2. Azure Container Registry Credentials"
az acr credential show --name chatwootregistry95290 --query "username" -o tsv > /tmp/acr_username
az acr credential show --name chatwootregistry95290 --query "passwords[0].value" -o tsv > /tmp/acr_password

ACR_USERNAME=$(cat /tmp/acr_username)
ACR_PASSWORD=$(cat /tmp/acr_password)

gh secret set AZURE_REGISTRY_USERNAME --body "$ACR_USERNAME"
gh secret set AZURE_REGISTRY_PASSWORD --body "$ACR_PASSWORD"

rm /tmp/acr_username /tmp/acr_password

echo "✅ Container Registry credentials set"

# Database Credentials
echo ""
echo "3. Database Credentials"
read -p "Enter PostgreSQL username: " DB_USERNAME
read -s -p "Enter PostgreSQL password: " DB_PASSWORD
echo ""
DB_HOST="chatwoot-db-fresh.postgres.database.azure.com"

gh secret set DB_USERNAME --body "$DB_USERNAME"
gh secret set DB_PASSWORD --body "$DB_PASSWORD"
gh secret set DB_HOST --body "$DB_HOST"

echo "✅ Database credentials set"

# Application Secrets
echo ""
echo "4. Application Secrets"
read -p "Enter SECRET_KEY_BASE (or press Enter to generate): " SECRET_KEY_BASE
if [ -z "$SECRET_KEY_BASE" ]; then
    SECRET_KEY_BASE=$(openssl rand -hex 64)
    echo "Generated SECRET_KEY_BASE: $SECRET_KEY_BASE"
fi

read -p "Enter FRONTEND_URL: " FRONTEND_URL
read -p "Enter REDIS_URL: " REDIS_URL
read -p "Force SSL? (true/false): " FORCE_SSL

gh secret set SECRET_KEY_BASE --body "$SECRET_KEY_BASE"
gh secret set FRONTEND_URL --body "$FRONTEND_URL"
gh secret set REDIS_URL --body "$REDIS_URL"
gh secret set FORCE_SSL --body "$FORCE_SSL"

echo "✅ Application secrets set"

echo ""
echo "🎉 GitHub Secrets Setup Complete!"
echo "=================================="
echo ""
echo "📋 Summary of secrets created:"
echo "   - AZURE_CREDENTIALS"
echo "   - AZURE_REGISTRY_USERNAME"
echo "   - AZURE_REGISTRY_PASSWORD"
echo "   - DB_USERNAME"
echo "   - DB_PASSWORD"
echo "   - DB_HOST"
echo "   - SECRET_KEY_BASE"
echo "   - FRONTEND_URL"
echo "   - REDIS_URL"
echo "   - FORCE_SSL"
echo ""
echo "🚀 You can now push to your repository to trigger deployments!"
echo ""
echo "📚 Branch Strategy:"
echo "   - Push to 'main' → Production deployment"
echo "   - Push to 'develop' → Staging deployment"
echo "   - Push to 'feature/*' → Development deployment" 