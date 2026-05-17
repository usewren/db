-- Query indexes: opt-in index declarations on collection schemas.
-- Each declaration specifies a JSON path and an index kind (btree, gin, trigram).
-- The server creates/drops Postgres indexes on schema save.
-- Migration: 010_query_indexes

ALTER TABLE collection_schemas
  ADD COLUMN IF NOT EXISTS indexes JSONB DEFAULT '[]'::jsonb;

COMMENT ON COLUMN collection_schemas.indexes IS
  'Array of index declarations: [{"path":"fieldName","kind":"btree"}]. Kinds: btree, gin, trigram.';
