-- Migration 092: Idempotency Keys, Transactional Outbox Events, and Provider Webhooks
-- Additive DDL for Meet Commerce platform reliability (Blueprint §04.3, §04.4, §04.5)

-- 1. Idempotency Keys Table
CREATE TABLE IF NOT EXISTS idempotency_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT NOT NULL,
  user_id UUID NOT NULL REFERENCES users(id),
  request_hash TEXT NOT NULL,
  response_snapshot JSONB,
  status TEXT NOT NULL DEFAULT 'PROCESSING', -- PROCESSING | COMPLETE | FAILED
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS uix_idempotency_keys_key_user ON idempotency_keys(key, user_id);

-- 2. Transactional Outbox Events Table
CREATE TABLE IF NOT EXISTS outbox_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type TEXT NOT NULL,
  aggregate_type TEXT NOT NULL,
  aggregate_id UUID NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}',
  correlation_id UUID,
  causation_id UUID,
  published_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_outbox_events_unpublished ON outbox_events(created_at) WHERE published_at IS NULL;

-- 3. Provider Webhook Events Table
CREATE TABLE IF NOT EXISTS provider_webhook_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider TEXT NOT NULL, -- RAZORPAY | WHATSAPP | SMS | MEDIA_SCAN
  provider_event_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  raw_body TEXT NOT NULL,
  processed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uix_webhook_provider_event ON provider_webhook_events(provider, provider_event_id);
