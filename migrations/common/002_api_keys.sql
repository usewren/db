-- API keys for server-to-server authentication
-- Migration: 002_api_keys

CREATE TABLE IF NOT EXISTS common.api_keys (
  id           TEXT        PRIMARY KEY DEFAULT gen_random_uuid()::text,
  user_id      TEXT        NOT NULL,
  name         TEXT        NOT NULL,
  key_hash     TEXT        NOT NULL UNIQUE,  -- SHA-256 of the raw key, hex-encoded
  key_prefix   TEXT        NOT NULL,         -- first 12 chars of raw key for display
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_used_at TIMESTAMPTZ,
  revoked_at   TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS api_keys_user_id  ON common.api_keys (user_id);
CREATE INDEX IF NOT EXISTS api_keys_key_hash ON common.api_keys (key_hash);

INSERT INTO common.schema_versions (version, description)
VALUES (2, 'API keys table for server-to-server authentication')
ON CONFLICT (version) DO NOTHING;
