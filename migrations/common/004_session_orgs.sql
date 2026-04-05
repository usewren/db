-- Per-session active org selection
-- Migration: 004_session_orgs

CREATE TABLE IF NOT EXISTS common.session_orgs (
  session_id TEXT        PRIMARY KEY,
  org_id     TEXT        NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO common.schema_versions (version, description)
VALUES (4, 'Per-session active org for multi-org users')
ON CONFLICT (version) DO NOTHING;
