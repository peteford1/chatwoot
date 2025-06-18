#!/bin/sh
set -e

echo "🚀 Starting Chatwoot..."

# Wait for database to be ready
echo "⏳ Waiting for database connection..."
until pg_isready -h postgres -p 5432 -U chatwootuser; do
  echo "Database not ready, waiting..."
  sleep 2
done
echo "✅ Database is ready"

# Wait for Redis to be ready
echo "⏳ Waiting for Redis connection..."
until redis-cli -h redis ping; do
  echo "Redis not ready, waiting..."
  sleep 2
done
echo "✅ Redis is ready"

# Set Rails environment for local development
export RAILS_ENV=development

# Create database if it doesn't exist and run migrations
echo "📦 Setting up database..."
bundle exec rails db:create 2>/dev/null || echo "Database already exists"
bundle exec rails db:migrate 2>/dev/null || echo "Migration completed"

# Start the Rails server
echo "🌟 Starting Chatwoot Rails server..."
exec bundle exec rails server -b 0.0.0.0 -p 3000 