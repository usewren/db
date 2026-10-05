-- Version retention policies
-- Migration: 015_retention
--
-- An org default (collection = '*') and per-collection overrides. A document's
-- current version and every version a label points to are always kept; of the
-- rest, a version is removed when any rule set here says so. A row with no rule
-- set means "keep everything" (useful to exempt one collection from the default).

CREATE TABLE IF NOT EXISTS common.retention_policies (
  org_id        TEXT        NOT NULL,
  collection    TEXT        NOT NULL DEFAULT '*',
  labeled_only  BOOLEAN     NOT NULL DEFAULT FALSE,              -- keep only labeled versions
  max_versions  INTEGER     CHECK (max_versions >= 1),           -- keep the newest n
  max_age_days  INTEGER     CHECK (max_age_days >= 1),           -- remove older than n days
  after_label   TEXT,                                            -- remove older than this label's version
  updated_by    TEXT,
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (org_id, collection)
);

CREATE TABLE IF NOT EXISTS common.retention_runs (
  id               BIGSERIAL   PRIMARY KEY,
  org_id           TEXT        NOT NULL,
  collection       TEXT        NOT NULL,
  versions_removed INTEGER     NOT NULL,
  bytes_freed      BIGINT      NOT NULL,
  triggered_by     TEXT,                    -- user id, or 'schedule'
  ran_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS retention_runs_org ON common.retention_runs (org_id, ran_at DESC);

INSERT INTO common.schema_versions (version, description)
VALUES (15, 'Version retention policies')
ON CONFLICT (version) DO NOTHING;
