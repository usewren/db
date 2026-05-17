-- Materialized queries: named, persisted query results that auto-refresh on write.
-- The result is stored as a versioned document so it participates in labels/promote.
-- Migration: 011_materialized_queries

CREATE TABLE IF NOT EXISTS materialized_queries (
  id              TEXT        PRIMARY KEY DEFAULT gen_random_uuid()::text,
  collection      TEXT        NOT NULL,
  name            TEXT        NOT NULL,
  query           JSONB       NOT NULL,
  refresh_on      TEXT        NOT NULL DEFAULT 'write',
  result_doc_id   TEXT,
  created_by      TEXT        NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (collection, name)
);

CREATE INDEX IF NOT EXISTS mq_collection_idx ON materialized_queries (collection);
