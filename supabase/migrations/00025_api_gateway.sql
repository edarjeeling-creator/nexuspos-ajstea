-- ==============================================================================
-- Migration: 00025_api_gateway
-- Description: API Keys, Integration Logging for Enterprise Monitoring
-- ==============================================================================

-- 1. API KEYS
-- ------------------------------------------------------------------------------
CREATE TABLE public.api_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    outlet_id UUID REFERENCES public.outlets(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL, -- e.g., 'Zomato Integration Key', 'Customer Mobile App'
    key_hash VARCHAR(255) NOT NULL, -- Never store raw keys
    permissions JSONB DEFAULT '[]'::jsonb, -- e.g. ["orders.create", "menu.read"]
    is_active BOOLEAN DEFAULT true,
    expires_at TIMESTAMPTZ,
    last_used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- 2. INTEGRATION LOGS (Enterprise Monitoring)
-- ------------------------------------------------------------------------------
CREATE TABLE public.integration_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    api_key_id UUID REFERENCES public.api_keys(id), -- Null if failed auth
    system_type VARCHAR(100) NOT NULL CHECK (system_type IN ('API_GATEWAY', 'WEBHOOK', 'PAYMENT_GATEWAY', 'MARKETPLACE', 'SYNC_ENGINE')),
    endpoint VARCHAR(255) NOT NULL,
    method VARCHAR(10) NOT NULL,
    status_code INT,
    response_time_ms INT,
    payload_snippet JSONB, -- Scrubbed/truncated payload for debugging
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast monitoring dashboard queries
CREATE INDEX idx_integration_logs_tenant_created ON public.integration_logs(tenant_id, created_at DESC);
CREATE INDEX idx_integration_logs_errors ON public.integration_logs(tenant_id, status_code) WHERE status_code >= 400;

-- RLS
ALTER TABLE public.api_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.integration_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY ak_isolation ON public.api_keys FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY il_isolation ON public.integration_logs FOR ALL USING (tenant_id = public.get_current_tenant_id());
