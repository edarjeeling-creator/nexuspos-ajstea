-- ==============================================================================
-- Migration: 00026_mobile_infrastructure
-- Description: Mobile Devices Registry, Push Tokens, and Health Monitoring
-- ==============================================================================

-- 1. MOBILE DEVICES REGISTRY
-- ------------------------------------------------------------------------------
CREATE TABLE public.mobile_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    outlet_id UUID REFERENCES public.outlets(id) ON DELETE CASCADE,
    device_name VARCHAR(255) NOT NULL, -- e.g., 'Waiter Tablet 1', 'Manager iPhone'
    device_type VARCHAR(50) NOT NULL CHECK (device_type IN ('IOS', 'ANDROID', 'CUSTOM_HARDWARE')),
    app_role VARCHAR(50) NOT NULL CHECK (app_role IN ('WAITER', 'KITCHEN', 'MANAGER', 'OWNER', 'CUSTOMER')),
    expo_push_token VARCHAR(255),
    app_version VARCHAR(50),
    os_version VARCHAR(50),
    last_active_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    status VARCHAR(50) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE', 'LOST_OR_STOLEN')),
    last_sync_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. APP HEALTH EVENTS (Monitoring)
-- ------------------------------------------------------------------------------
CREATE TABLE public.app_health_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    device_id UUID NOT NULL REFERENCES public.mobile_devices(id) ON DELETE CASCADE,
    event_type VARCHAR(50) NOT NULL CHECK (event_type IN ('CRASH', 'SYNC_FAILURE', 'OFFLINE_DETECTED', 'LOW_BATTERY', 'PERFORMANCE_WARNING')),
    severity VARCHAR(50) NOT NULL CHECK (severity IN ('INFO', 'WARNING', 'CRITICAL')),
    message TEXT,
    stack_trace TEXT,
    battery_level DECIMAL(3,2),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. DEVICE-AWARE AUDIT LOGGING EXTENSION
-- ------------------------------------------------------------------------------
-- We will add a column to audit_logs to explicitly track the hardware device that initiated an action
ALTER TABLE public.audit_logs ADD COLUMN source_device_id UUID REFERENCES public.mobile_devices(id) ON DELETE SET NULL;

-- 4. PUSH NOTIFICATION OUTBOX
-- ------------------------------------------------------------------------------
CREATE TABLE public.push_notification_outbox (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    device_id UUID NOT NULL REFERENCES public.mobile_devices(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    data JSONB,
    status VARCHAR(50) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'SENT', 'FAILED')),
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    processed_at TIMESTAMPTZ
);

-- RLS
ALTER TABLE public.mobile_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_health_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.push_notification_outbox ENABLE ROW LEVEL SECURITY;

CREATE POLICY md_isolation ON public.mobile_devices FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY ahe_isolation ON public.app_health_events FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY pno_isolation ON public.push_notification_outbox FOR ALL USING (tenant_id = public.get_current_tenant_id());
