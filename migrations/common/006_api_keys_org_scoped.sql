-- Make API keys org-scoped: each key belongs to an org, not just a user.
-- Existing keys are migrated to belong to the key owner's own org (user_id = org_id).
-- Migration: 006_api_keys_org_scoped

ALTER TABLE common.api_keys
  ADD COLUMN IF NOT EXISTS org_id TEXT NOT NULL DEFAULT '';

-- Back-fill: existing keys belong to the creating user's own org
UPDATE common.api_keys SET org_id = user_id WHERE org_id = '';

-- Drop the default now that all rows are filled
ALTER TABLE common.api_keys ALTER COLUMN org_id DROP DEFAULT;

CREATE INDEX IF NOT EXISTS api_keys_org_id ON common.api_keys (org_id);

INSERT INTO common.schema_versions (version, description)
VALUES (6, 'API keys are org-scoped')
ON CONFLICT (version) DO NOTHING;
