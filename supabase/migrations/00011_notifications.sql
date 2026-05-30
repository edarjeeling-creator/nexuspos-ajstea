-- ==============================================================================
-- Migration: 00011_notifications
-- Description: System Notifications, Emails, and Communication Templates.
-- ==============================================================================

-- 1. NOTIFICATION TEMPLATES
-- ------------------------------------------------------------------------------
-- NOTE: Future migrations will introduce `notification_preferences` to allow 
-- users to opt-in/opt-out of specific notification types and channels.
CREATE TABLE IF NOT EXISTS public.notification_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    template_code VARCHAR(100) NOT NULL,
    version_no INT DEFAULT 1 CHECK (version_no >= 1),
    language_code VARCHAR(10) DEFAULT 'en',
    name VARCHAR(255) NOT NULL,
    channel VARCHAR(50) NOT NULL CHECK (channel IN ('EMAIL', 'SMS', 'PUSH', 'IN_APP', 'WHATSAPP')),
    notification_type VARCHAR(50) DEFAULT 'TRANSACTIONAL' CHECK (notification_type IN ('TRANSACTIONAL', 'MARKETING', 'SYSTEM_ALERT')),
    subject_template VARCHAR(255),
    body_template TEXT NOT NULL,
    variables JSONB, -- Document expected variables for the template
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(tenant_id, template_code, channel, language_code, version_no)
);
COMMENT ON TABLE public.notification_templates IS 'Templates for generating emails, SMS, and in-app notifications.';

CREATE INDEX IF NOT EXISTS idx_notification_templates_tenant_id ON public.notification_templates(tenant_id);
CREATE INDEX IF NOT EXISTS idx_notification_templates_active ON public.notification_templates(tenant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_notification_templates_updated_at
BEFORE UPDATE ON public.notification_templates
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_notification_templates
AFTER INSERT OR UPDATE OR DELETE ON public.notification_templates
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.notification_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY notification_templates_isolation_policy ON public.notification_templates
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- 2. NOTIFICATIONS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    outlet_id UUID REFERENCES public.outlets(id) ON DELETE SET NULL,
    recipient_profile_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    recipient_email VARCHAR(255),
    recipient_phone VARCHAR(50),
    channel VARCHAR(50) NOT NULL CHECK (channel IN ('EMAIL', 'SMS', 'PUSH', 'IN_APP', 'WHATSAPP')),
    notification_type VARCHAR(50) DEFAULT 'TRANSACTIONAL' CHECK (notification_type IN ('TRANSACTIONAL', 'MARKETING', 'SYSTEM_ALERT')),
    priority VARCHAR(50) DEFAULT 'NORMAL' CHECK (priority IN ('LOW', 'NORMAL', 'HIGH', 'URGENT')),
    subject VARCHAR(255),
    body TEXT NOT NULL,
    reference_type VARCHAR(100), -- E.g., 'ORDER', 'INVOICE', 'SYSTEM_ALERT'
    reference_id UUID,
    status VARCHAR(50) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PROCESSING', 'SENT', 'FAILED', 'CANCELLED')),
    retry_count INT DEFAULT 0 CHECK (retry_count >= 0),
    max_retries INT DEFAULT 3 CHECK (max_retries >= 0),
    last_retry_at TIMESTAMP WITH TIME ZONE,
    scheduled_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    provider_name VARCHAR(100), -- E.g., 'Twilio', 'SendGrid', 'Firebase'
    provider_response JSONB,
    metadata JSONB,
    error_message TEXT,
    sent_at TIMESTAMP WITH TIME ZONE,
    read_at TIMESTAMP WITH TIME ZONE, 
    opened_at TIMESTAMP WITH TIME ZONE,
    clicked_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);
COMMENT ON TABLE public.notifications IS 'Log and queue of all outbound system notifications.';

CREATE INDEX IF NOT EXISTS idx_notifications_tenant_id ON public.notifications(tenant_id);
CREATE INDEX IF NOT EXISTS idx_notifications_recipient ON public.notifications(recipient_profile_id);
CREATE INDEX IF NOT EXISTS idx_notifications_status ON public.notifications(tenant_id, status);
-- Queue processing index: prioritize finding pending records that are due to be sent
CREATE INDEX IF NOT EXISTS idx_notifications_queue ON public.notifications(tenant_id, status, scheduled_at, priority) WHERE status = 'PENDING' AND deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_notifications_active ON public.notifications(tenant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_notifications_updated_at
BEFORE UPDATE ON public.notifications
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Typically, we do not audit the notifications queue heavily to save space, but for consistency:
CREATE TRIGGER audit_notifications
AFTER INSERT OR UPDATE OR DELETE ON public.notifications
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY notifications_isolation_policy ON public.notifications
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- ==============================================================================
-- ROLLBACK INSTRUCTIONS
-- ==============================================================================
/*
DROP POLICY IF EXISTS notifications_isolation_policy ON public.notifications;
DROP POLICY IF EXISTS notification_templates_isolation_policy ON public.notification_templates;

DROP TABLE IF EXISTS public.notifications CASCADE;
DROP TABLE IF EXISTS public.notification_templates CASCADE;
*/
