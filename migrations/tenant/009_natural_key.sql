-- Natural keys: each collection can designate one field (e.g. "slug") whose
-- value becomes the document's stable addressable identity. The column here
-- is auto-populated by the server on every PUT/POST by reading the schema's
-- naturalKey field and extracting data[naturalKey] from the incoming doc.

ALTER TABLE documents
  ADD COLUMN IF NOT EXISTS natural_key TEXT;

-- Unique per (collection, key), ignoring soft-deleted rows and null keys.
-- Collections without a declared natural key can ignore the column entirely:
-- the partial index only kicks in when the column is populated.
CREATE UNIQUE INDEX IF NOT EXISTS documents_natural_key_unique_idx
  ON documents (collection, natural_key)
  WHERE natural_key IS NOT NULL AND deleted_at IS NULL;

-- A collection's designated natural-key field name, stored alongside its
-- other schema config. NULL means "no natural key" and the /by-key/ routes
-- will 400 when called against this collection.
ALTER TABLE collection_schemas
  ADD COLUMN IF NOT EXISTS natural_key TEXT;
