-- vizion-onboarding schema (v1)
-- Tables: onboard_session, onboard_step

CREATE TABLE IF NOT EXISTS onboard_request (
  id BIGSERIAL PRIMARY KEY,
  request_id TEXT NOT NULL UNIQUE,
  client_key TEXT,
  status TEXT NOT NULL DEFAULT 'received' CHECK (status IN ('received','in_progress','completed','failed')),
  payload JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_onboard_request_status ON onboard_request (status, created_at DESC);

CREATE TABLE IF NOT EXISTS onboard_session (
  id BIGSERIAL PRIMARY KEY,
  workspace_key TEXT NOT NULL,
  initiated_by TEXT NOT NULL DEFAULT 'platform',
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','in_progress','completed','failed')),
  modules_completed JSONB DEFAULT '[]'::jsonb,
  payload JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_onboard_session_status ON onboard_session (status, created_at DESC);

CREATE TABLE IF NOT EXISTS onboard_step (
  id BIGSERIAL PRIMARY KEY,
  session_id BIGINT NOT NULL REFERENCES onboard_session(id) ON DELETE CASCADE,
  module_key TEXT NOT NULL,
  step_name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','running','completed','failed','skipped')),
  output JSONB,
  error TEXT,
  started_at TIMESTAMPTZ,
  finished_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_onboard_step_session ON onboard_step (session_id, module_key);
