-- ==============================================================================
-- Migration: 00003_saas_billing
-- Description: SaaS Subscription plans, billing, and payment history.
-- ==============================================================================

-- 1. SUBSCRIPTION PLANS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.subscription_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) UNIQUE NOT NULL, -- e.g., 'STARTER', 'PRO_MONTHLY'
    name VARCHAR(100) NOT NULL,
    description TEXT,
    price_monthly DECIMAL(10,2) NOT NULL CHECK (price_monthly >= 0),
    price_yearly DECIMAL(10,2) NOT NULL CHECK (price_yearly >= 0),
    features JSONB,
    status VARCHAR(50) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE', 'ARCHIVED')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);
COMMENT ON TABLE public.subscription_plans IS 'Available SaaS tiers and pricing details.';

CREATE INDEX IF NOT EXISTS idx_sub_plans_active ON public.subscription_plans(id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_sub_plans_updated_at
BEFORE UPDATE ON public.subscription_plans
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_sub_plans
AFTER INSERT OR UPDATE OR DELETE ON public.subscription_plans
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY subscription_plans_read_policy ON public.subscription_plans
    FOR SELECT USING (true);


-- 2. SUBSCRIPTIONS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    plan_id UUID NOT NULL REFERENCES public.subscription_plans(id) ON DELETE RESTRICT,
    provider VARCHAR(50), -- e.g., 'STRIPE', 'RAZORPAY', 'INTERNAL'
    provider_subscription_id VARCHAR(255),
    status VARCHAR(50) NOT NULL DEFAULT 'TRIAL' CHECK (status IN ('TRIAL', 'ACTIVE', 'PAST_DUE', 'CANCELED')),
    billing_cycle VARCHAR(20) NOT NULL DEFAULT 'MONTHLY' CHECK (billing_cycle IN ('MONTHLY', 'YEARLY')),
    trial_ends_at TIMESTAMP WITH TIME ZONE,
    current_period_start TIMESTAMP WITH TIME ZONE,
    current_period_end TIMESTAMP WITH TIME ZONE,
    cancel_at_period_end BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);
COMMENT ON TABLE public.subscriptions IS 'Active tenant subscriptions mapping to plans.';

CREATE INDEX IF NOT EXISTS idx_subscriptions_tenant_id ON public.subscriptions(tenant_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_active ON public.subscriptions(tenant_id) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_active_subscription ON public.subscriptions(tenant_id) WHERE status IN ('ACTIVE', 'TRIAL') AND deleted_at IS NULL;

CREATE TRIGGER set_subscriptions_updated_at
BEFORE UPDATE ON public.subscriptions
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_subscriptions
AFTER INSERT OR UPDATE OR DELETE ON public.subscriptions
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY subscriptions_isolation_policy ON public.subscriptions
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- 3. TENANT BILLING DETAILS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.tenant_billing (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    billing_email VARCHAR(255),
    billing_address TEXT,
    tax_id VARCHAR(100),
    provider VARCHAR(50),
    provider_customer_id VARCHAR(255),
    payment_method_id VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(tenant_id)
);
COMMENT ON TABLE public.tenant_billing IS 'Secure billing and tax information for a tenant.';

CREATE INDEX IF NOT EXISTS idx_tenant_billing_tenant_id ON public.tenant_billing(tenant_id);

CREATE TRIGGER set_tenant_billing_updated_at
BEFORE UPDATE ON public.tenant_billing
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_tenant_billing
AFTER INSERT OR UPDATE OR DELETE ON public.tenant_billing
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.tenant_billing ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_billing_isolation_policy ON public.tenant_billing
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- 4. PAYMENT TRANSACTIONS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payment_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    subscription_id UUID REFERENCES public.subscriptions(id) ON DELETE SET NULL,
    gateway_name VARCHAR(50),
    gateway_transaction_id VARCHAR(255),
    amount DECIMAL(10,2) NOT NULL CHECK (amount >= 0),
    currency VARCHAR(10) DEFAULT 'INR' CHECK (currency IN ('INR', 'USD', 'EUR', 'GBP')),
    status VARCHAR(50) NOT NULL CHECK (status IN ('SUCCESS', 'FAILED', 'PENDING', 'REFUNDED')),
    invoice_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);
COMMENT ON TABLE public.payment_transactions IS 'Record of all SaaS billing charges and refunds.';

CREATE INDEX IF NOT EXISTS idx_payment_tx_tenant_id ON public.payment_transactions(tenant_id);
CREATE INDEX IF NOT EXISTS idx_payment_tx_active ON public.payment_transactions(tenant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_payment_tx_updated_at
BEFORE UPDATE ON public.payment_transactions
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_payment_transactions
AFTER INSERT OR UPDATE OR DELETE ON public.payment_transactions
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.payment_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY payment_tx_isolation_policy ON public.payment_transactions
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- ==============================================================================
-- ROLLBACK INSTRUCTIONS
-- ==============================================================================
/*
DROP POLICY IF EXISTS payment_tx_isolation_policy ON public.payment_transactions;
DROP POLICY IF EXISTS tenant_billing_isolation_policy ON public.tenant_billing;
DROP POLICY IF EXISTS subscriptions_isolation_policy ON public.subscriptions;
DROP POLICY IF EXISTS subscription_plans_read_policy ON public.subscription_plans;

DROP TABLE IF EXISTS public.payment_transactions CASCADE;
DROP TABLE IF EXISTS public.tenant_billing CASCADE;
DROP TABLE IF EXISTS public.subscriptions CASCADE;
DROP TABLE IF EXISTS public.subscription_plans CASCADE;
*/
