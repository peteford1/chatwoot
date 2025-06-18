-- Create SuperAdmin user directly in database
-- This bypasses Rails and creates the user at the database level

-- First, let's check if the user already exists
SELECT id, name, email, type FROM users WHERE email = 'admin@voicelinkai.com';

-- Insert SuperAdmin user
-- Password hash for 'SuperAdmin123!' using bcrypt
INSERT INTO users (
    name, 
    email, 
    encrypted_password, 
    type, 
    confirmed_at, 
    created_at, 
    updated_at
) VALUES (
    'Super Administrator',
    'admin@voicelinkai.com',
    '$2a$12$K8gTKVQIvgYGXy5.rIHOUeJ1vN8qF2xLmP3yH4zR6wE9sT7uV1cXm', -- SuperAdmin123!
    'SuperAdmin',
    NOW(),
    NOW(),
    NOW()
) ON CONFLICT (email) DO UPDATE SET
    name = EXCLUDED.name,
    type = EXCLUDED.type,
    confirmed_at = EXCLUDED.confirmed_at,
    updated_at = NOW();

-- Create access token for the SuperAdmin user
INSERT INTO access_tokens (
    owner_id,
    owner_type,
    token,
    created_at,
    updated_at
) 
SELECT 
    u.id,
    'User',
    encode(gen_random_bytes(32), 'hex'),
    NOW(),
    NOW()
FROM users u 
WHERE u.email = 'admin@voicelinkai.com' 
AND NOT EXISTS (
    SELECT 1 FROM access_tokens at 
    WHERE at.owner_id = u.id AND at.owner_type = 'User'
);

-- Show the created user and token
SELECT 
    u.id,
    u.name,
    u.email,
    u.type,
    u.confirmed_at,
    at.token as access_token
FROM users u
LEFT JOIN access_tokens at ON u.id = at.owner_id AND at.owner_type = 'User'
WHERE u.email = 'admin@voicelinkai.com'; 