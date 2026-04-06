-- Access control: permissions and audit log
-- Migration: 005_permissions

-- Per-principal, per-resource permission rules
CREATE TABLE IF NOT EXISTS common.permissions (
  id           TEXT        PRIMARY KEY DEFAULT gen_random_uuid()::text,
  org_id       TEXT        NOT NULL,
  principal    TEXT        NOT NULL,  -- 'member:<userId>' | 'key:<keyId>'
  resource     TEXT        NOT NULL,  -- '*' | 'collection:x' | 'tree:x' | 'collection:*' | 'tree:*'
  access       TEXT        NOT NULL DEFAULT 'read'
                           CHECK (access IN ('none', 'read', 'write', 'admin')),
  label_filter TEXT,                  -- if set, reads are silently scoped to this label
  filter_lang  TEXT        CHECK (filter_lang IN ('jq', 'jmespath', 'jsonata')),
  filter_expr  TEXT,                  -- expression in filter_lang applied to document data
  audit_reads  BOOLEAN     NOT NULL DEFAULT FALSE,
  audit_writes BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (principal, resource)
);

CREATE INDEX IF NOT EXISTS permissions_principal ON common.permissions (principal);
CREATE INDEX IF NOT EXISTS permissions_org       ON common.permissions (org_id);

-- Audit log — schema defined now, populated when audit_reads/audit_writes is set
CREATE TABLE IF NOT EXISTS common.access_log (
  id        BIGSERIAL   PRIMARY KEY,
  org_id    TEXT        NOT NULL,
  principal TEXT        NOT NULL,
  resource  TEXT        NOT NULL,  -- resolved resource, e.g. 'collection:golf-magazine'
  method    TEXT        NOT NULL,  -- GET | POST | PUT | DELETE
  path      TEXT        NOT NULL,
  status    INTEGER     NOT NULL,
  ts        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS access_log_principal ON common.access_log (principal, ts DESC);
CREATE INDEX IF NOT EXISTS access_log_org       ON common.access_log (org_id, ts DESC);

-- Optional expiry on API keys
ALTER TABLE common.api_keys
  ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;

INSERT INTO common.schema_versions (version, description)
VALUES (5, 'Permissions, audit log, and API key expiry')
ON CONFLICT (version) DO NOTHING;
