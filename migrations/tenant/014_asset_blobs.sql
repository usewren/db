-- Store each distinct file once
-- Migration: 014_asset_blobs
--
-- File bytes move to asset_blobs, keyed by their SHA-256. asset_contents keeps one
-- row per document version (name, type, size) pointing at its blob, so history is
-- unchanged but identical bytes are stored once — re-uploads of an unchanged file,
-- or the same image uploaded as several documents.
--
-- asset_contents is rebuilt rather than altered: dropping its bytea column would not
-- give the space back until a VACUUM FULL, while dropping the old table does, and
-- this works inside the migration's transaction.

CREATE TABLE IF NOT EXISTS asset_blobs (
  sha256     TEXT        PRIMARY KEY,           -- hex, as in the version metadata
  data       BYTEA       NOT NULL,
  size       INTEGER     NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = current_schema() AND table_name = 'asset_contents' AND column_name = 'data'
  ) THEN
    CREATE TABLE asset_contents_new (
      document_id TEXT        NOT NULL REFERENCES documents(id),
      version     INTEGER     NOT NULL,
      sha256      TEXT        NOT NULL,
      mime_type   TEXT        NOT NULL,
      filename    TEXT        NOT NULL,
      size        INTEGER     NOT NULL,
      created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (document_id, version)
    );

    INSERT INTO asset_contents_new (document_id, version, sha256, mime_type, filename, size, created_at)
      SELECT document_id, version, encode(sha256(data), 'hex'), mime_type, filename, size, created_at
      FROM asset_contents;

    -- One blob per distinct hash: take the bytes from any row that has them
    INSERT INTO asset_blobs (sha256, data, size)
      SELECT DISTINCT ON (n.sha256) n.sha256, o.data, octet_length(o.data)
      FROM asset_contents_new n
      JOIN asset_contents o ON o.document_id = n.document_id AND o.version = n.version
      ORDER BY n.sha256
    ON CONFLICT (sha256) DO NOTHING;

    DROP TABLE asset_contents;
    ALTER TABLE asset_contents_new RENAME TO asset_contents;
    ALTER TABLE asset_contents RENAME CONSTRAINT asset_contents_new_pkey TO asset_contents_pkey;
    ALTER TABLE asset_contents RENAME CONSTRAINT asset_contents_new_document_id_fkey TO asset_contents_document_id_fkey;
  END IF;
END $$;

-- A blob can't be removed while a version points at it
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'asset_contents_sha256_fkey'
                   AND connamespace = current_schema()::regnamespace) THEN
    ALTER TABLE asset_contents ADD CONSTRAINT asset_contents_sha256_fkey
      FOREIGN KEY (sha256) REFERENCES asset_blobs(sha256);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS asset_contents_sha256_idx ON asset_contents (sha256);
