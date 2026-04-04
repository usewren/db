-- Common schema: version tracking and shared utilities
-- Migration: 001_initial

CREATE SCHEMA IF NOT EXISTS common;

-- Tracks the version history of the common schema itself
CREATE TABLE IF NOT EXISTS common.schema_versions (
  version     INTEGER     PRIMARY KEY,
  description TEXT        NOT NULL,
  applied_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tracks which common schema version each tenant is currently on
CREATE TABLE IF NOT EXISTS common.tenant_versions (
  org_id          TEXT        PRIMARY KEY,
  common_version  INTEGER     NOT NULL REFERENCES common.schema_versions(version),
  schema_name     TEXT        NOT NULL,
  migrated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  migrated_by     TEXT
);

-- Tracks the version history of each tenant's own schema
CREATE TABLE IF NOT EXISTS common.tenant_migration_log (
  id              TEXT        PRIMARY KEY DEFAULT gen_random_uuid()::text,
  org_id          TEXT        NOT NULL,
  tenant_version  INTEGER     NOT NULL,
  description     TEXT        NOT NULL,
  applied_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  applied_by      TEXT,
  UNIQUE (org_id, tenant_version)
);

-- -------------------------------------------------------
-- Shared utility functions
-- -------------------------------------------------------

-- Sanitise an org_id into a valid Postgres schema name
CREATE OR REPLACE FUNCTION common.tenant_schema_name(org_id TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT 'tenant_' || regexp_replace(lower(org_id), '[^a-z0-9]', '_', 'g');
$$;

-- Return the current version of the common schema
CREATE OR REPLACE FUNCTION common.current_version()
RETURNS INTEGER
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(MAX(version), 0) FROM common.schema_versions;
$$;

-- Record this migration as applied
INSERT INTO common.schema_versions (version, description)
VALUES (1, 'Initial common schema: version tracking and utility functions')
ON CONFLICT (version) DO NOTHING;
