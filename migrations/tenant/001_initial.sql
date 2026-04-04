-- Tenant schema: core tables
-- Migration: 001_initial
-- Note: executed with search_path set to the tenant schema

-- -------------------------------------------------------
-- Documents
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS documents (
  id              TEXT        PRIMARY KEY DEFAULT gen_random_uuid()::text,
  collection      TEXT        NOT NULL,
  current_version INTEGER     NOT NULL DEFAULT 1,
  created_by      TEXT        NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at      TIMESTAMPTZ               -- soft delete
);

CREATE INDEX IF NOT EXISTS documents_collection_idx ON documents (collection);
CREATE INDEX IF NOT EXISTS documents_created_by_idx ON documents (created_by);
CREATE INDEX IF NOT EXISTS documents_deleted_at_idx ON documents (deleted_at)
  WHERE deleted_at IS NULL;

-- -------------------------------------------------------
-- Versions
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS versions (
  id          TEXT        PRIMARY KEY DEFAULT gen_random_uuid()::text,
  document_id TEXT        NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
  version     INTEGER     NOT NULL,
  data        JSONB       NOT NULL,
  created_by  TEXT        NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (document_id, version)
);

CREATE INDEX IF NOT EXISTS versions_document_id_idx ON versions (document_id);
CREATE INDEX IF NOT EXISTS versions_data_gin_idx    ON versions USING GIN (data);

-- -------------------------------------------------------
-- Labels (named pointers into version history)
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS labels (
  id          TEXT        PRIMARY KEY DEFAULT gen_random_uuid()::text,
  document_id TEXT        NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
  label       TEXT        NOT NULL,
  version     INTEGER     NOT NULL,
  created_by  TEXT        NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (document_id, label)               -- one pointer per label per document
);

CREATE INDEX IF NOT EXISTS labels_document_id_idx ON labels (document_id);
CREATE INDEX IF NOT EXISTS labels_label_idx       ON labels (label);

-- -------------------------------------------------------
-- Paths (tree access — optional, multiple per document)
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS paths (
  id          TEXT        PRIMARY KEY DEFAULT gen_random_uuid()::text,
  document_id TEXT        NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
  path        TEXT        NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (path)
);

CREATE INDEX IF NOT EXISTS paths_document_id_idx ON paths (document_id);
CREATE INDEX IF NOT EXISTS paths_path_idx        ON paths (path text_pattern_ops); -- prefix queries

-- -------------------------------------------------------
-- Refs (sub-document references for streaming composition)
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS refs (
  id                  TEXT        PRIMARY KEY DEFAULT gen_random_uuid()::text,
  parent_document_id  TEXT        NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
  ref_path            TEXT        NOT NULL,  -- JSON pointer within parent (e.g. /hero)
  child_document_id   TEXT        NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (parent_document_id, ref_path)
);

CREATE INDEX IF NOT EXISTS refs_parent_idx ON refs (parent_document_id);
CREATE INDEX IF NOT EXISTS refs_child_idx  ON refs (child_document_id); -- reverse lookup
