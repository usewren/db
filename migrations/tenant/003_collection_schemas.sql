-- Tenant schema: JSON Schema enforcement per collection
-- Migration: 003_collection_schemas

CREATE TABLE IF NOT EXISTS collection_schemas (
  collection  TEXT        PRIMARY KEY,
  schema      JSONB       NOT NULL,
  created_by  TEXT        NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
