-- Migration 093: Dashboard User 2FA Settings and Device Session Management
-- Additive DDL for Meet Commerce security & session control (Blueprint §05.1, §05.2)

-- 1. User 2FA Settings Table
CREATE TABLE IF NOT EXISTS user_2fa_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID UNIQUE NOT NULL REFERENCES users(id),
  method TEXT NOT NULL DEFAULT 'TOTP', -- TOTP | SMS | EMAIL
  secret_hash TEXT NOT NULL,
  recovery_codes_hash TEXT,
  is_verified BOOLEAN NOT NULL DEFAULT FALSE,
  verified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. User Device Sessions Table
CREATE TABLE IF NOT EXISTS user_device_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  session_version INTEGER NOT NULL,
  device_fingerprint TEXT NOT NULL,
  ip_address TEXT,
  user_agent TEXT,
  device_type TEXT NOT NULL DEFAULT 'UNKNOWN', -- MOBILE_APP | WEB_DASHBOARD | TABLET | UNKNOWN
  last_active_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_revoked BOOLEAN NOT NULL DEFAULT FALSE,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_device_sessions_user ON user_device_sessions(user_id, is_revoked, expires_at);
