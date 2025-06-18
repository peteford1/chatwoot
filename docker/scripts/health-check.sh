#!/bin/bash

# Health check script for Chatwoot with Redis
# Returns 0 if healthy, 1 if unhealthy

# Check if Rails server is responding
echo "🔍 Checking Rails application health..."
if ! curl -f -s http://localhost:3000/health > /dev/null 2>&1; then
    echo "❌ Rails application health check failed"
    exit 1
fi

# Check Redis connection if REDIS_URL is set
if [ -n "$REDIS_URL" ]; then
    echo "🔍 Checking Redis connectivity..."
    
    # Parse Redis connection details
    REDIS_HOST=$(echo "$REDIS_URL" | sed -n 's/redis:\/\/\([^:]*\):.*/\1/p')
    REDIS_PORT=$(echo "$REDIS_URL" | sed -n 's/redis:\/\/[^:]*:\([0-9]*\).*/\1/p')
    
    # Default values
    REDIS_HOST=${REDIS_HOST:-localhost}
    REDIS_PORT=${REDIS_PORT:-6379}
    
    # Test Redis connection
    if ! redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping | grep -q "PONG" 2>/dev/null; then
        echo "❌ Redis connectivity check failed"
        exit 1
    fi
fi

# Check database connection if DATABASE_URL is set
if [ -n "$DATABASE_URL" ]; then
    echo "🔍 Checking database connectivity..."
    
    # Simple database check using Rails
    if ! timeout 5 bundle exec rails runner "ActiveRecord::Base.connection.execute('SELECT 1')" > /dev/null 2>&1; then
        echo "❌ Database connectivity check failed"
        exit 1
    fi
fi

echo "✅ All health checks passed"
exit 0 