-- Initialize Chatwoot database for local development
-- This script runs when the PostgreSQL container starts

-- Create the development database if it doesn't exist
SELECT 'CREATE DATABASE chatwoot_development'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'chatwoot_development');

-- Create the test database for running tests
CREATE DATABASE IF NOT EXISTS chatwoot_test;

-- Grant all privileges to chatwootuser
GRANT ALL PRIVILEGES ON DATABASE chatwoot_development TO chatwootuser;
GRANT ALL PRIVILEGES ON DATABASE chatwoot_test TO chatwootuser;

-- Enable required extensions
\c chatwoot_development;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

\c chatwoot_test;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements"; 