#!/bin/bash
set -e

echo "🚀 Starting Chatwoot with Redis integration..."

# Function to wait for service
wait_for_service() {
    local host=$1
    local port=$2
    local service_name=$3
    local max_attempts=30
    local attempt=1

    echo "⏳ Waiting for $service_name at $host:$port..."
    
    while [ $attempt -le $max_attempts ]; do
        if nc -z "$host" "$port" 2>/dev/null; then
            echo "✅ $service_name is ready!"
            return 0
        fi
        
        echo "Attempt $attempt/$max_attempts: $service_name not ready, waiting..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo "❌ Failed to connect to $service_name after $max_attempts attempts"
    return 1
}

# Parse DATABASE_URL to get host and port
if [ -n "$DATABASE_URL" ]; then
    DB_HOST=$(echo "$DATABASE_URL" | sed -n 's/.*@\([^:]*\):.*/\1/p')
    DB_PORT=$(echo "$DATABASE_URL" | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')
    
    if [ -n "$DB_HOST" ] && [ -n "$DB_PORT" ]; then
        wait_for_service "$DB_HOST" "$DB_PORT" "PostgreSQL Database"
    else
        echo "⚠️  Could not parse DATABASE_URL, skipping database check"
    fi
else
    echo "⚠️  DATABASE_URL not set, skipping database check"
fi

# Parse REDIS_URL to get host and port
if [ -n "$REDIS_URL" ]; then
    REDIS_HOST=$(echo "$REDIS_URL" | sed -n 's/redis:\/\/\([^:]*\):.*/\1/p')
    REDIS_PORT=$(echo "$REDIS_URL" | sed -n 's/redis:\/\/[^:]*:\([0-9]*\).*/\1/p')
    
    # Default values if parsing fails
    REDIS_HOST=${REDIS_HOST:-localhost}
    REDIS_PORT=${REDIS_PORT:-6379}
    
    wait_for_service "$REDIS_HOST" "$REDIS_PORT" "Redis Cache"
    
    # Test Redis connection
    echo "🔍 Testing Redis connection..."
    if redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping | grep -q "PONG"; then
        echo "✅ Redis connection successful!"
    else
        echo "❌ Redis connection failed!"
        exit 1
    fi
else
    echo "⚠️  REDIS_URL not set, skipping Redis check"
fi

# Validate required environment variables
echo "🔍 Validating environment variables..."
required_vars=("SECRET_KEY_BASE" "RAILS_ENV")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ Required environment variable $var is not set"
        exit 1
    fi
done
echo "✅ Environment variables validated"

# Set Rails environment
export RAILS_ENV=${RAILS_ENV:-production}
echo "🔧 Rails environment: $RAILS_ENV"

# Prepare database (idempotent)
echo "📦 Preparing database..."
if [ "$SKIP_DATABASE_CREATION" != "true" ]; then
    bundle exec rails db:prepare 2>/dev/null || {
        echo "⚠️  Database preparation had issues, but continuing..."
    }
else
    echo "⏭️  Skipping database preparation (SKIP_DATABASE_CREATION=true)"
fi

# Precompile assets if needed
if [ "$SKIP_ASSET_PRECOMPILE" != "true" ] && [ "$RAILS_ENV" = "production" ]; then
    echo "🎨 Precompiling assets..."
    bundle exec rails assets:precompile 2>/dev/null || {
        echo "⚠️  Asset precompilation had issues, but continuing..."
    }
else
    echo "⏭️  Skipping asset precompilation"
fi

# Start the Rails server
echo "🌟 Starting Chatwoot Rails server..."
echo "🌐 Server will be available at http://0.0.0.0:3000"
echo "🔗 Frontend URL: ${FRONTEND_URL:-http://localhost:3000}"

exec bundle exec rails server -b 0.0.0.0 -p 3000 