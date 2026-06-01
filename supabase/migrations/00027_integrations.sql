-- ==============================================================================
-- Migration: 00027_integrations
-- Description: Marketplace & Payment Gateways, Webhook Queues
-- ==============================================================================

-- 1. PAYMENT INTENTS (Stripe, Razorpay, UPI)
-- ------------------------------------------------------------------------------
CREATE TABLE public.payment_intents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    outlet_id UUID REFERENCES public.outlets(id),
    order_id UUID REFERENCES public.order_events(id),
    provider VARCHAR(50) NOT NULL CHECK (provider IN ('STRIPE', 'RAZORPAY', 'CASHFREE', 'PHONEPE', 'PAYTM', 'UPI')),
    provider_reference_id VARCHAR(255) NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    currency VARCHAR(10) DEFAULT 'USD',
    status VARCHAR(50) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PROCESSING', 'SUCCEEDED', 'FAILED', 'CANCELED')),
    payment_method_details JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. PAYMENT REFUNDS
-- ------------------------------------------------------------------------------
CREATE TABLE public.payment_refunds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    payment_intent_id UUID NOT NULL REFERENCES public.payment_intents(id),
    provider_refund_id VARCHAR(255),
    amount DECIMAL(15,2) NOT NULL,
    reason TEXT,
    status VARCHAR(50) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'SUCCEEDED', 'FAILED')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. PAYMENT RECONCILIATION
-- ------------------------------------------------------------------------------
CREATE TABLE public.payment_reconciliation (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    provider VARCHAR(50) NOT NULL,
    payout_id VARCHAR(255) NOT NULL,
    total_amount DECIMAL(15,2) NOT NULL,
    fees_deducted DECIMAL(15,2) NOT NULL,
    net_payout DECIMAL(15,2) NOT NULL,
    payout_date DATE NOT NULL,
    status VARCHAR(50) DEFAULT 'MATCHED' CHECK (status IN ('UNMATCHED', 'MATCHED', 'DISCREPANCY')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. MARKETPLACE MAPPINGS (Zomato/Swiggy -> Local Products)
-- ------------------------------------------------------------------------------
CREATE TABLE public.marketplace_mappings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    marketplace VARCHAR(50) NOT NULL CHECK (marketplace IN ('ZOMATO', 'SWIGGY', 'ONDC', 'UBER_EATS')),
    marketplace_item_id VARCHAR(255) NOT NULL,
    local_menu_item_id UUID NOT NULL REFERENCES public.menu_items(id) ON DELETE CASCADE,
    price_override DECIMAL(15,2), -- Marketplaces often have higher prices
    is_active BOOLEAN DEFAULT true,
    UNIQUE(tenant_id, marketplace, marketplace_item_id)
);

-- 5. MARKETPLACE ORDERS TRACKING
-- ------------------------------------------------------------------------------
CREATE TABLE public.marketplace_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    outlet_id UUID REFERENCES public.outlets(id),
    marketplace VARCHAR(50) NOT NULL,
    marketplace_order_id VARCHAR(255) NOT NULL,
    local_order_id UUID REFERENCES public.order_events(id),
    status VARCHAR(50) DEFAULT 'RECEIVED' CHECK (status IN ('RECEIVED', 'ACCEPTED', 'REJECTED', 'DISPATCHED', 'DELIVERED', 'CANCELED')),
    rider_details JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, marketplace, marketplace_order_id)
);

-- 6. DEAD-LETTER QUEUE (Webhook Failures)
-- ------------------------------------------------------------------------------
CREATE TABLE public.integration_dead_letters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    source_system VARCHAR(100) NOT NULL, -- e.g., 'ZOMATO_WEBHOOK'
    payload JSONB NOT NULL,
    error_reason TEXT,
    retry_count INT DEFAULT 0,
    status VARCHAR(50) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'RESOLVED', 'IGNORED')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    last_retried_at TIMESTAMPTZ
);

-- RLS
ALTER TABLE public.payment_intents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_refunds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_reconciliation ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_mappings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.integration_dead_letters ENABLE ROW LEVEL SECURITY;

CREATE POLICY pi_isolation ON public.payment_intents FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY prf_isolation ON public.payment_refunds FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY prc_isolation ON public.payment_reconciliation FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY mm_isolation ON public.marketplace_mappings FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY mo_isolation ON public.marketplace_orders FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY idl_isolation ON public.integration_dead_letters FOR ALL USING (tenant_id = public.get_current_tenant_id());
