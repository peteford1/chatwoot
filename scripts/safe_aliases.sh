#!/bin/bash

# Safe Aliases for Chatwoot Environment Management
# Updated: $(date) - Enforce environment boundaries through shell aliases
# Source this file in your ~/.zshrc or ~/.bashrc: source /path/to/chatwoot/scripts/safe_aliases.sh

echo "🛡️  Loading Chatwoot Environment Safety Aliases..."

# Environment Management Aliases (Schema-based)
alias cw-envs='ruby scripts/manage_environments_schema.rb --list'
alias cw-status='ruby scripts/manage_environments_schema.rb --status'
alias cw-dev-status='ruby scripts/manage_environments_schema.rb --status development'
alias cw-staging-status='ruby scripts/manage_environments_schema.rb --status staging'
alias cw-prod-status='ruby scripts/manage_environments_schema.rb --status production'
alias cw-setup-db='ruby scripts/setup_shared_database.rb'

# Safe Deployment Aliases
alias cw-deploy='echo "❌ Use GitHub Actions for deployment! Push to appropriate branch instead."'
alias cw-deploy-dev='echo "✅ Push to feature/* branch to deploy to development"'
alias cw-deploy-staging='echo "✅ Push to develop branch to deploy to staging"'
alias cw-deploy-prod='echo "✅ Push to main branch to deploy to production"'

# Forbidden Command Overrides
alias az-containerapp-update='echo "🚫 FORBIDDEN: Use GitHub Actions workflow instead of direct container updates!"'
alias az-postgres-execute='echo "🚫 FORBIDDEN: Use API endpoints instead of direct database access!"'

# Safe Azure Commands (read-only)
alias cw-logs-dev='az containerapp logs show --name chatwoot-backend-test --resource-group SM-Test --follow'
alias cw-logs-staging='az containerapp logs show --name chatwoot-backend-staging --resource-group SM-Test --follow'
alias cw-logs-prod='az containerapp logs show --name chatwoot-backend-prod --resource-group SM-Test --follow'

# Database Status (read-only)
alias cw-db-status='az postgres flexible-server list --query "[].{Name:name, State:state}" -o table'
alias cw-db-show='az postgres flexible-server show --name chatwoot-db-fresh --resource-group SM-Test'

# Container App Status (read-only)
alias cw-apps='az containerapp list --query "[].{Name:name, Status:properties.runningStatus}" -o table'
alias cw-app-dev='az containerapp show --name chatwoot-backend-test --resource-group SM-Test'
alias cw-app-staging='az containerapp show --name chatwoot-backend-staging --resource-group SM-Test'
alias cw-app-prod='az containerapp show --name chatwoot-backend-prod --resource-group SM-Test'

# GitHub Actions Aliases
alias cw-runs='gh run list --limit 10'
alias cw-run-watch='gh run watch'
alias cw-workflow='gh workflow list'

# Branch Management
alias cw-branch='git branch --show-current && echo "Environment mapping:" && echo "  feature/* → development" && echo "  develop → staging" && echo "  main → production"'
alias cw-new-feature='git checkout -b feature/'
alias cw-to-staging='git checkout develop'
alias cw-to-prod='git checkout main'

# Environment Variable Generation (Schema-based)
alias cw-env-dev='ruby scripts/manage_environments_schema.rb --env-vars development'
alias cw-env-staging='ruby scripts/manage_environments_schema.rb --env-vars staging'
alias cw-env-prod='ruby scripts/manage_environments_schema.rb --env-vars production'

# Health Checks
alias cw-health-dev='curl -s https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/health'
alias cw-health-staging='echo "Staging URL not configured yet"'
alias cw-health-prod='echo "Production URL not configured yet"'

# Debug Helpers
alias cw-debug='ls -la debug/ && echo "Use existing debug files to troubleshoot similar issues"'
alias cw-debug-new='echo "Creating debug file..." && touch debug/$(date +%s)_issue.md'

# Configuration Helpers
alias cw-config='cat config/environments.yml'
alias cw-secrets='echo "GitHub Secrets configured. Use: gh secret list"'

# Safety Reminders
alias rails-console='echo "⚠️  REMINDER: Never modify user data directly in production!" && command rails console'
alias psql='echo "⚠️  REMINDER: Use API endpoints instead of direct database access!" && command psql'

# Override dangerous commands with safety checks
function az() {
    if [[ "$*" == *"containerapp update"* ]] && [[ "$*" == *"--image"* ]]; then
        echo "🚫 BLOCKED: Direct container app image updates are forbidden!"
        echo "✅ Use GitHub Actions workflow instead:"
        echo "   1. Push to appropriate branch (feature/*, develop, main)"
        echo "   2. Monitor deployment: gh run watch"
        return 1
    elif [[ "$*" == *"postgres flexible-server execute"* ]]; then
        echo "🚫 BLOCKED: Direct database execution is forbidden!"
        echo "✅ Use API endpoints or Rails console instead"
        return 1
    else
        command az "$@"
    fi
}

# Git safety wrapper
function git() {
    if [[ "$1" == "push" ]] && [[ "$*" != *"--dry-run"* ]]; then
        local current_branch=$(command git branch --show-current)
        echo "🚀 Pushing to branch: $current_branch"
        case $current_branch in
            main)
                echo "🔴 PRODUCTION deployment will be triggered!"
                read -p "Are you sure? (y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    echo "Push cancelled."
                    return 1
                fi
                ;;
            develop)
                echo "🟡 STAGING deployment will be triggered!"
                ;;
            feature/*)
                echo "🟢 DEVELOPMENT deployment will be triggered!"
                ;;
            *)
                echo "⚠️  Non-standard branch. Deployment target unclear."
                ;;
        esac
    fi
    command git "$@"
}

# Help function
function cw-help() {
    echo "🔧 Chatwoot Environment Management Commands:"
    echo ""
    echo "📊 Status & Monitoring:"
    echo "  cw-envs              - List all environments"
    echo "  cw-dev-status        - Check development environment"
    echo "  cw-staging-status    - Check staging environment"  
    echo "  cw-prod-status       - Check production environment"
    echo "  cw-logs-dev          - View development logs"
    echo "  cw-apps              - List all container apps"
    echo "  cw-db-status         - Check database status"
    echo ""
    echo "🚀 Deployment:"
    echo "  cw-deploy-dev        - How to deploy to development"
    echo "  cw-deploy-staging    - How to deploy to staging"
    echo "  cw-deploy-prod       - How to deploy to production"
    echo "  cw-runs              - View GitHub Actions runs"
    echo ""
    echo "🌿 Branch Management:"
    echo "  cw-branch            - Show current branch and environment mapping"
    echo "  cw-new-feature       - Create new feature branch"
    echo "  cw-to-staging        - Switch to staging branch"
    echo "  cw-to-prod           - Switch to production branch"
    echo ""
    echo "🔧 Configuration:"
    echo "  cw-env-dev           - Generate development environment variables"
    echo "  cw-config            - View environment configuration"
    echo "  cw-secrets           - View GitHub secrets status"
    echo ""
    echo "🩺 Health Checks:"
    echo "  cw-health-dev        - Check development health"
    echo "  cw-debug             - List debug files"
    echo ""
}

echo "✅ Chatwoot environment safety aliases loaded!"
echo "💡 Type 'cw-help' for available commands" 