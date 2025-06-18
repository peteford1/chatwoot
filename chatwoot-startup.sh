#!/bin/bash
set -e

echo "Starting Chatwoot container..."
echo "Database URL: $DATABASE_URL"
echo "Redis URL: $REDIS_URL"

# Prepare the database
echo "Preparing database..."
bundle exec rails db:prepare

# Start the Rails server
echo "Starting Rails server..."
exec bundle exec rails server -b 0.0.0.0 -p 3000 