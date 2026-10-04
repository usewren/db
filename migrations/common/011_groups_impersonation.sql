-- Groups, per-org permission uniqueness, and org-scoped impersonation
-- Migration: 011_groups_impersonation

-- ── Permission rules are unique PER ORG ────────────────────────────────────────
-- Before: UNIQUE (principal, resource) across all orgs, and rule creation upserted
-- on it, so org B creating '*' on 'tree:site' updated org A's rule for its own
-- tree 'site' instead of creating B's.
ALTER TABLE common.permissions DROP CONSTRAINT IF EXISTS permissions_principal_resource_key;
CREATE UNIQUE INDEX IF NOT EXISTS permissions_org_principal_resource
  ON common.permissions (org_id, principal, resource);

-- ── Groups ────────────────────────────────────────────────────────────────────
-- Permission rules can name a group as principal: 'group:<groupId>'.
CREATE TABLE IF NOT EXISTS common.groups (
  id          TEXT        PRIMARY KEY DEFAULT gen_random_uuid()::text,
  org_id      TEXT        NOT NULL,
  name        TEXT        NOT NULL,
  description TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (org_id, name)
);
CREATE INDEX IF NOT EXISTS groups_org_id ON common.groups (org_id);

CREATE TABLE IF NOT EXISTS common.group_members (
  group_id TEXT        NOT NULL REFERENCES common.groups(id) ON DELETE CASCADE,
  user_id  TEXT        NOT NULL,
  added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (group_id, user_id)
);
CREATE INDEX IF NOT EXISTS group_members_user_id ON common.group_members (user_id);

-- Invites carry the groups the invitee joins on acceptance
ALTER TABLE common.invites ADD COLUMN IF NOT EXISTS group_ids TEXT[] NOT NULL DEFAULT '{}';

-- ── Impersonation ─────────────────────────────────────────────────────────────
-- An org admin's browser session acts as one member of that org until it expires
-- or is ended. Bound to the admin's session, the org and the target user.
CREATE TABLE IF NOT EXISTS common.impersonations (
  id             TEXT        PRIMARY KEY DEFAULT gen_random_uuid()::text,
  session_id     TEXT        NOT NULL,
  org_id         TEXT        NOT NULL,
  admin_user_id  TEXT        NOT NULL,
  target_user_id TEXT        NOT NULL,
  started_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at     TIMESTAMPTZ NOT NULL,
  ended_at       TIMESTAMPTZ
);
-- At most one active impersonation per admin session
CREATE UNIQUE INDEX IF NOT EXISTS impersonations_active_session
  ON common.impersonations (session_id) WHERE ended_at IS NULL;
CREATE INDEX IF NOT EXISTS impersonations_org ON common.impersonations (org_id, started_at DESC);

INSERT INTO common.schema_versions (version, description)
VALUES (11, 'Groups, per-org permission uniqueness, impersonation')
ON CONFLICT (version) DO NOTHING;
