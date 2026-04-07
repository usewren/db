CREATE TABLE IF NOT EXISTS common.request_stats (
  org_id  TEXT   NOT NULL,
  date    DATE   NOT NULL DEFAULT CURRENT_DATE,
  reads   BIGINT NOT NULL DEFAULT 0,
  writes  BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (org_id, date)
);
