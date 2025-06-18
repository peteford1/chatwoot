SELECT
  u.id AS user_id,
  au.account_id,
  t.token AS api_token
FROM
  users u
JOIN
  account_users au ON u.id = au.user_id
JOIN
  access_tokens t ON u.id = t.owner_id AND t.owner_type = 'User'
WHERE
  u.email = 'admin@voicelinkai.com'; 