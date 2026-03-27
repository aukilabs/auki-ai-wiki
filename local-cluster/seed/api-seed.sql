-- api-seed.sql — Idempotent test data for the local posemesh cluster.
-- Designed to run after all API migrations have been applied.

-- 1. Test organization
INSERT INTO organizations (id, name)
VALUES ('a1dcf9a5-b035-42f0-9f7f-e78b38dbdb6d', 'Test Org')
ON CONFLICT DO NOTHING;

-- 2. Test user (password: testtest)
--    Hash is bcrypt(sha512("testtest")) — the API uses SHA-512 pre-hashing.
--    After migration 30 the users table has organization_id and user_role
--    directly on the row (users_in_organizations table was removed).
INSERT INTO users (id, email, password_hash, email_verified, organization_id, user_role)
VALUES (
  'b5f8c7d0-1234-4a5b-8c9d-e0f1a2b3c4d5',
  'test@test.com',
  '$2a$10$ie9PxQhFB1PahY6ywmlO3eGAgUHu9.lqrZNRpj.CP9NMZDfPAbAbW',
  true,
  'a1dcf9a5-b035-42f0-9f7f-e78b38dbdb6d',
  0  -- owner
)
ON CONFLICT DO NOTHING;

-- 3. Test app
--    After migration 31 the apps table has organization_id directly
--    (apps_in_organizations table was removed).
INSERT INTO apps (id, organization_id, name, key, secret)
VALUES (
  'c3d4e5f6-7890-4abc-def0-123456789abc',
  'a1dcf9a5-b035-42f0-9f7f-e78b38dbdb6d',
  'Test App',
  'test_app_key_local',
  'test_app_secret_local'
)
ON CONFLICT DO NOTHING;

-- 4. Test domain
--    After migration 23 the domains table has organization_id directly
--    (domains_in_organizations table was removed).
INSERT INTO domains (id, organization_id, name)
VALUES (
  'd4e5f6a7-8901-4bcd-ef01-23456789abcd',
  'a1dcf9a5-b035-42f0-9f7f-e78b38dbdb6d',
  'Test Domain'
)
ON CONFLICT DO NOTHING;
