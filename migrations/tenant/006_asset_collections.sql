-- Binary asset content stored per (document, version)
CREATE TABLE IF NOT EXISTS asset_contents (
  document_id TEXT    NOT NULL REFERENCES documents(id),
  version     INTEGER NOT NULL,
  data        BYTEA   NOT NULL,
  mime_type   TEXT    NOT NULL,
  filename    TEXT    NOT NULL,
  size        INTEGER NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (document_id, version)
);

-- Mark a collection as binary (stores files instead of JSON)
ALTER TABLE collection_schemas
  ADD COLUMN IF NOT EXISTS collection_type TEXT NOT NULL DEFAULT 'json';
