-- ==============================================================================
-- Migration: 00012_integrations
-- Description: External API Integrations, Credentials, and Webhooks.
-- ==============================================================================

-- 1. INTEGRATIONS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.integrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    outlet_id UUID REFERENCES public.outlets(id) ON DELETE SET NULL, -- Null if tenant-level integration
    provider VARCHAR(100) NOT NULL, -- E.g., 'ZOMATO', 'SWIGGY', 'QUICKBOOKS', 'STRIPE', 'RAZORPAY'
    integration_type VARCHAR(50) NOT NULL CHECK (integration_type IN ('DELIVERY', 'ACCOUNTING', 'PAYMENT', 'SMS', 'MARKETING', 'ERP', 'OTHER')),
    -- NOTE: credentials should ideally be stored in a secure vault; this column stores either JSON or a vault reference token.
    credentials JSONB, 
    credential_reference VARCHAR(255),
    external_account_id VARCHAR(255),
    settings JSONB,
    status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE', 'ERROR', 'PENDING_AUTH')),
    sync_frequency_minutes INT DEFAULT 60 CHECK (sync_frequency_minutes >= 0),
    last_sync_at TIMESTAMP WITH TIME ZONE,
    last_successful_sync_at TIMESTAMP WITH TIME ZONE,
    next_sync_at TIMESTAMP WITH TIME ZONE,
    error_message TEXT,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(tenant_id, outlet_id, provider)
);
COMMENT ON TABLE public.integrations IS 'Configuration and credentials for third-party external services.';

CREATE INDEX IF NOT EXISTS idx_integrations_tenant_id ON public.integrations(tenant_id);
CREATE INDEX IF NOT EXISTS idx_integrations_outlet_id ON public.integrations(outlet_id);
CREATE INDEX IF NOT EXISTS idx_integrations_active ON public.integrations(tenant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_integrations_updated_at
BEFORE UPDATE ON public.integrations
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_integrations
AFTER INSERT OR UPDATE OR DELETE ON public.integrations
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.integrations ENABLE ROW LEVEL SECURITY;

CREATE POLICY integrations_isolation_policy ON public.integrations
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- 2. INTEGRATION LOGS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.integration_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    integration_id UUID REFERENCES public.integrations(id) ON DELETE CASCADE,
    direction VARCHAR(50) NOT NULL CHECK (direction IN ('INBOUND', 'OUTBOUND')),
    endpoint VARCHAR(500),
    request_payload JSONB,
    response_payload JSONB,
    status_code INT,
    status VARCHAR(50) NOT NULL CHECK (status IN ('SUCCESS', 'FAILED', 'PENDING')),
    duration_ms INT CHECK (duration_ms >= 0),
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);
COMMENT ON TABLE public.integration_logs IS 'Audit trail for external API requests and responses.';

CREATE INDEX IF NOT EXISTS idx_integration_logs_tenant_id ON public.integration_logs(tenant_id);
CREATE INDEX IF NOT EXISTS idx_integration_logs_integration ON public.integration_logs(integration_id);
CREATE INDEX IF NOT EXISTS idx_integration_logs_status ON public.integration_logs(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_integration_logs_created_at ON public.integration_logs(tenant_id, created_at);
CREATE INDEX IF NOT EXISTS idx_integration_logs_active ON public.integration_logs(tenant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_integration_logs_updated_at
BEFORE UPDATE ON public.integration_logs
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Skip auditing on logs table to prevent recursive bloat
-- CREATE TRIGGER audit_integration_logs ...

ALTER TABLE public.integration_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY integration_logs_isolation_policy ON public.integration_logs
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- 3. WEBHOOKS
-- ------------------------------------------------------------------------------
-- NOTE: Future migrations may introduce `webhook_delivery_logs` to maintain
-- a detailed retry and delivery attempt history per outbound webhook payload.
CREATE TABLE IF NOT EXISTS public.webhooks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    event_type VARCHAR(100) NOT NULL, -- E.g., 'order.created', 'inventory.low'
    endpoint_url VARCHAR(500) NOT NULL,
    secret_key VARCHAR(255),
    signature_algorithm VARCHAR(50) DEFAULT 'HMAC-SHA256',
    event_filters JSONB, -- Optional filters, e.g. only trigger if amount > 100
    is_active BOOLEAN DEFAULT true,
    max_retries INT DEFAULT 3 CHECK (max_retries >= 0),
    retry_backoff_seconds INT DEFAULT 300 CHECK (retry_backoff_seconds >= 0),
    retry_count INT DEFAULT 0 CHECK (retry_count >= 0),
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(tenant_id, event_type, endpoint_url)
);
COMMENT ON TABLE public.webhooks IS 'Outbound webhook configurations for pushing events to external systems.';

CREATE INDEX IF NOT EXISTS idx_webhooks_tenant_id ON public.webhooks(tenant_id);
CREATE INDEX IF NOT EXISTS idx_webhooks_active ON public.webhooks(tenant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_webhooks_updated_at
BEFORE UPDATE ON public.webhooks
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_webhooks
AFTER INSERT OR UPDATE OR DELETE ON public.webhooks
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.webhooks ENABLE ROW LEVEL SECURITY;

CREATE POLICY webhooks_isolation_policy ON public.webhooks
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- ==============================================================================
-- ROLLBACK INSTRUCTIONS
-- ==============================================================================
/*
DROP POLICY IF EXISTS webhooks_isolation_policy ON public.webhooks;
DROP POLICY IF EXISTS integration_logs_isolation_policy ON public.integration_logs;
DROP POLICY IF EXISTS integrations_isolation_policy ON public.integrations;

DROP TABLE IF EXISTS public.webhooks CASCADE;
DROP TABLE IF EXISTS public.integration_logs CASCADE;
DROP TABLE IF EXISTS public.integrations CASCADE;
*/
