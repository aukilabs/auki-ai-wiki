-- dds-seed.sql — Test data for the DDS database in the local posemesh cluster.
-- Runs after DDS migrations. Creates a test node, domain, and MAC address
-- so the console has something to display.

-- 1. Test node (domain server) — not a real running DS, just a DB record
--    so we can link a domain to it.
INSERT INTO nodes (id, name, secret, status, organization_id, mode, latitude, longitude)
VALUES (
  'e5f6a7b8-9012-4cde-f012-3456789abcde',
  'seed-node',
  'not-a-real-secret',
  4,  -- unregistered
  'a1dcf9a5-b035-42f0-9f7f-e78b38dbdb6d',
  'public',
  0, 0
)
ON CONFLICT DO NOTHING;

-- 2. Test domain linked to the seed node
INSERT INTO domains (id, name, organization_id, domain_server_id)
VALUES (
  'd4e5f6a7-8901-4bcd-ef01-23456789abcd',
  'Test Domain',
  'a1dcf9a5-b035-42f0-9f7f-e78b38dbdb6d',
  'e5f6a7b8-9012-4cde-f012-3456789abcde'
)
ON CONFLICT DO NOTHING;

-- 3. Test MAC address on the domain
INSERT INTO mac_addresses (id, domain_id, mac_address, name)
VALUES (
  'f6a7b8c9-0123-4def-0123-456789abcdef',
  'd4e5f6a7-8901-4bcd-ef01-23456789abcd',
  'AA:BB:CC:DD:EE:FF',
  'Test Device'
)
ON CONFLICT DO NOTHING;
