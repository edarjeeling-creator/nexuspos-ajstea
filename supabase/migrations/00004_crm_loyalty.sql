-- ==============================================================================
-- Migration: 00004_crm_loyalty
-- Description: Customers and loyalty points tracking.
-- ==============================================================================

-- 1. CUSTOMERS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    signup_outlet_id UUID REFERENCES public.outlets(id) ON DELETE SET NULL,
    customer_code VARCHAR(100),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    full_name VARCHAR(255) GENERATED ALWAYS AS (
        TRIM(COALESCE(first_name, '') || ' ' || COALESCE(last_name, ''))
    ) STORED,
    email VARCHAR(255),
    phone VARCHAR(50),
    date_of_birth DATE,
    customer_tier VARCHAR(50) DEFAULT 'STANDARD', -- e.g., STANDARD, BRONZE, SILVER, GOLD
    accepts_marketing BOOLEAN DEFAULT false,
    marketing_email_opt_in BOOLEAN DEFAULT false,
    marketing_sms_opt_in BOOLEAN DEFAULT false,
    status VARCHAR(50) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE', 'BANNED')),
    -- Note: loyalty_points acts as a cached aggregate of loyalty_transactions.
    loyalty_points INT DEFAULT 0 CHECK (loyalty_points >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);
COMMENT ON TABLE public.customers IS 'CRM entity tracking customer profiles. loyalty_points is a cached aggregate sum.';

CREATE INDEX IF NOT EXISTS idx_customers_tenant_id ON public.customers(tenant_id);
CREATE INDEX IF NOT EXISTS idx_customers_signup_outlet_id ON public.customers(signup_outlet_id);
CREATE INDEX IF NOT EXISTS idx_customers_active ON public.customers(tenant_id) WHERE deleted_at IS NULL;

-- Partial unique indexes to allow re-using phone/email if a customer is soft deleted
CREATE UNIQUE INDEX IF NOT EXISTS idx_customers_unique_phone ON public.customers(tenant_id, phone) WHERE deleted_at IS NULL AND phone IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_customers_unique_email ON public.customers(tenant_id, email) WHERE deleted_at IS NULL AND email IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_customers_unique_code ON public.customers(tenant_id, customer_code) WHERE deleted_at IS NULL AND customer_code IS NOT NULL;

-- Search index
CREATE INDEX IF NOT EXISTS idx_customers_search ON public.customers USING gin (
    to_tsvector('english', COALESCE(full_name, '') || ' ' || COALESCE(email, '') || ' ' || COALESCE(phone, ''))
);

CREATE TRIGGER set_customers_updated_at
BEFORE UPDATE ON public.customers
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_customers
AFTER INSERT OR UPDATE OR DELETE ON public.customers
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;

CREATE POLICY customers_isolation_policy ON public.customers
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- 2. LOYALTY TRANSACTIONS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.loyalty_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    outlet_id UUID REFERENCES public.outlets(id) ON DELETE SET NULL,
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
    points_change INT NOT NULL, -- positive or negative
    transaction_type VARCHAR(50) NOT NULL CHECK (transaction_type IN ('EARNED', 'REDEEMED', 'EXPIRED', 'ADJUSTED')),
    reason VARCHAR(255),
    reference_type VARCHAR(100), -- e.g., 'ORDER', 'REFUND', 'MANUAL_ADJUSTMENT'
    reference_id UUID, -- order_id context
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);
COMMENT ON TABLE public.loyalty_transactions IS 'Immutable ledger for customer loyalty point variations over time.';

CREATE INDEX IF NOT EXISTS idx_loyalty_tx_tenant_id ON public.loyalty_transactions(tenant_id);
CREATE INDEX IF NOT EXISTS idx_loyalty_tx_customer ON public.loyalty_transactions(customer_id);
CREATE INDEX IF NOT EXISTS idx_loyalty_tx_active ON public.loyalty_transactions(tenant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_loyalty_transactions_updated_at
BEFORE UPDATE ON public.loyalty_transactions
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_loyalty_transactions
AFTER INSERT OR UPDATE OR DELETE ON public.loyalty_transactions
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.loyalty_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY loyalty_transactions_isolation_policy ON public.loyalty_transactions
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- ==============================================================================
-- ROLLBACK INSTRUCTIONS
-- ==============================================================================
/*
DROP POLICY IF EXISTS loyalty_transactions_isolation_policy ON public.loyalty_transactions;
DROP POLICY IF EXISTS customers_isolation_policy ON public.customers;

DROP TABLE IF EXISTS public.loyalty_transactions CASCADE;
DROP TABLE IF EXISTS public.customers CASCADE;
*/
