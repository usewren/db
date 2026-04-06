CREATE TABLE IF NOT EXISTS common.org_slugs (
  org_id     TEXT        PRIMARY KEY,
  slug       TEXT        UNIQUE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS org_slugs_slug ON common.org_slugs (slug);
