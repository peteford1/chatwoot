#!/usr/bin/env ruby

puts "🔑 GENERATING FRESH TOKENS USING AZURE CLI"
puts "=" * 60

# Database connection details
db_host = "chatwoot-db-fresh.postgres.database.azure.com"
db_name = "chatwoot_production"
db_user = "chatwootuser"

puts "🔗 Connecting to Azure PostgreSQL using Azure CLI..."
puts "   Host: #{db_host}"
puts "   Database: #{db_name}"
puts "   User: #{db_user}"

# SQL script to generate tokens
sql_script = <<~SQL
  -- Find or create admin user
  DO $$
  DECLARE
      v_admin_user_id INTEGER;
      v_account_id INTEGER;
      v_account_user_id INTEGER;
      v_api_token_value TEXT;
      v_platform_app_id INTEGER;
      v_platform_token_value TEXT;
  BEGIN
      -- Generate random tokens
      v_api_token_value := encode(gen_random_bytes(32), 'hex');
      v_platform_token_value := encode(gen_random_bytes(32), 'hex');
      
      -- Find or create admin user
      SELECT id INTO v_admin_user_id FROM users WHERE email = 'admin@voicelinkai.com';
      
      IF v_admin_user_id IS NULL THEN
          INSERT INTO users (
              name, 
              email, 
              encrypted_password, 
              confirmed_at, 
              created_at, 
              updated_at,
              uid,
              provider
          ) VALUES (
              'VoiceLink Admin',
              'admin@voicelinkai.com',
              '$2a$12$dummy.encrypted.password.hash.for.testing.purposes.only',
              NOW(),
              NOW(),
              NOW(),
              'admin@voicelinkai.com',
              'email'
          ) RETURNING id INTO v_admin_user_id;
          
          RAISE NOTICE 'Created admin user with ID: %', v_admin_user_id;
      ELSE
          RAISE NOTICE 'Found existing admin user with ID: %', v_admin_user_id;
          
          -- Ensure user is confirmed
          UPDATE users SET confirmed_at = NOW() WHERE id = v_admin_user_id AND confirmed_at IS NULL;
      END IF;
      
      -- Find or create account
      SELECT id INTO v_account_id FROM accounts ORDER BY id LIMIT 1;
      
      IF v_account_id IS NULL THEN
          INSERT INTO accounts (
              name,
              status,
              created_at,
              updated_at
          ) VALUES (
              'VoiceLink Account',
              0, -- active status
              NOW(),
              NOW()
          ) RETURNING id INTO v_account_id;
          
          RAISE NOTICE 'Created account with ID: %', v_account_id;
      ELSE
          RAISE NOTICE 'Found existing account with ID: %', v_account_id;
      END IF;
      
      -- Find or create account_user relationship
      SELECT au.id INTO v_account_user_id FROM account_users au
      WHERE au.user_id = v_admin_user_id AND au.account_id = v_account_id;
      
      IF v_account_user_id IS NULL THEN
          INSERT INTO account_users (
              user_id,
              account_id,
              role,
              created_at,
              updated_at
          ) VALUES (
              v_admin_user_id,
              v_account_id,
              1, -- administrator role
              NOW(),
              NOW()
          ) RETURNING id INTO v_account_user_id;
          
          RAISE NOTICE 'Created account_user relationship with ID: %', v_account_user_id;
      ELSE
          -- Ensure user is administrator
          UPDATE account_users SET role = 1 WHERE id = v_account_user_id;
          RAISE NOTICE 'Updated account_user to administrator role: %', v_account_user_id;
      END IF;
      
      -- Delete existing access tokens for this user
      DELETE FROM access_tokens WHERE owner_type = 'User' AND owner_id = v_admin_user_id;
      
      -- Create new API access token
      INSERT INTO access_tokens (
          owner_type,
          owner_id,
          token,
          created_at,
          updated_at
      ) VALUES (
          'User',
          v_admin_user_id,
          v_api_token_value,
          NOW(),
          NOW()
      );
      
      RAISE NOTICE 'Created API token: %', v_api_token_value;
      
      -- Delete existing platform apps
      DELETE FROM platform_apps WHERE name = 'VoiceLink Platform App';
      
      -- Create platform app
      INSERT INTO platform_apps (
          name,
          created_at,
          updated_at
      ) VALUES (
          'VoiceLink Platform App',
          NOW(),
          NOW()
      ) RETURNING id INTO v_platform_app_id;
      
      RAISE NOTICE 'Created platform app with ID: %', v_platform_app_id;
      
      -- Link platform app to account
      INSERT INTO platform_app_permissibles (
          platform_app_id,
          permissible_type,
          permissible_id,
          created_at,
          updated_at
      ) VALUES (
          v_platform_app_id,
          'Account',
          v_account_id,
          NOW(),
          NOW()
      );
      
      -- Create platform token
      INSERT INTO access_tokens (
          owner_type,
          owner_id,
          token,
          created_at,
          updated_at
      ) VALUES (
          'PlatformApp',
          v_platform_app_id,
          v_platform_token_value,
          NOW(),
          NOW()
      );
      
      RAISE NOTICE 'Created platform token: %', v_platform_token_value;
      
      -- Output summary
      RAISE NOTICE '';
      RAISE NOTICE '============================================================';
      RAISE NOTICE 'TOKEN GENERATION COMPLETE';
      RAISE NOTICE '============================================================';
      RAISE NOTICE '';
      RAISE NOTICE 'Admin User ID: %', v_admin_user_id;
      RAISE NOTICE 'Account ID: %', v_account_id;
      RAISE NOTICE 'API Token: %', v_api_token_value;
      RAISE NOTICE 'Platform Token: %', v_platform_token_value;
      RAISE NOTICE '';
      RAISE NOTICE 'Environment Variables:';
      RAISE NOTICE 'export CHATWOOT_ADMIN_USER_ID=%', v_admin_user_id;
      RAISE NOTICE 'export CHATWOOT_ADMIN_TOKEN="%"', v_api_token_value;
      RAISE NOTICE 'export CHATWOOT_PLATFORM_TOKEN="%"', v_platform_token_value;
      RAISE NOTICE 'export CHATWOOT_ACCOUNT_ID=%', v_account_id;
      RAISE NOTICE 'export CHATWOOT_USER_TOKEN="%"', v_api_token_value;
      RAISE NOTICE 'export CHATWOOT_USER_ID=%', v_admin_user_id;
      RAISE NOTICE 'export CHATWOOT_USER_EMAIL="admin@voicelinkai.com"';
      RAISE NOTICE '';
      
  END $$;
SQL

# Write SQL to temporary file
sql_file = 'temp_token_generation.sql'
File.write(sql_file, sql_script)

puts "\n🔧 Executing SQL script via Azure CLI..."
puts "   SQL file: #{sql_file}"

# Execute SQL using Azure CLI
result = system("az postgres flexible-server execute --name chatwoot-db-fresh --admin-user #{db_user} --admin-password 'VoiceLinkAI2024!' --database-name #{db_name} --file-path #{sql_file}")

if result
  puts "\n✅ SQL script executed successfully!"
  
  # Now extract the tokens from the output
  puts "\n🔍 Extracting tokens from database..."
  
  # Query to get the generated tokens
  token_query = <<~SQL
    SELECT 
        u.id as user_id,
        u.name as user_name,
        u.email as user_email,
        a.id as account_id,
        a.name as account_name,
        at_user.token as api_token,
        at_platform.token as platform_token
    FROM users u
    JOIN account_users au ON u.id = au.user_id
    JOIN accounts a ON au.account_id = a.id
    LEFT JOIN access_tokens at_user ON u.id = at_user.owner_id AND at_user.owner_type = 'User'
    LEFT JOIN platform_apps pa ON pa.name = 'VoiceLink Platform App'
    LEFT JOIN access_tokens at_platform ON pa.id = at_platform.owner_id AND at_platform.owner_type = 'PlatformApp'
    WHERE u.email = 'admin@voicelinkai.com'
    ORDER BY at_user.created_at DESC, at_platform.created_at DESC
    LIMIT 1;
SQL
  
  query_file = 'temp_token_query.sql'
  File.write(query_file, token_query)
  
  puts "   Querying generated tokens..."
  system("az postgres flexible-server execute --name chatwoot-db-fresh --admin-user #{db_user} --admin-password 'VoiceLinkAI2024!' --database-name #{db_name} --file-path #{query_file}")
  
  # Clean up temporary files
  File.delete(sql_file) if File.exist?(sql_file)
  File.delete(query_file) if File.exist?(query_file)
  
  puts "\n🎯 Token generation completed!"
  puts "\nNext steps:"
  puts "1. Copy the environment variables from the output above"
  puts "2. Set them in your shell or create a fresh_tokens.env file"
  puts "3. Test the tokens with your API"
  
else
  puts "\n❌ Failed to execute SQL script"
  File.delete(sql_file) if File.exist?(sql_file)
end 