-- Public aliases: optional short name for a collection or tree in public URLs.
-- Only meaningful on principal='*' rules — lets the public URL use a different
-- name than the internal collection/tree name.
-- Migration: 010_permission_aliases

ALTER TABLE common.permissions
  ADD COLUMN IF NOT EXISTS alias TEXT;

-- Alias must be unique per org (no two public rules in the same org can share an alias)
CREATE UNIQUE INDEX IF NOT EXISTS idx_permissions_alias
  ON common.permissions (org_id, alias)
  WHERE alias IS NOT NULL;

INSERT INTO common.schema_versions (version, description)
VALUES (10, 'Public aliases on permission rules')
ON CONFLICT (version) DO NOTHING;
