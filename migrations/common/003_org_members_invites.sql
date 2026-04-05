-- Org members and invites for collaboration
-- Migration: 003_org_members_invites

CREATE TABLE IF NOT EXISTS common.org_members (
  org_id    TEXT        NOT NULL,
  user_id   TEXT        NOT NULL,
  role      TEXT        NOT NULL DEFAULT 'member',
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (org_id, user_id)
);

CREATE INDEX IF NOT EXISTS org_members_user_id ON common.org_members (user_id);

CREATE TABLE IF NOT EXISTS common.invites (
  id           TEXT        PRIMARY KEY DEFAULT gen_random_uuid()::text,
  org_id       TEXT        NOT NULL,       -- owner's userId (their tenant schema)
  email        TEXT        NOT NULL,       -- invited email address
  token_hash   TEXT        NOT NULL UNIQUE,-- SHA-256 of raw token, hex-encoded
  token_prefix TEXT        NOT NULL,       -- first 8 chars for display
  role         TEXT        NOT NULL DEFAULT 'member',
  invited_by   TEXT        NOT NULL,       -- userId of the person who sent the invite
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at   TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '7 days'),
  accepted_at  TIMESTAMPTZ,
  revoked_at   TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS invites_org_id     ON common.invites (org_id);
CREATE INDEX IF NOT EXISTS invites_email      ON common.invites (email);
CREATE INDEX IF NOT EXISTS invites_token_hash ON common.invites (token_hash);

INSERT INTO common.schema_versions (version, description)
VALUES (3, 'Org members and invites for collaboration')
ON CONFLICT (version) DO NOTHING;
