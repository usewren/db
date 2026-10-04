-- Landing-page experiment counts
-- Migration: 013_landing_stats
--
-- Aggregated per day, variant and event (visitor, view, admin, signup).
-- No IPs, no user ids: the visitor's variant lives only in their wren_v cookie.

CREATE TABLE IF NOT EXISTS common.landing_stats (
  date    DATE    NOT NULL DEFAULT CURRENT_DATE,
  variant TEXT    NOT NULL,
  event   TEXT    NOT NULL,
  count   BIGINT  NOT NULL DEFAULT 0,
  PRIMARY KEY (date, variant, event)
);

INSERT INTO common.schema_versions (version, description)
VALUES (13, 'Landing-page experiment counts')
ON CONFLICT (version) DO NOTHING;
