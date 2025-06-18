DO $$
DECLARE
    v_admin_user_id INTEGER := 1;
    v_account_id INTEGER := 1;
    v_api_token_value TEXT;
    v_platform_token_value TEXT;
    v_platform_app_id INTEGER;
BEGIN
    -- Generate new random tokens
    v_api_token_value := encode(gen_random_bytes(32), 'hex');
    v_platform_token_value := encode(gen_random_bytes(32), 'hex');
    
    -- Delete existing access tokens for this user
    DELETE FROM access_tokens WHERE owner_type = 'User' AND owner_id = v_admin_user_id;
    
    -- Create new API access token
    INSERT INTO access_tokens (owner_type, owner_id, token, created_at, updated_at)
    VALUES ('User', v_admin_user_id, v_api_token_value, NOW(), NOW());
    
    -- Delete existing platform apps and tokens
    DELETE FROM platform_apps WHERE name = 'VoiceLink Platform App';
    
    -- Create new platform app
    INSERT INTO platform_apps (name, created_at, updated_at)
    VALUES ('VoiceLink Platform App', NOW(), NOW())
    RETURNING id INTO v_platform_app_id;
    
    -- Link platform app to account
    INSERT INTO platform_app_permissibles (platform_app_id, permissible_type, permissible_id, created_at, updated_at)
    VALUES (v_platform_app_id, 'Account', v_account_id, NOW(), NOW());
    
    -- Create platform token
    INSERT INTO access_tokens (owner_type, owner_id, token, created_at, updated_at)
    VALUES ('PlatformApp', v_platform_app_id, v_platform_token_value, NOW(), NOW());
    
    -- Output the tokens
    RAISE NOTICE 'API Token: %', v_api_token_value;
    RAISE NOTICE 'Platform Token: %', v_platform_token_value;
    RAISE NOTICE 'User ID: %', v_admin_user_id;
    RAISE NOTICE 'Account ID: %', v_account_id;
    RAISE NOTICE 'Platform App ID: %', v_platform_app_id;
END $$; 