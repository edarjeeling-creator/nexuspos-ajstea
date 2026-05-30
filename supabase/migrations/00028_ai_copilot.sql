-- ==============================================================================
-- Migration: 00028_ai_copilot
-- Description: WhatsApp Commerce & AI Executive Copilot Structure
-- ==============================================================================

-- 1. WHATSAPP MESSAGE LOGS
-- ------------------------------------------------------------------------------
CREATE TABLE public.whatsapp_message_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES public.customers(id),
    phone_number VARCHAR(20) NOT NULL,
    message_type VARCHAR(50) NOT NULL CHECK (message_type IN ('ORDER_CONFIRMATION', 'ORDER_READY', 'DIGITAL_RECEIPT', 'LOYALTY_UPDATE', 'FEEDBACK_REQUEST', 'CAMPAIGN', 'BIRTHDAY_OFFER')),
    template_name VARCHAR(100),
    status VARCHAR(50) DEFAULT 'QUEUED' CHECK (status IN ('QUEUED', 'SENT', 'DELIVERED', 'READ', 'FAILED')),
    provider_message_id VARCHAR(255),
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    sent_at TIMESTAMPTZ
);

-- 2. AI EXECUTIVE COPILOT CONVERSATIONS
-- ------------------------------------------------------------------------------
CREATE TABLE public.ai_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id),
    title VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.ai_conversation_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    conversation_id UUID NOT NULL REFERENCES public.ai_conversations(id) ON DELETE CASCADE,
    role VARCHAR(50) NOT NULL CHECK (role IN ('USER', 'ASSISTANT', 'SYSTEM', 'TOOL')),
    content TEXT NOT NULL,
    sql_query_generated TEXT, -- Logs the exact SQL the AI used to derive the answer
    tokens_used INT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. PROACTIVE AI INSIGHTS
-- ------------------------------------------------------------------------------
CREATE TABLE public.ai_insights (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    outlet_id UUID REFERENCES public.outlets(id),
    insight_type VARCHAR(100) NOT NULL CHECK (insight_type IN ('ANOMALY_DETECTION', 'TREND_ANALYSIS', 'INVENTORY_WARNING', 'STAFFING_RECOMMENDATION')),
    severity VARCHAR(50) DEFAULT 'INFO' CHECK (severity IN ('INFO', 'WARNING', 'CRITICAL', 'OPPORTUNITY')),
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    action_url VARCHAR(255),
    is_dismissed BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. NEW RBAC PERMISSIONS (Appending to existing roles via API)
-- We document them here conceptually as the application handles role JSON objects.
-- The user specified: ai.read, ai.ask, ai.admin
-- (Usually managed in the app-level constants, but we log the requirement here)

-- RLS
ALTER TABLE public.whatsapp_message_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_conversation_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_insights ENABLE ROW LEVEL SECURITY;

CREATE POLICY wml_isolation ON public.whatsapp_message_logs FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY aic_isolation ON public.ai_conversations FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY aicm_isolation ON public.ai_conversation_messages FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY aii_isolation ON public.ai_insights FOR ALL USING (tenant_id = public.get_current_tenant_id());
