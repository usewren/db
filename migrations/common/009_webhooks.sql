-- Webhooks: event-driven notifications with time-window batching.
-- Migration: 009_webhooks

-- Webhook configuration (max 10 per org, enforced in app layer)
CREATE TABLE IF NOT EXISTS common.webhooks (
  id              TEXT        PRIMARY KEY DEFAULT gen_random_uuid()::text,
  org_id          TEXT        NOT NULL,
  url             TEXT        NOT NULL,
  secret          TEXT        NOT NULL,          -- HMAC-SHA256 signing key
  events          TEXT[]      NOT NULL DEFAULT '{}',  -- empty = all events
  enabled         BOOLEAN     NOT NULL DEFAULT true,
  consec_failures INT         NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_webhooks_org ON common.webhooks (org_id);

-- Persistent event queue (7-day retention, purged by delivery worker)
CREATE TABLE IF NOT EXISTS common.webhook_events (
  id          BIGSERIAL   PRIMARY KEY,
  org_id      TEXT        NOT NULL,
  event_type  TEXT        NOT NULL,
  payload     JSONB       NOT NULL,
  batch_key   TEXT        NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wh_events_batch ON common.webhook_events (batch_key, created_at);
CREATE INDEX IF NOT EXISTS idx_wh_events_org    ON common.webhook_events (org_id, created_at);

-- Delivery log (one row per webhook × batch × attempt)
CREATE TABLE IF NOT EXISTS common.webhook_deliveries (
  id          BIGSERIAL   PRIMARY KEY,
  webhook_id  TEXT        NOT NULL REFERENCES common.webhooks(id) ON DELETE CASCADE,
  batch_key   TEXT        NOT NULL,
  event_count INT         NOT NULL DEFAULT 0,
  attempt     INT         NOT NULL DEFAULT 1,
  status_code INT,
  error       TEXT,
  delivered_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wh_deliveries_webhook ON common.webhook_deliveries (webhook_id, delivered_at DESC);

INSERT INTO common.schema_versions (version, description)
VALUES (9, 'Webhooks: event queue, delivery log, time-window batching')
ON CONFLICT (version) DO NOTHING;
