-- ==============================================================================
-- Migration: 00001_initial_schema
-- Description: Core multi-tenant architecture tables
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS public.tenants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    status VARCHAR(50) DEFAULT 'ACTIVE',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.outlets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    address TEXT,
    phone VARCHAR(50),
    status VARCHAR(50) DEFAULT 'ACTIVE',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_name TEXT NOT NULL,
    record_id UUID NOT NULL,
    action TEXT NOT NULL,
    old_data JSONB,
    new_data JSONB,
    changed_by UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION public.process_audit_log()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        INSERT INTO public.audit_logs (table_name, record_id, action, old_data, changed_by)
        VALUES (TG_TABLE_NAME, OLD.id, TG_OP, row_to_json(OLD)::jsonb, auth.uid());
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO public.audit_logs (table_name, record_id, action, old_data, new_data, changed_by)
        VALUES (TG_TABLE_NAME, NEW.id, TG_OP, row_to_json(OLD)::jsonb, row_to_json(NEW)::jsonb, auth.uid());
        RETURN NEW;
    ELSIF (TG_OP = 'INSERT') THEN
        INSERT INTO public.audit_logs (table_name, record_id, action, new_data, changed_by)
        VALUES (TG_TABLE_NAME, NEW.id, TG_OP, row_to_json(NEW)::jsonb, auth.uid());
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.get_current_tenant_id()
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN (current_setting('request.jwt.claims', true)::jsonb->>'tenant_id')::UUID;
END;
$$ ;
-- ==============================================================================
-- Migration: 00002_auth_rbac
-- Description: Supabase Auth integration, Profiles, and strict Role-Based Access Control.
-- ==============================================================================

-- 1. PROFILES (Linked to auth.users)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    tenant_id UUID REFERENCES public.tenants(id) ON DELETE RESTRICT,
    outlet_id UUID REFERENCES public.outlets(id) ON DELETE SET NULL,
    full_name VARCHAR(255),
    phone VARCHAR(50),
    status VARCHAR(50) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);
COMMENT ON TABLE public.profiles IS 'System users, mapped 1-to-1 with Supabase auth.users.';

CREATE INDEX IF NOT EXISTS idx_profiles_tenant_id ON public.profiles(tenant_id);
CREATE INDEX IF NOT EXISTS idx_profiles_outlet_id ON public.profiles(outlet_id);
CREATE INDEX IF NOT EXISTS idx_profiles_active ON public.profiles(tenant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_profiles_updated_at
BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_profiles
AFTER INSERT OR UPDATE OR DELETE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY profiles_isolation_policy ON public.profiles
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- 2. REPLACE TENANT LOOKUP FUNCTION & ADD OUTLET LOOKUP
-- ------------------------------------------------------------------------------
-- Overwrite the stub from 00001 with secure implementation.
CREATE OR REPLACE FUNCTION public.get_current_tenant_id()
RETURNS UUID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    RETURN (
        SELECT public.profiles.tenant_id 
        FROM public.profiles 
        WHERE public.profiles.id = auth.uid()
    );
END;
$$;

-- Add outlet lookup for finer granularity.
CREATE OR REPLACE FUNCTION public.get_current_outlet_id()
RETURNS UUID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    RETURN (
        SELECT public.profiles.outlet_id 
        FROM public.profiles 
        WHERE public.profiles.id = auth.uid()
    );
END;
$$;


-- 3. RBAC (Role-Based Access Control)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE, -- NULL for system/global roles
    parent_role_id UUID REFERENCES public.roles(id) ON DELETE SET NULL, -- Role inheritance
    name VARCHAR(100) NOT NULL,
    description TEXT,
    status VARCHAR(50) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(tenant_id, name)
);
COMMENT ON TABLE public.roles IS 'Tenant-specific and global user roles with optional inheritance.';

CREATE INDEX IF NOT EXISTS idx_roles_tenant_id ON public.roles(tenant_id);
CREATE INDEX IF NOT EXISTS idx_roles_parent_id ON public.roles(parent_role_id);
CREATE INDEX IF NOT EXISTS idx_roles_active ON public.roles(tenant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_roles_updated_at
BEFORE UPDATE ON public.roles
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_roles
AFTER INSERT OR UPDATE OR DELETE ON public.roles
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;

CREATE POLICY roles_isolation_policy ON public.roles
    FOR ALL USING (tenant_id IS NULL OR tenant_id = public.get_current_tenant_id());


CREATE TABLE IF NOT EXISTS public.permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) UNIQUE NOT NULL, -- e.g., 'pos:sales:create', 'inventory:view'
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE public.permissions IS 'System-wide atomic permission flags. Not tenant-specific.';

CREATE TRIGGER set_permissions_updated_at
BEFORE UPDATE ON public.permissions
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.permissions ENABLE ROW LEVEL SECURITY;

CREATE POLICY permissions_read_policy ON public.permissions
    FOR SELECT USING (true); -- Global read access


CREATE TABLE IF NOT EXISTS public.role_permissions (
    role_id UUID NOT NULL REFERENCES public.roles(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES public.permissions(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY(role_id, permission_id)
);
COMMENT ON TABLE public.role_permissions IS 'Mapping of permissions to roles.';

CREATE INDEX IF NOT EXISTS idx_role_permissions_role ON public.role_permissions(role_id);
CREATE INDEX IF NOT EXISTS idx_role_permissions_perm ON public.role_permissions(permission_id);

CREATE TRIGGER audit_role_permissions
AFTER INSERT OR UPDATE OR DELETE ON public.role_permissions
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;

CREATE POLICY role_permissions_isolation_policy ON public.role_permissions
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.roles r 
            WHERE r.id = role_permissions.role_id 
            AND (r.tenant_id IS NULL OR r.tenant_id = public.get_current_tenant_id())
        )
    );


CREATE TABLE IF NOT EXISTS public.user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES public.roles(id) ON DELETE CASCADE,
    outlet_id UUID REFERENCES public.outlets(id) ON DELETE CASCADE, -- Role might be specific to an outlet
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE public.user_roles IS 'Assignment of roles to users, optionally scoped to an outlet.';

CREATE INDEX IF NOT EXISTS idx_user_roles_user ON public.user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_outlet ON public.user_roles(outlet_id);

-- Enforce uniqueness across user + role + outlet combo handling nulls distinctly
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_roles_unique ON public.user_roles (
    user_id, 
    role_id, 
    COALESCE(outlet_id, '00000000-0000-0000-0000-000000000000'::UUID)
);

CREATE TRIGGER set_user_roles_updated_at
BEFORE UPDATE ON public.user_roles
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_user_roles
AFTER INSERT OR UPDATE OR DELETE ON public.user_roles
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_roles_isolation_policy ON public.user_roles
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.profiles p 
            WHERE p.id = user_roles.user_id 
            AND p.tenant_id = public.get_current_tenant_id()
        )
    );


-- 4. EXAMPLE PERMISSIONS SEED
-- ------------------------------------------------------------------------------
INSERT INTO public.permissions (name, description) VALUES
('pos:order:create', 'Create a new POS order'),
('inventory:item:view', 'View inventory items'),
('inventory:stock:adjust', 'Adjust inventory stock'),
('accounting:ledger:view', 'View accounting ledgers')
ON CONFLICT DO NOTHING;


-- ==============================================================================
-- ROLLBACK INSTRUCTIONS
-- ==============================================================================
/*
-- To rollback this migration, run the following commands:
DROP POLICY IF EXISTS user_roles_isolation_policy ON public.user_roles;
DROP POLICY IF EXISTS role_permissions_isolation_policy ON public.role_permissions;
DROP POLICY IF EXISTS permissions_read_policy ON public.permissions;
DROP POLICY IF EXISTS roles_isolation_policy ON public.roles;
DROP POLICY IF EXISTS profiles_isolation_policy ON public.profiles;

DROP TABLE IF EXISTS public.user_roles CASCADE;
DROP TABLE IF EXISTS public.role_permissions CASCADE;
DROP TABLE IF EXISTS public.permissions CASCADE;
DROP TABLE IF EXISTS public.roles CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

DROP FUNCTION IF EXISTS public.get_current_outlet_id() CASCADE;

-- Revert the tenant_id function to the stub from 00001
CREATE OR REPLACE FUNCTION public.get_current_tenant_id()
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN (current_setting('request.jwt.claims', true)::jsonb->>'tenant_id')::UUID;
END;
$$;
*/
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
-- ==============================================================================
-- Migration: 00005_inventory
-- Description: Inventory management with ledger-based transactions.
-- ==============================================================================

-- 1. WAREHOUSES
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.warehouses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    outlet_id UUID REFERENCES public.outlets(id) ON DELETE SET NULL,
    name VARCHAR(255) NOT NULL,
    address TEXT,
    status VARCHAR(50) DEFAULT 'ACTIVE',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER set_warehouses_updated_at
BEFORE UPDATE ON public.warehouses
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_warehouses
AFTER INSERT OR UPDATE OR DELETE ON public.warehouses
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.warehouses ENABLE ROW LEVEL SECURITY;

CREATE POLICY warehouses_isolation_policy ON public.warehouses
    FOR ALL USING (tenant_id = public.get_current_tenant_id());

-- 2. INVENTORY CATEGORIES
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    parent_id UUID REFERENCES public.categories(id),
    status VARCHAR(50) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);
COMMENT ON TABLE public.categories IS 'Hierarchical taxonomy for inventory and menu items.';

CREATE INDEX IF NOT EXISTS idx_categories_tenant_id ON public.categories(tenant_id);
CREATE INDEX IF NOT EXISTS idx_categories_parent_id ON public.categories(parent_id);
CREATE INDEX IF NOT EXISTS idx_categories_active ON public.categories(tenant_id) WHERE deleted_at IS NULL;

-- Ensure category names are unique per level within a tenant
CREATE UNIQUE INDEX IF NOT EXISTS idx_categories_unique_name ON public.categories(
    tenant_id, 
    name, 
    COALESCE(parent_id, '00000000-0000-0000-0000-000000000000'::UUID)
) WHERE deleted_at IS NULL;

CREATE TRIGGER set_categories_updated_at
BEFORE UPDATE ON public.categories
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_categories
AFTER INSERT OR UPDATE OR DELETE ON public.categories
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY categories_isolation_policy ON public.categories
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- 2. INVENTORY ITEMS (Raw Materials)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.inventory_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    category_id UUID REFERENCES public.categories(id) ON DELETE SET NULL,
    item_code VARCHAR(100),
    name VARCHAR(255) NOT NULL,
    sku VARCHAR(100) NOT NULL,
    barcode VARCHAR(100),
    item_type VARCHAR(50) NOT NULL DEFAULT 'RAW_MATERIAL' CHECK (item_type IN ('RAW_MATERIAL', 'FINISHED_GOOD', 'PACKAGING', 'CONSUMABLE')),
    valuation_method VARCHAR(50) NOT NULL DEFAULT 'FIFO' CHECK (valuation_method IN ('FIFO', 'LIFO', 'AVERAGE')),
    unit_of_measure VARCHAR(50) NOT NULL, -- e.g., 'kg', 'ltr', 'pcs'
    cost_price DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (cost_price >= 0),
    reorder_level DECIMAL(12,2) DEFAULT 0 CHECK (reorder_level >= 0),
    status VARCHAR(50) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);
COMMENT ON TABLE public.inventory_items IS 'Physical raw materials or retail products held in inventory.';

CREATE INDEX IF NOT EXISTS idx_inventory_items_tenant_id ON public.inventory_items(tenant_id);
CREATE INDEX IF NOT EXISTS idx_inventory_items_category_id ON public.inventory_items(category_id);
CREATE INDEX IF NOT EXISTS idx_inventory_items_active ON public.inventory_items(tenant_id) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_inventory_items_sku ON public.inventory_items(tenant_id, sku) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_inventory_items_code ON public.inventory_items(tenant_id, item_code) WHERE deleted_at IS NULL AND item_code IS NOT NULL;

CREATE TRIGGER set_inventory_items_updated_at
BEFORE UPDATE ON public.inventory_items
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_inventory_items
AFTER INSERT OR UPDATE OR DELETE ON public.inventory_items
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.inventory_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY inventory_items_isolation_policy ON public.inventory_items
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- 3. INVENTORY TRANSACTIONS (Ledger)
-- ------------------------------------------------------------------------------
-- NOTE: In a future migration, we will add a database trigger to enforce tenant consistency 
-- across warehouse_id, outlet_id, and inventory_item_id to prevent cross-tenant data anomalies.
-- 
-- NOTE: The current stock level for any item at any warehouse is calculated by summing the 
-- quantity_change in this table. In production, we will deploy a materialized view or 
-- a ClickHouse projection (e.g. `vw_stock_snapshots`) to pre-aggregate these sums.
-- 
CREATE TABLE IF NOT EXISTS public.inventory_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    warehouse_id UUID REFERENCES public.warehouses(id) ON DELETE RESTRICT,
    outlet_id UUID REFERENCES public.outlets(id) ON DELETE RESTRICT,
    inventory_item_id UUID NOT NULL REFERENCES public.inventory_items(id) ON DELETE RESTRICT,
    transaction_type VARCHAR(50) NOT NULL CHECK (transaction_type IN ('PURCHASE', 'SALE', 'ADJUSTMENT', 'WASTE', 'TRANSFER_IN', 'TRANSFER_OUT', 'RETURN')),
    quantity_change DECIMAL(12,3) NOT NULL, -- positive or negative
    unit_cost DECIMAL(12,2) NOT NULL CHECK (unit_cost >= 0),
    batch_number VARCHAR(100),
    expiry_date DATE,
    reference_type VARCHAR(100) CHECK (reference_type IN ('ORDER', 'PURCHASE_ORDER', 'TRANSFER', 'MANUAL_ADJUSTMENT')), 
    reference_id UUID, 
    notes TEXT,
    created_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);
COMMENT ON TABLE public.inventory_transactions IS 'Immutable ledger capturing every stock movement. Stock level is the sum of quantity_change.';

CREATE INDEX IF NOT EXISTS idx_inv_tx_tenant_id ON public.inventory_transactions(tenant_id);
CREATE INDEX IF NOT EXISTS idx_inv_tx_item ON public.inventory_transactions(inventory_item_id);
CREATE INDEX IF NOT EXISTS idx_inv_tx_warehouse ON public.inventory_transactions(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_inv_tx_outlet ON public.inventory_transactions(outlet_id);
CREATE INDEX IF NOT EXISTS idx_inv_tx_active ON public.inventory_transactions(tenant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_inventory_transactions_updated_at
BEFORE UPDATE ON public.inventory_transactions
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_inventory_transactions
AFTER INSERT OR UPDATE OR DELETE ON public.inventory_transactions
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.inventory_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY inv_tx_isolation_policy ON public.inventory_transactions
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- 4. WAREHOUSE TRANSFERS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.warehouse_transfers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    source_warehouse_id UUID NOT NULL REFERENCES public.warehouses(id),
    destination_warehouse_id UUID NOT NULL REFERENCES public.warehouses(id),
    status VARCHAR(50) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'IN_TRANSIT', 'COMPLETED', 'CANCELLED')),
    transfer_date TIMESTAMP WITH TIME ZONE,
    created_by UUID REFERENCES public.profiles(id),
    received_by UUID REFERENCES public.profiles(id),
    received_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT chk_warehouse_transfer_diff CHECK (source_warehouse_id != destination_warehouse_id)
);
COMMENT ON TABLE public.warehouse_transfers IS 'Tracks the movement of stock between different warehouse locations.';

CREATE INDEX IF NOT EXISTS idx_wh_transfers_tenant_id ON public.warehouse_transfers(tenant_id);
CREATE INDEX IF NOT EXISTS idx_wh_transfers_active ON public.warehouse_transfers(tenant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_warehouse_transfers_updated_at
BEFORE UPDATE ON public.warehouse_transfers
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_warehouse_transfers
AFTER INSERT OR UPDATE OR DELETE ON public.warehouse_transfers
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.warehouse_transfers ENABLE ROW LEVEL SECURITY;

CREATE POLICY wh_transfers_isolation_policy ON public.warehouse_transfers
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- 5. WAREHOUSE TRANSFER ITEMS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.warehouse_transfer_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    transfer_id UUID NOT NULL REFERENCES public.warehouse_transfers(id) ON DELETE CASCADE,
    inventory_item_id UUID NOT NULL REFERENCES public.inventory_items(id),
    quantity DECIMAL(12,3) NOT NULL CHECK (quantity > 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);
COMMENT ON TABLE public.warehouse_transfer_items IS 'Line items defining the inventory items being transferred.';

CREATE INDEX IF NOT EXISTS idx_wh_transfer_items_tenant_id ON public.warehouse_transfer_items(tenant_id);
CREATE INDEX IF NOT EXISTS idx_wh_transfer_items_transfer ON public.warehouse_transfer_items(transfer_id);
CREATE INDEX IF NOT EXISTS idx_wh_transfer_items_active ON public.warehouse_transfer_items(tenant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_warehouse_transfer_items_updated_at
BEFORE UPDATE ON public.warehouse_transfer_items
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_warehouse_transfer_items
AFTER INSERT OR UPDATE OR DELETE ON public.warehouse_transfer_items
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.warehouse_transfer_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY wh_transfer_items_isolation_policy ON public.warehouse_transfer_items
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- ==============================================================================
-- ROLLBACK INSTRUCTIONS
-- ==============================================================================
/*
DROP POLICY IF EXISTS wh_transfer_items_isolation_policy ON public.warehouse_transfer_items;
DROP POLICY IF EXISTS wh_transfers_isolation_policy ON public.warehouse_transfers;
DROP POLICY IF EXISTS inv_tx_isolation_policy ON public.inventory_transactions;
DROP POLICY IF EXISTS inventory_items_isolation_policy ON public.inventory_items;
DROP POLICY IF EXISTS categories_isolation_policy ON public.categories;

DROP TABLE IF EXISTS public.warehouse_transfer_items CASCADE;
DROP TABLE IF EXISTS public.warehouse_transfers CASCADE;
DROP TABLE IF EXISTS public.inventory_transactions CASCADE;
DROP TABLE IF EXISTS public.inventory_items CASCADE;
DROP TABLE IF EXISTS public.categories CASCADE;
*/



-- ==============================================================================
-- Migration: 00006_restaurant
-- Description: Menu items and recipe management bridging to inventory.
-- ==============================================================================

-- 1. MENU ITEMS
-- ------------------------------------------------------------------------------
-- NOTE: Future migrations will introduce `menu_item_outlets` to handle outlet-specific
-- pricing and availability overrides.
-- NOTE: Future migrations will introduce `menu_item_modifiers` (e.g., Extra Cheese, No Ice)
-- and `combo_items` to handle complex menu composition.
CREATE TABLE IF NOT EXISTS public.menu_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    category_id UUID REFERENCES public.categories(id) ON DELETE SET NULL,
    item_code VARCHAR(100),
    name VARCHAR(255) NOT NULL,
    short_name VARCHAR(100),
    description TEXT,
    menu_type VARCHAR(50) DEFAULT 'FOOD' CHECK (menu_type IN ('FOOD', 'BEVERAGE', 'ALCOHOL', 'RETAIL', 'OTHER')),
    price DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (price >= 0),
    -- NOTE: cost_estimate acts as a cached aggregate based on recipe items and current inventory costs.
    cost_estimate DECIMAL(12,2) DEFAULT 0 CHECK (cost_estimate >= 0),
    tax_category VARCHAR(100), -- E.g., 'STANDARD', 'REDUCED', 'EXEMPT'
    image_url TEXT,
    is_available BOOLEAN DEFAULT true,
    track_inventory BOOLEAN DEFAULT true,
    preparation_station VARCHAR(100), -- E.g., 'KITCHEN_1', 'BAR', 'GRILL'
    preparation_time_minutes INT DEFAULT 0 CHECK (preparation_time_minutes >= 0),
    status VARCHAR(50) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE', 'ARCHIVED')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);
COMMENT ON TABLE public.menu_items IS 'Products available for sale in the POS system.';

CREATE INDEX IF NOT EXISTS idx_menu_items_tenant_id ON public.menu_items(tenant_id);
CREATE INDEX IF NOT EXISTS idx_menu_items_category_id ON public.menu_items(category_id);
CREATE INDEX IF NOT EXISTS idx_menu_items_active ON public.menu_items(tenant_id) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_menu_items_code ON public.menu_items(tenant_id, item_code) WHERE deleted_at IS NULL AND item_code IS NOT NULL;

CREATE TRIGGER set_menu_items_updated_at
BEFORE UPDATE ON public.menu_items
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_menu_items
AFTER INSERT OR UPDATE OR DELETE ON public.menu_items
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.menu_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY menu_items_isolation_policy ON public.menu_items
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- 2. RECIPES
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.recipes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    menu_item_id UUID NOT NULL REFERENCES public.menu_items(id) ON DELETE CASCADE,
    name VARCHAR(255),
    instructions TEXT,
    yield_quantity DECIMAL(12,3) DEFAULT 1 CHECK (yield_quantity > 0),
    version_no INT DEFAULT 1 CHECK (version_no >= 1),
    status VARCHAR(50) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(tenant_id, menu_item_id, version_no)
);
COMMENT ON TABLE public.recipes IS 'Formulas connecting a menu item to its underlying inventory components.';

CREATE INDEX IF NOT EXISTS idx_recipes_tenant_id ON public.recipes(tenant_id);
CREATE INDEX IF NOT EXISTS idx_recipes_menu_item_id ON public.recipes(menu_item_id);
CREATE INDEX IF NOT EXISTS idx_recipes_active ON public.recipes(tenant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_recipes_updated_at
BEFORE UPDATE ON public.recipes
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_recipes
AFTER INSERT OR UPDATE OR DELETE ON public.recipes
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.recipes ENABLE ROW LEVEL SECURITY;

CREATE POLICY recipes_isolation_policy ON public.recipes
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- 3. RECIPE ITEMS (BOM)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.recipe_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    recipe_id UUID NOT NULL REFERENCES public.recipes(id) ON DELETE CASCADE,
    inventory_item_id UUID NOT NULL REFERENCES public.inventory_items(id) ON DELETE RESTRICT,
    quantity DECIMAL(12,3) NOT NULL CHECK (quantity > 0),
    unit_of_measure VARCHAR(50) NOT NULL,
    is_optional BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(tenant_id, recipe_id, inventory_item_id)
);
COMMENT ON TABLE public.recipe_items IS 'Line items representing raw materials required for a recipe (Bill of Materials).';

CREATE INDEX IF NOT EXISTS idx_recipe_items_tenant_id ON public.recipe_items(tenant_id);
CREATE INDEX IF NOT EXISTS idx_recipe_items_recipe ON public.recipe_items(recipe_id);
CREATE INDEX IF NOT EXISTS idx_recipe_items_inventory ON public.recipe_items(inventory_item_id);
CREATE INDEX IF NOT EXISTS idx_recipe_items_active ON public.recipe_items(tenant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_recipe_items_updated_at
BEFORE UPDATE ON public.recipe_items
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_recipe_items
AFTER INSERT OR UPDATE OR DELETE ON public.recipe_items
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.recipe_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY recipe_items_isolation_policy ON public.recipe_items
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- ==============================================================================
-- ROLLBACK INSTRUCTIONS
-- ==============================================================================
/*
DROP POLICY IF EXISTS recipe_items_isolation_policy ON public.recipe_items;
DROP POLICY IF EXISTS recipes_isolation_policy ON public.recipes;
DROP POLICY IF EXISTS menu_items_isolation_policy ON public.menu_items;

DROP TABLE IF EXISTS public.recipe_items CASCADE;
DROP TABLE IF EXISTS public.recipes CASCADE;
DROP TABLE IF EXISTS public.menu_items CASCADE;
*/
-- ==============================================================================
-- Migration: 00007_pos
-- Description: Core Point of Sale tables (Orders, Order Items, Payments).
-- ==============================================================================

-- 1. ORDERS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
    parent_order_id UUID REFERENCES public.orders(id) ON DELETE SET NULL, -- For split bills
    customer_id UUID REFERENCES public.customers(id) ON DELETE SET NULL,
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL, -- Cashier or Server
    cash_register_id UUID, -- References a future cash_registers table
    order_number VARCHAR(100) NOT NULL,
    external_order_id VARCHAR(100), -- E.g., Aggregator ID (Swiggy/Zomato)
    order_type VARCHAR(50) NOT NULL DEFAULT 'DINE_IN' CHECK (order_type IN ('DINE_IN', 'TAKEAWAY', 'DELIVERY', 'ONLINE', 'CATERING')),
    order_source VARCHAR(50) NOT NULL DEFAULT 'POS' CHECK (order_source IN ('POS', 'KIOSK', 'WEB', 'APP', 'AGGREGATOR')),
    table_number VARCHAR(50), -- Only relevant for DINE_IN
    guest_count INT DEFAULT 1 CHECK (guest_count >= 1),
    status VARCHAR(50) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'ACCEPTED', 'PREPARING', 'READY', 'COMPLETED', 'CANCELLED', 'REFUNDED')),
    payment_status VARCHAR(50) NOT NULL DEFAULT 'UNPAID' CHECK (payment_status IN ('UNPAID', 'PARTIAL', 'PAID', 'REFUNDED')),
    subtotal DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (subtotal >= 0),
    tax_total DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (tax_total >= 0),
    discount_total DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (discount_total >= 0),
    -- NOTE: grand_total is the final authoritative monetary value for the order.
    grand_total DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (grand_total >= 0),
    tax_breakdown JSONB,
    inventory_processed BOOLEAN DEFAULT false,
    cancel_reason TEXT,
    void_reason TEXT,
    notes TEXT,
    -- Lifecycle timestamps
    accepted_at TIMESTAMP WITH TIME ZONE,
    preparing_at TIMESTAMP WITH TIME ZONE,
    ready_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(tenant_id, outlet_id, order_number)
);
COMMENT ON TABLE public.orders IS 'Master transaction record for a POS sale. grand_total is the authoritative value.';

CREATE INDEX IF NOT EXISTS idx_orders_tenant_id ON public.orders(tenant_id);
CREATE INDEX IF NOT EXISTS idx_orders_outlet_id ON public.orders(outlet_id);
CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON public.orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_parent_id ON public.orders(parent_order_id);
CREATE INDEX IF NOT EXISTS idx_orders_active ON public.orders(tenant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_orders_updated_at
BEFORE UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_orders
AFTER INSERT OR UPDATE OR DELETE ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY orders_isolation_policy ON public.orders
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- 2. ORDER ITEMS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    menu_item_id UUID NOT NULL REFERENCES public.menu_items(id) ON DELETE RESTRICT,
    preparation_station VARCHAR(100), -- Copied from menu_item for KDS routing
    quantity DECIMAL(10,2) NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(12,2) NOT NULL CHECK (unit_price >= 0),
    subtotal DECIMAL(12,2) NOT NULL CHECK (subtotal >= 0),
    tax_amount DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (tax_amount >= 0),
    discount_amount DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
    total_price DECIMAL(12,2) NOT NULL CHECK (total_price >= 0),
    status VARCHAR(50) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PREPARING', 'READY', 'SERVED', 'CANCELLED', 'RETURNED')),
    void_reason TEXT,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);
COMMENT ON TABLE public.order_items IS 'Line items belonging to a specific order.';

CREATE INDEX IF NOT EXISTS idx_order_items_tenant_id ON public.order_items(tenant_id);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON public.order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_active ON public.order_items(tenant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_order_items_updated_at
BEFORE UPDATE ON public.order_items
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_order_items
AFTER INSERT OR UPDATE OR DELETE ON public.order_items
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY order_items_isolation_policy ON public.order_items
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- 3. PAYMENTS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES public.customers(id) ON DELETE SET NULL,
    cash_register_id UUID,
    amount DECIMAL(12,2) NOT NULL CHECK (amount > 0),
    payment_method VARCHAR(50) NOT NULL CHECK (payment_method IN ('CASH', 'CREDIT_CARD', 'DEBIT_CARD', 'UPI', 'WALLET', 'GIFT_CARD', 'LOYALTY_POINTS', 'OTHER')),
    status VARCHAR(50) NOT NULL DEFAULT 'COMPLETED' CHECK (status IN ('PENDING', 'COMPLETED', 'FAILED', 'REFUNDED')),
    gateway_name VARCHAR(100),
    transaction_reference VARCHAR(255), -- External gateway reference
    gateway_response JSONB,
    payment_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);
COMMENT ON TABLE public.payments IS 'Customer payments applied to orders.';

CREATE INDEX IF NOT EXISTS idx_payments_tenant_id ON public.payments(tenant_id);
CREATE INDEX IF NOT EXISTS idx_payments_outlet_id ON public.payments(outlet_id);
CREATE INDEX IF NOT EXISTS idx_payments_order_id ON public.payments(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_active ON public.payments(tenant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_payments_updated_at
BEFORE UPDATE ON public.payments
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_payments
AFTER INSERT OR UPDATE OR DELETE ON public.payments
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY payments_isolation_policy ON public.payments
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- ==============================================================================
-- ROLLBACK INSTRUCTIONS
-- ==============================================================================
/*
DROP POLICY IF EXISTS payments_isolation_policy ON public.payments;
DROP POLICY IF EXISTS order_items_isolation_policy ON public.order_items;
DROP POLICY IF EXISTS orders_isolation_policy ON public.orders;

DROP TABLE IF EXISTS public.payments CASCADE;
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
*/
-- ==============================================================================
-- Migration: 00008_hrms
-- Description: Human Resource Management System (Employees, Attendance).
-- ==============================================================================

-- 1. EMPLOYEES
-- ------------------------------------------------------------------------------
-- NOTE: Future migrations may introduce `employee_outlet_history` to track
-- reassignments across multiple outlets over time.
CREATE TABLE IF NOT EXISTS public.employees (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    outlet_id UUID REFERENCES public.outlets(id) ON DELETE SET NULL,
    profile_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL, -- Mapping to auth/login if they have system access
    manager_employee_id UUID REFERENCES public.employees(id) ON DELETE SET NULL,
    employee_code VARCHAR(100),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    full_name VARCHAR(255) GENERATED ALWAYS AS (
        TRIM(COALESCE(first_name, '') || ' ' || COALESCE(last_name, ''))
    ) STORED,
    email VARCHAR(255),
    phone VARCHAR(50),
    designation VARCHAR(100),
    department VARCHAR(100),
    cost_center VARCHAR(100),
    employment_type VARCHAR(50) DEFAULT 'FULL_TIME' CHECK (employment_type IN ('FULL_TIME', 'PART_TIME', 'CONTRACT', 'SEASONAL')),
    status VARCHAR(50) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'ON_LEAVE', 'SUSPENDED', 'TERMINATED')),
    hire_date DATE,
    probation_end_date DATE,
    termination_date DATE,
    hourly_rate DECIMAL(10,2) DEFAULT 0 CHECK (hourly_rate >= 0),
    monthly_salary DECIMAL(12,2) DEFAULT 0 CHECK (monthly_salary >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(tenant_id, profile_id),
    CONSTRAINT chk_term_date CHECK (termination_date IS NULL OR termination_date >= hire_date)
);
COMMENT ON TABLE public.employees IS 'Core HR table tracking staff details and employment status.';

CREATE INDEX IF NOT EXISTS idx_employees_tenant_id ON public.employees(tenant_id);
CREATE INDEX IF NOT EXISTS idx_employees_outlet_id ON public.employees(outlet_id);
CREATE INDEX IF NOT EXISTS idx_employees_manager_id ON public.employees(manager_employee_id);
CREATE INDEX IF NOT EXISTS idx_employees_active ON public.employees(tenant_id) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_employees_code ON public.employees(tenant_id, employee_code) WHERE deleted_at IS NULL AND employee_code IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_employees_email ON public.employees(tenant_id, email) WHERE deleted_at IS NULL AND email IS NOT NULL;

CREATE TRIGGER set_employees_updated_at
BEFORE UPDATE ON public.employees
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_employees
AFTER INSERT OR UPDATE OR DELETE ON public.employees
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;

CREATE POLICY employees_isolation_policy ON public.employees
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- 2. ATTENDANCE
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    outlet_id UUID REFERENCES public.outlets(id) ON DELETE SET NULL,
    employee_id UUID NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
    shift_date DATE NOT NULL,
    shift_name VARCHAR(100), -- E.g., 'MORNING', 'EVENING', 'NIGHT'
    clock_in_time TIMESTAMP WITH TIME ZONE,
    clock_out_time TIMESTAMP WITH TIME ZONE,
    -- NOTE: total_hours acts as a cached calculation (clock_out - clock_in) to speed up payroll queries.
    total_hours DECIMAL(5,2) DEFAULT 0 CHECK (total_hours >= 0),
    attendance_source VARCHAR(50) DEFAULT 'POS' CHECK (attendance_source IN ('POS', 'WEB', 'APP', 'BIOMETRIC', 'MANUAL')),
    status VARCHAR(50) DEFAULT 'PRESENT' CHECK (status IN ('PRESENT', 'ABSENT', 'LATE', 'HALF_DAY', 'ON_LEAVE', 'HOLIDAY')),
    approved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    approved_at TIMESTAMP WITH TIME ZONE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT chk_clock_times CHECK (clock_out_time IS NULL OR clock_out_time >= clock_in_time)
);
COMMENT ON TABLE public.attendance IS 'Daily time-tracking and attendance logs for employees.';

CREATE INDEX IF NOT EXISTS idx_attendance_tenant_id ON public.attendance(tenant_id);
CREATE INDEX IF NOT EXISTS idx_attendance_employee ON public.attendance(employee_id);
CREATE INDEX IF NOT EXISTS idx_attendance_date ON public.attendance(tenant_id, shift_date);
CREATE INDEX IF NOT EXISTS idx_attendance_active ON public.attendance(tenant_id) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_attendance_unique_shift ON public.attendance(tenant_id, employee_id, shift_date) WHERE deleted_at IS NULL;

CREATE TRIGGER set_attendance_updated_at
BEFORE UPDATE ON public.attendance
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_attendance
AFTER INSERT OR UPDATE OR DELETE ON public.attendance
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;

CREATE POLICY attendance_isolation_policy ON public.attendance
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- ==============================================================================
-- ROLLBACK INSTRUCTIONS
-- ==============================================================================
/*
DROP POLICY IF EXISTS attendance_isolation_policy ON public.attendance;
DROP POLICY IF EXISTS employees_isolation_policy ON public.employees;

DROP TABLE IF EXISTS public.attendance CASCADE;
DROP TABLE IF EXISTS public.employees CASCADE;
*/
-- ==============================================================================
-- Migration: 00009_erp
-- Description: Enterprise Resource Planning (Suppliers, Purchase Orders).
-- ==============================================================================

-- 1. SUPPLIERS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.suppliers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    supplier_code VARCHAR(100),
    name VARCHAR(255) NOT NULL,
    contact_name VARCHAR(255),
    email VARCHAR(255),
    phone VARCHAR(50),
    address TEXT,
    tax_id VARCHAR(100),
    payment_terms VARCHAR(100) DEFAULT 'NET_30' CHECK (payment_terms IN ('IMMEDIATE', 'NET_15', 'NET_30', 'NET_45', 'NET_60', 'NET_90', 'CASH_ON_DELIVERY')),
    credit_limit DECIMAL(15,2) DEFAULT 0 CHECK (credit_limit >= 0),
    supplier_rating DECIMAL(3,2) CHECK (supplier_rating >= 0 AND supplier_rating <= 5.0),
    status VARCHAR(50) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);
COMMENT ON TABLE public.suppliers IS 'Vendor/Supplier records for procurement and B2B relations.';

CREATE INDEX IF NOT EXISTS idx_suppliers_tenant_id ON public.suppliers(tenant_id);
CREATE INDEX IF NOT EXISTS idx_suppliers_active ON public.suppliers(tenant_id) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_suppliers_code ON public.suppliers(tenant_id, supplier_code) WHERE deleted_at IS NULL AND supplier_code IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_suppliers_email ON public.suppliers(tenant_id, email) WHERE deleted_at IS NULL AND email IS NOT NULL;

CREATE TRIGGER set_suppliers_updated_at
BEFORE UPDATE ON public.suppliers
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_suppliers
AFTER INSERT OR UPDATE OR DELETE ON public.suppliers
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;

CREATE POLICY suppliers_isolation_policy ON public.suppliers
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- 2. PURCHASE ORDERS (PO)
-- ------------------------------------------------------------------------------
-- NOTE: Future migrations will introduce `grn` (Goods Receipt Note) and `grn_items` tables 
-- to explicitly handle the receiving process and decouple it from the PO definition.
CREATE TABLE IF NOT EXISTS public.purchase_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    outlet_id UUID REFERENCES public.outlets(id) ON DELETE SET NULL,
    warehouse_id UUID REFERENCES public.warehouses(id) ON DELETE SET NULL,
    supplier_id UUID NOT NULL REFERENCES public.suppliers(id) ON DELETE RESTRICT,
    po_number VARCHAR(100) NOT NULL,
    supplier_invoice_number VARCHAR(100),
    supplier_invoice_date DATE,
    order_date DATE NOT NULL DEFAULT CURRENT_DATE,
    expected_delivery_date DATE,
    status VARCHAR(50) NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'ISSUED', 'CANCELLED', 'CLOSED')),
    receiving_status VARCHAR(50) NOT NULL DEFAULT 'PENDING' CHECK (receiving_status IN ('PENDING', 'PARTIAL', 'COMPLETED')),
    currency VARCHAR(10) DEFAULT 'INR' CHECK (currency IN ('INR', 'USD', 'EUR', 'GBP')),
    subtotal DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (subtotal >= 0),
    tax_total DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (tax_total >= 0),
    discount_total DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (discount_total >= 0),
    grand_total DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (grand_total >= 0),
    tax_breakdown JSONB,
    inventory_processed BOOLEAN DEFAULT false,
    notes TEXT,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    approved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    approved_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(tenant_id, po_number),
    CONSTRAINT chk_po_dates CHECK (expected_delivery_date IS NULL OR expected_delivery_date >= order_date)
);
COMMENT ON TABLE public.purchase_orders IS 'Master records for procurement orders issued to suppliers.';

CREATE INDEX IF NOT EXISTS idx_purchase_orders_tenant_id ON public.purchase_orders(tenant_id);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_supplier_id ON public.purchase_orders(supplier_id);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_warehouse_id ON public.purchase_orders(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_active ON public.purchase_orders(tenant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_purchase_orders_updated_at
BEFORE UPDATE ON public.purchase_orders
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_purchase_orders
AFTER INSERT OR UPDATE OR DELETE ON public.purchase_orders
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.purchase_orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY purchase_orders_isolation_policy ON public.purchase_orders
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- 3. PO ITEMS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.po_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    po_id UUID NOT NULL REFERENCES public.purchase_orders(id) ON DELETE CASCADE,
    inventory_item_id UUID NOT NULL REFERENCES public.inventory_items(id) ON DELETE RESTRICT,
    unit_of_measure VARCHAR(50) NOT NULL, -- Snapshot at time of order
    quantity_ordered DECIMAL(12,3) NOT NULL CHECK (quantity_ordered > 0),
    quantity_received DECIMAL(12,3) NOT NULL DEFAULT 0 CHECK (quantity_received >= 0),
    unit_cost DECIMAL(12,2) NOT NULL CHECK (unit_cost >= 0),
    subtotal DECIMAL(12,2) NOT NULL CHECK (subtotal >= 0),
    tax_amount DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (tax_amount >= 0),
    total_price DECIMAL(12,2) NOT NULL CHECK (total_price >= 0),
    status VARCHAR(50) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PARTIAL', 'RECEIVED', 'CANCELLED')),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT chk_qty_received CHECK (quantity_received <= quantity_ordered)
);
COMMENT ON TABLE public.po_items IS 'Line items belonging to a specific purchase order.';

CREATE INDEX IF NOT EXISTS idx_po_items_tenant_id ON public.po_items(tenant_id);
CREATE INDEX IF NOT EXISTS idx_po_items_po_id ON public.po_items(po_id);
CREATE INDEX IF NOT EXISTS idx_po_items_item_id ON public.po_items(inventory_item_id);
CREATE INDEX IF NOT EXISTS idx_po_items_active ON public.po_items(tenant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_po_items_updated_at
BEFORE UPDATE ON public.po_items
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_po_items
AFTER INSERT OR UPDATE OR DELETE ON public.po_items
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.po_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY po_items_isolation_policy ON public.po_items
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- ==============================================================================
-- ROLLBACK INSTRUCTIONS
-- ==============================================================================
/*
DROP POLICY IF EXISTS po_items_isolation_policy ON public.po_items;
DROP POLICY IF EXISTS purchase_orders_isolation_policy ON public.purchase_orders;
DROP POLICY IF EXISTS suppliers_isolation_policy ON public.suppliers;

DROP TABLE IF EXISTS public.po_items CASCADE;
DROP TABLE IF EXISTS public.purchase_orders CASCADE;
DROP TABLE IF EXISTS public.suppliers CASCADE;
*/
-- ==============================================================================
-- Migration: 00010_accounting
-- Description: Chart of Accounts and Double-Entry General Ledger.
-- ==============================================================================

-- NOTE: Future migrations will introduce `accounting_periods` to handle 
-- fiscal years, period closures, and retained earnings roll-forward.

-- 1. ACCOUNTS (Chart of Accounts)
-- ------------------------------------------------------------------------------
-- NOTE: Application initialization should seed system accounts (e.g., Accounts Receivable, 
-- Accounts Payable, Sales Tax, Retained Earnings) and mark them with `is_system_account = true`.
CREATE TABLE IF NOT EXISTS public.accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    parent_id UUID REFERENCES public.accounts(id) ON DELETE SET NULL,
    account_code VARCHAR(100) NOT NULL,
    name VARCHAR(255) NOT NULL,
    account_type VARCHAR(50) NOT NULL CHECK (account_type IN ('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE')),
    normal_balance VARCHAR(50) NOT NULL CHECK (normal_balance IN ('DEBIT', 'CREDIT')),
    is_system_account BOOLEAN DEFAULT false,
    is_tax_account BOOLEAN DEFAULT false,
    description TEXT,
    status VARCHAR(50) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(tenant_id, account_code)
);
COMMENT ON TABLE public.accounts IS 'Standard Chart of Accounts (COA) for double-entry bookkeeping.';

CREATE INDEX IF NOT EXISTS idx_accounts_tenant_id ON public.accounts(tenant_id);
CREATE INDEX IF NOT EXISTS idx_accounts_parent_id ON public.accounts(parent_id);
CREATE INDEX IF NOT EXISTS idx_accounts_active ON public.accounts(tenant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_accounts_updated_at
BEFORE UPDATE ON public.accounts
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_accounts
AFTER INSERT OR UPDATE OR DELETE ON public.accounts
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;

CREATE POLICY accounts_isolation_policy ON public.accounts
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- 2. JOURNAL ENTRIES
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.journal_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    outlet_id UUID REFERENCES public.outlets(id) ON DELETE SET NULL, -- Optional context
    reversal_entry_id UUID REFERENCES public.journal_entries(id) ON DELETE SET NULL,
    entry_number VARCHAR(100) NOT NULL,
    entry_date DATE NOT NULL DEFAULT CURRENT_DATE,
    description TEXT,
    source_module VARCHAR(50) NOT NULL CHECK (source_module IN ('POS', 'INVENTORY', 'PROCUREMENT', 'PAYROLL', 'MANUAL', 'SYSTEM')),
    reference_type VARCHAR(100) CHECK (reference_type IN ('ORDER', 'PURCHASE_ORDER', 'PAYMENT', 'PAYROLL', 'INVENTORY_ADJUSTMENT', 'MANUAL')),
    reference_id UUID,
    currency VARCHAR(10) DEFAULT 'INR',
    status VARCHAR(50) NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'POSTED', 'VOIDED')),
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    posted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    posted_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(tenant_id, entry_number)
);
COMMENT ON TABLE public.journal_entries IS 'Header records for all accounting journal transactions.';

CREATE INDEX IF NOT EXISTS idx_journal_entries_tenant_id ON public.journal_entries(tenant_id);
CREATE INDEX IF NOT EXISTS idx_journal_entries_date ON public.journal_entries(tenant_id, entry_date);
CREATE INDEX IF NOT EXISTS idx_journal_entries_active ON public.journal_entries(tenant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_journal_entries_updated_at
BEFORE UPDATE ON public.journal_entries
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_journal_entries
AFTER INSERT OR UPDATE OR DELETE ON public.journal_entries
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.journal_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY journal_entries_isolation_policy ON public.journal_entries
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- 3. JOURNAL LINES
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.journal_lines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    journal_entry_id UUID NOT NULL REFERENCES public.journal_entries(id) ON DELETE CASCADE,
    account_id UUID NOT NULL REFERENCES public.accounts(id) ON DELETE RESTRICT,
    line_number INT NOT NULL CHECK (line_number > 0),
    cost_center VARCHAR(100),
    debit DECIMAL(14,2) NOT NULL DEFAULT 0 CHECK (debit >= 0),
    credit DECIMAL(14,2) NOT NULL DEFAULT 0 CHECK (credit >= 0),
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT chk_debit_credit_mutex CHECK (
        (debit > 0 AND credit = 0) OR (credit > 0 AND debit = 0) OR (debit = 0 AND credit = 0)
    ),
    UNIQUE(tenant_id, journal_entry_id, line_number)
);
COMMENT ON TABLE public.journal_lines IS 'Individual debit/credit lines.';

CREATE INDEX IF NOT EXISTS idx_journal_lines_tenant_id ON public.journal_lines(tenant_id);
CREATE INDEX IF NOT EXISTS idx_journal_lines_entry_id ON public.journal_lines(journal_entry_id);
CREATE INDEX IF NOT EXISTS idx_journal_lines_account_id ON public.journal_lines(account_id);
CREATE INDEX IF NOT EXISTS idx_journal_lines_active ON public.journal_lines(tenant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_journal_lines_updated_at
BEFORE UPDATE ON public.journal_lines
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_journal_lines
AFTER INSERT OR UPDATE OR DELETE ON public.journal_lines
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.journal_lines ENABLE ROW LEVEL SECURITY;

CREATE POLICY journal_lines_isolation_policy ON public.journal_lines
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- 4. ACCOUNTING TRIGGERS (IMMUTABILITY AND BALANCING)
-- ------------------------------------------------------------------------------
-- A. Prevent modification of posted entries
CREATE OR REPLACE FUNCTION public.prevent_posted_modification()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status = 'POSTED' THEN
        -- Allow updates only to transition to VOIDED or setting reversal_entry_id
        IF NEW.status = 'VOIDED' OR NEW.reversal_entry_id IS NOT NULL THEN
            RETURN NEW;
        END IF;
        RAISE EXCEPTION 'Cannot modify a POSTED journal entry';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_posted_modification
BEFORE UPDATE ON public.journal_entries
FOR EACH ROW EXECUTE FUNCTION public.prevent_posted_modification();

-- B. Validate double-entry balance on POST
CREATE OR REPLACE FUNCTION public.validate_journal_balance()
RETURNS TRIGGER AS $$
DECLARE
    total_debits DECIMAL(14,2);
    total_credits DECIMAL(14,2);
BEGIN
    IF NEW.status = 'POSTED' THEN
        SELECT COALESCE(SUM(debit), 0), COALESCE(SUM(credit), 0)
        INTO total_debits, total_credits
        FROM public.journal_lines
        WHERE journal_entry_id = NEW.id AND deleted_at IS NULL;

        IF total_debits != total_credits THEN
            RAISE EXCEPTION 'Journal entry does not balance. Debits: %, Credits: %', total_debits, total_credits;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_journal_balance
BEFORE UPDATE OF status ON public.journal_entries
FOR EACH ROW
WHEN (NEW.status = 'POSTED' AND (OLD.status IS DISTINCT FROM NEW.status))
EXECUTE FUNCTION public.validate_journal_balance();


-- ==============================================================================
-- ROLLBACK INSTRUCTIONS
-- ==============================================================================
/*
DROP TRIGGER IF EXISTS trg_validate_journal_balance ON public.journal_entries;
DROP FUNCTION IF EXISTS public.validate_journal_balance();
DROP TRIGGER IF EXISTS trg_prevent_posted_modification ON public.journal_entries;
DROP FUNCTION IF EXISTS public.prevent_posted_modification();

DROP POLICY IF EXISTS journal_lines_isolation_policy ON public.journal_lines;
DROP POLICY IF EXISTS journal_entries_isolation_policy ON public.journal_entries;
DROP POLICY IF EXISTS accounts_isolation_policy ON public.accounts;

DROP TABLE IF EXISTS public.journal_lines CASCADE;
DROP TABLE IF EXISTS public.journal_entries CASCADE;
DROP TABLE IF EXISTS public.accounts CASCADE;
*/
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
-- ==============================================================================
-- Migration: 00013_analytics
-- Description: Dashboards, Reports, and Aggregated Metrics.
-- ==============================================================================

-- NOTE: In the future, as data volume grows, we will likely migrate these analytics 
-- tables and views to a dedicated OLAP database like ClickHouse to offload 
-- heavy aggregation workloads from PostgreSQL.

-- NOTE: Future migrations will introduce `analytics_events` to capture 
-- granular user and system telemetry events.

-- 1. DAILY SALES AGGREGATES
-- ------------------------------------------------------------------------------
-- NOTE: Populated by a nightly CRON job or pg_cron to prevent real-time analytical queries 
-- from impacting POS transaction performance.
-- NOTE: Future migrations will introduce `daily_inventory_aggregates` for stock trending.
-- NOTE: Future migrations will introduce daily profitability metrics (combining COGS and OPEX).
CREATE TABLE IF NOT EXISTS public.daily_sales_aggregates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    outlet_id UUID REFERENCES public.outlets(id) ON DELETE CASCADE,
    report_date DATE NOT NULL,
    total_orders INT NOT NULL DEFAULT 0 CHECK (total_orders >= 0),
    total_sales DECIMAL(15,2) NOT NULL DEFAULT 0 CHECK (total_sales >= 0),
    total_tax DECIMAL(15,2) NOT NULL DEFAULT 0 CHECK (total_tax >= 0),
    total_discount DECIMAL(15,2) NOT NULL DEFAULT 0 CHECK (total_discount >= 0),
    guest_count INT NOT NULL DEFAULT 0 CHECK (guest_count >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(tenant_id, outlet_id, report_date)
);
COMMENT ON TABLE public.daily_sales_aggregates IS 'Pre-calculated daily sales metrics to power fast dashboard rendering.';

CREATE INDEX IF NOT EXISTS idx_sales_agg_tenant_id ON public.daily_sales_aggregates(tenant_id);
CREATE INDEX IF NOT EXISTS idx_sales_agg_outlet_id ON public.daily_sales_aggregates(outlet_id);
CREATE INDEX IF NOT EXISTS idx_sales_agg_date ON public.daily_sales_aggregates(tenant_id, report_date);
CREATE INDEX IF NOT EXISTS idx_sales_agg_active ON public.daily_sales_aggregates(tenant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_sales_agg_updated_at
BEFORE UPDATE ON public.daily_sales_aggregates
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Aggregates don't typically need heavy auditing, but to maintain the 15-point rule:
CREATE TRIGGER audit_daily_sales_aggregates
AFTER INSERT OR UPDATE OR DELETE ON public.daily_sales_aggregates
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.daily_sales_aggregates ENABLE ROW LEVEL SECURITY;

CREATE POLICY sales_aggregates_isolation_policy ON public.daily_sales_aggregates
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- 2. REPORTS CONFIGURATION
-- ------------------------------------------------------------------------------
-- NOTE: Future migrations will introduce `report_executions` to track when reports 
-- are run and cache their heavy computational results.
-- NOTE: Future support will be added for diverse export formats (e.g. PDF, CSV, EXCEL) 
-- defined within the report configuration.
CREATE TABLE IF NOT EXISTS public.reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    report_type VARCHAR(50) NOT NULL CHECK (report_type IN ('SALES', 'INVENTORY', 'FINANCE', 'HR', 'CUSTOM')),
    query_configuration JSONB NOT NULL, -- The structure or identifiers of what to query
    schedule_cron VARCHAR(100), -- E.g., '0 0 * * *' for daily
    status VARCHAR(50) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE', 'ARCHIVED')),
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);
COMMENT ON TABLE public.reports IS 'Configurations and schedules for custom tenant reports.';

CREATE INDEX IF NOT EXISTS idx_reports_tenant_id ON public.reports(tenant_id);
CREATE INDEX IF NOT EXISTS idx_reports_active ON public.reports(tenant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_reports_updated_at
BEFORE UPDATE ON public.reports
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_reports
AFTER INSERT OR UPDATE OR DELETE ON public.reports
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY reports_isolation_policy ON public.reports
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- 3. DASHBOARDS
-- ------------------------------------------------------------------------------
-- NOTE: Future migrations will extract `dashboard_widgets` into a separate table 
-- to allow fine-grained widget reusability across multiple dashboards.
-- NOTE: Future updates will introduce dashboard scope support (e.g., GLOBAL, OUTLET-SPECIFIC, USER-SPECIFIC).
CREATE TABLE IF NOT EXISTS public.dashboards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    layout JSONB NOT NULL, -- Grid layouts, widget configurations
    is_default BOOLEAN DEFAULT false,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);
COMMENT ON TABLE public.dashboards IS 'User or tenant-specific analytical dashboard layouts.';

CREATE INDEX IF NOT EXISTS idx_dashboards_tenant_id ON public.dashboards(tenant_id);
CREATE INDEX IF NOT EXISTS idx_dashboards_active ON public.dashboards(tenant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_dashboards_updated_at
BEFORE UPDATE ON public.dashboards
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_dashboards
AFTER INSERT OR UPDATE OR DELETE ON public.dashboards
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.dashboards ENABLE ROW LEVEL SECURITY;

CREATE POLICY dashboards_isolation_policy ON public.dashboards
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- ==============================================================================
-- ROLLBACK INSTRUCTIONS
-- ==============================================================================
/*
DROP POLICY IF EXISTS dashboards_isolation_policy ON public.dashboards;
DROP POLICY IF EXISTS reports_isolation_policy ON public.reports;
DROP POLICY IF EXISTS sales_aggregates_isolation_policy ON public.daily_sales_aggregates;

DROP TABLE IF EXISTS public.dashboards CASCADE;
DROP TABLE IF EXISTS public.reports CASCADE;
DROP TABLE IF EXISTS public.daily_sales_aggregates CASCADE;
*/
-- ==============================================================================
-- Migration: 00014_auth_hooks
-- Description: Supabase Auth Hooks for Auto-creating Tenants and Seed Roles
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS TRIGGER AS $$
DECLARE
    target_tenant_id UUID;
    target_outlet_id UUID;
    owner_role_id UUID;
BEGIN
    -- If the user was invited to an existing tenant (via metadata)
    IF NEW.raw_user_meta_data->>'tenant_id' IS NOT NULL THEN
        target_tenant_id := (NEW.raw_user_meta_data->>'tenant_id')::UUID;
        
        -- Get the oldest/main outlet for this tenant
        SELECT id INTO target_outlet_id FROM public.outlets WHERE tenant_id = target_tenant_id ORDER BY created_at ASC LIMIT 1;
        
        -- Create the Profile linked to the existing tenant
        INSERT INTO public.profiles (id, tenant_id, outlet_id, status)
        VALUES (NEW.id, target_tenant_id, target_outlet_id, 'ACTIVE');

    ELSE
        -- 1. Create a new Tenant (Self-serve Registration)
        INSERT INTO public.tenants (name)
        VALUES (COALESCE(NEW.raw_user_meta_data->>'tenant_name', 'My Business'))
        RETURNING id INTO target_tenant_id;

        -- 2. Create a default Outlet
        INSERT INTO public.outlets (tenant_id, name)
        VALUES (target_tenant_id, 'Main Outlet')
        RETURNING id INTO target_outlet_id;

        -- 3. Create the Profile
        INSERT INTO public.profiles (id, tenant_id, outlet_id, status)
        VALUES (NEW.id, target_tenant_id, target_outlet_id, 'ACTIVE');

        -- 4. Seed system roles for the newly created tenant
        INSERT INTO public.roles (tenant_id, name, description) VALUES 
            (target_tenant_id, 'OWNER', 'Full access'),
            (target_tenant_id, 'ADMIN', 'Administrative access'),
            (target_tenant_id, 'MANAGER', 'Store manager'),
            (target_tenant_id, 'CASHIER', 'Cashier');

        -- Retrieve the newly created OWNER role
        SELECT id INTO owner_role_id FROM public.roles WHERE tenant_id = target_tenant_id AND name = 'OWNER' LIMIT 1;

        -- 5. Assign the OWNER role to the foundational user
        INSERT INTO public.user_roles (user_id, role_id, outlet_id)
        VALUES (NEW.id, owner_role_id, target_outlet_id);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop trigger if it exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Create the trigger
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
-- ==============================================================================
-- Migration: 00015_pos_events
-- Description: Core Event-Sourcing Ledger for POS Orders
-- ==============================================================================

-- Order Events Table (Append-Only Ledger)
CREATE TABLE public.order_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    outlet_id UUID NOT NULL,
    order_id UUID NOT NULL, -- Ties events to a specific logical order
    event_type VARCHAR(100) NOT NULL, -- e.g., ORDER_CREATED, ITEM_ADDED, PAYMENT_CAPTURED, ORDER_VOIDED
    payload JSONB NOT NULL DEFAULT '{}'::jsonb, -- The serialized event data
    device_identifier VARCHAR(255), -- Tracks which physical device generated the event
    created_by UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    FOREIGN KEY (tenant_id) REFERENCES public.tenants(id),
    FOREIGN KEY (outlet_id) REFERENCES public.outlets(id)
);

-- RLS Policies
ALTER TABLE public.order_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY order_events_isolation_policy ON public.order_events
    FOR ALL USING (tenant_id = public.get_current_tenant_id());

-- Indexes for event reconstruction and syncing
CREATE INDEX idx_order_events_tenant ON public.order_events(tenant_id);
CREATE INDEX idx_order_events_order_id ON public.order_events(order_id);
CREATE INDEX idx_order_events_created_at ON public.order_events(created_at);

-- Trigger to prevent UPDATE or DELETE on the append-only ledger
CREATE OR REPLACE FUNCTION public.prevent_event_modification()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Order events are immutable. Updates and Deletes are forbidden.';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_order_events_mutation
    BEFORE UPDATE OR DELETE ON public.order_events
    FOR EACH ROW EXECUTE FUNCTION public.prevent_event_modification();
-- ==============================================================================
-- Migration: 00016_pos_operations
-- Description: Cash Registers, Shifts, Table Service, and Receipt Archives
-- ==============================================================================

-- Cash Registers
CREATE TABLE public.cash_registers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    outlet_id UUID NOT NULL,
    name VARCHAR(255) NOT NULL,
    device_identifier VARCHAR(255) UNIQUE, -- Binds a register to a specific hardware device
    status VARCHAR(50) NOT NULL DEFAULT 'OFFLINE', -- ONLINE, OFFLINE
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    
    FOREIGN KEY (tenant_id) REFERENCES public.tenants(id),
    FOREIGN KEY (outlet_id) REFERENCES public.outlets(id)
);

-- Cash Shifts (Till Management)
CREATE TABLE public.cash_shifts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    outlet_id UUID NOT NULL,
    cash_register_id UUID NOT NULL,
    opened_by UUID NOT NULL,
    closed_by UUID,
    opened_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    closed_at TIMESTAMPTZ,
    starting_balance NUMERIC(15, 4) NOT NULL DEFAULT 0,
    expected_balance NUMERIC(15, 4),
    actual_balance NUMERIC(15, 4),
    variance_amount NUMERIC(15, 4),
    notes TEXT,
    
    FOREIGN KEY (tenant_id) REFERENCES public.tenants(id),
    FOREIGN KEY (outlet_id) REFERENCES public.outlets(id),
    FOREIGN KEY (cash_register_id) REFERENCES public.cash_registers(id)
);

-- Draft Orders (For Table Service / Open Tabs)
CREATE TABLE public.draft_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    outlet_id UUID NOT NULL,
    name VARCHAR(255), -- e.g. "Table 4" or "John's Tab"
    table_number VARCHAR(50),
    state JSONB NOT NULL DEFAULT '{}'::jsonb, -- The serialized cart state
    created_by UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    
    FOREIGN KEY (tenant_id) REFERENCES public.tenants(id),
    FOREIGN KEY (outlet_id) REFERENCES public.outlets(id)
);

-- Receipt Archives (Sequential Receipt Strategy)
CREATE TABLE public.receipt_archives (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    outlet_id UUID NOT NULL,
    order_id UUID NOT NULL,
    receipt_number VARCHAR(255) NOT NULL, -- Hybrid ID: OUTLET-REG-DATE-SEQ
    receipt_html TEXT, -- Cached HTML/Text payload for instant re-printing
    printed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    printed_by UUID,
    
    FOREIGN KEY (tenant_id) REFERENCES public.tenants(id),
    FOREIGN KEY (outlet_id) REFERENCES public.outlets(id)
);

-- RLS Policies
ALTER TABLE public.cash_registers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cash_shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.draft_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.receipt_archives ENABLE ROW LEVEL SECURITY;

CREATE POLICY cr_isolation ON public.cash_registers FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY cs_isolation ON public.cash_shifts FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY do_isolation ON public.draft_orders FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY ra_isolation ON public.receipt_archives FOR ALL USING (tenant_id = public.get_current_tenant_id());

-- Audit Triggers
CREATE TRIGGER trg_audit_cash_registers AFTER INSERT OR UPDATE OR DELETE ON public.cash_registers FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();
CREATE TRIGGER trg_audit_cash_shifts AFTER INSERT OR UPDATE OR DELETE ON public.cash_shifts FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();
CREATE TRIGGER trg_audit_draft_orders AFTER INSERT OR UPDATE OR DELETE ON public.draft_orders FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

-- Indexes
CREATE INDEX idx_cash_registers_tenant ON public.cash_registers(tenant_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_cash_shifts_tenant ON public.cash_shifts(tenant_id);
CREATE INDEX idx_draft_orders_tenant ON public.draft_orders(tenant_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_receipt_archives_tenant ON public.receipt_archives(tenant_id);
-- ==============================================================================
-- Migration: 00017_shift_management
-- Description: Advanced Shift Control, Overrides, and POS Settings
-- ==============================================================================

-- POS Settings Configuration
CREATE TABLE public.pos_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    outlet_id UUID NOT NULL,
    blind_close_enabled BOOLEAN NOT NULL DEFAULT false,
    variance_threshold NUMERIC(15, 4) NOT NULL DEFAULT 5.00,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    FOREIGN KEY (tenant_id) REFERENCES public.tenants(id),
    FOREIGN KEY (outlet_id) REFERENCES public.outlets(id),
    UNIQUE(tenant_id, outlet_id)
);

-- Shift Events Table (Append-Only Ledger for Drawer Operations)
CREATE TABLE public.shift_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    outlet_id UUID NOT NULL,
    shift_id UUID NOT NULL,
    event_type VARCHAR(100) NOT NULL, -- CASH_IN, CASH_OUT, PETTY_CASH, CASH_DROP
    amount NUMERIC(15, 4) NOT NULL,
    reason TEXT,
    created_by UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    FOREIGN KEY (tenant_id) REFERENCES public.tenants(id),
    FOREIGN KEY (outlet_id) REFERENCES public.outlets(id),
    FOREIGN KEY (shift_id) REFERENCES public.cash_shifts(id)
);

-- Manager Overrides Table
CREATE TABLE public.manager_overrides (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    outlet_id UUID NOT NULL,
    shift_id UUID NOT NULL,
    approved_by UUID NOT NULL, -- The manager who provided the PIN
    approval_reason TEXT NOT NULL,
    approval_method VARCHAR(50) NOT NULL DEFAULT 'LOCAL_PIN',
    approved_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'::jsonb, -- e.g., expected variance vs actual
    
    FOREIGN KEY (tenant_id) REFERENCES public.tenants(id),
    FOREIGN KEY (outlet_id) REFERENCES public.outlets(id),
    FOREIGN KEY (shift_id) REFERENCES public.cash_shifts(id)
);

-- Enforce One Active Shift per Register Constraint
CREATE UNIQUE INDEX idx_one_active_shift_per_register 
ON public.cash_shifts (cash_register_id) 
WHERE closed_at IS NULL;

-- Link order_events rigidly to Shifts and Registers
ALTER TABLE public.order_events ADD COLUMN shift_id UUID;
ALTER TABLE public.order_events ADD COLUMN cash_register_id UUID;

ALTER TABLE public.order_events
    ADD CONSTRAINT fk_oe_shift FOREIGN KEY (shift_id) REFERENCES public.cash_shifts(id) ON DELETE SET NULL;
ALTER TABLE public.order_events
    ADD CONSTRAINT fk_oe_register FOREIGN KEY (cash_register_id) REFERENCES public.cash_registers(id) ON DELETE SET NULL;

-- RLS Policies
ALTER TABLE public.pos_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shift_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.manager_overrides ENABLE ROW LEVEL SECURITY;

CREATE POLICY ps_isolation ON public.pos_settings FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY se_isolation ON public.shift_events FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY mo_isolation ON public.manager_overrides FOR ALL USING (tenant_id = public.get_current_tenant_id());

-- Prevent Modification of Shift Events
CREATE TRIGGER trg_prevent_shift_events_mutation
    BEFORE UPDATE OR DELETE ON public.shift_events
    FOR EACH ROW EXECUTE FUNCTION public.prevent_event_modification();

-- Audit Triggers
CREATE TRIGGER trg_audit_pos_settings AFTER INSERT OR UPDATE OR DELETE ON public.pos_settings FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();
-- ==============================================================================
-- Migration: 00019_inventory_advanced
-- Description: Recipe Versioning, GRN Enforcement, Waste, and Procurement upgrades
-- ==============================================================================

-- 1. RECIPE VERSIONING REFACTOR
-- ---------------------------------------------------------
-- Drop the trigger from 00018 so we can recreate it with versioning logic
DROP TRIGGER IF EXISTS trg_explode_order_inventory ON public.order_events;
DROP FUNCTION IF EXISTS explode_order_to_inventory();

CREATE TABLE public.recipe_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    recipe_id UUID NOT NULL REFERENCES public.recipes(id) ON DELETE CASCADE,
    version_number INT NOT NULL,
    effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    effective_to TIMESTAMPTZ, -- null means it is the currently active version
    created_by UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (tenant_id, recipe_id, version_number)
);

-- Repoint recipe_items to recipe_version_id
ALTER TABLE public.recipe_items ADD COLUMN recipe_version_id UUID;
ALTER TABLE public.recipe_items 
    ADD CONSTRAINT fk_ri_version FOREIGN KEY (recipe_version_id) REFERENCES public.recipe_versions(id) ON DELETE CASCADE;

-- Drop old linkage to parent recipe
ALTER TABLE public.recipe_items DROP COLUMN recipe_id CASCADE;
ALTER TABLE public.recipe_items ALTER COLUMN recipe_version_id SET NOT NULL;

-- 2. REORDER INTELLIGENCE (Upgrading inventory_items)
-- ---------------------------------------------------------
ALTER TABLE public.inventory_items ADD COLUMN average_daily_usage DECIMAL(12,4) DEFAULT 0;
ALTER TABLE public.inventory_items ADD COLUMN lead_time_days INT DEFAULT 0;
ALTER TABLE public.inventory_items ADD COLUMN safety_stock DECIMAL(12,4) DEFAULT 0;
-- Note: Reorder Point = (Average Daily Usage * Lead Time) + Safety Stock

-- 3. WASTE MANAGEMENT
-- ---------------------------------------------------------
CREATE TABLE public.waste_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    outlet_id UUID REFERENCES public.outlets(id),
    warehouse_id UUID REFERENCES public.warehouses(id),
    inventory_item_id UUID NOT NULL REFERENCES public.inventory_items(id),
    waste_category VARCHAR(50) NOT NULL CHECK (waste_category IN ('EXPIRED', 'DAMAGED', 'SPOILAGE', 'PRODUCTION_WASTE', 'THEFT', 'SAMPLING', 'PROMOTIONAL')),
    quantity DECIMAL(12,3) NOT NULL CHECK (quantity > 0),
    unit_cost DECIMAL(12,2) NOT NULL,
    total_cost DECIMAL(12,2) GENERATED ALWAYS AS (quantity * unit_cost) STORED,
    reason TEXT,
    logged_by UUID,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. GOODS RECEIPT NOTES (GRN)
-- ---------------------------------------------------------
CREATE TABLE public.grns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    po_id UUID NOT NULL REFERENCES public.purchase_orders(id),
    grn_number VARCHAR(100) NOT NULL,
    received_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    received_by UUID,
    status VARCHAR(50) DEFAULT 'COMPLETED' CHECK (status IN ('DRAFT', 'COMPLETED', 'CANCELLED')),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, grn_number)
);

CREATE TABLE public.grn_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    grn_id UUID NOT NULL REFERENCES public.grns(id) ON DELETE CASCADE,
    po_item_id UUID NOT NULL REFERENCES public.po_items(id),
    inventory_item_id UUID NOT NULL REFERENCES public.inventory_items(id),
    quantity_received DECIMAL(12,3) NOT NULL CHECK (quantity_received > 0),
    batch_number VARCHAR(100),
    expiry_date DATE,
    unit_cost DECIMAL(12,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enforce inventory increases ONLY through GRN posting or Valid Transfers
CREATE OR REPLACE FUNCTION enforce_grn_for_increases()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.quantity_change > 0 THEN
        IF NEW.transaction_type = 'PURCHASE' AND NEW.reference_type != 'GRN' THEN
            RAISE EXCEPTION 'Inventory increases for purchases must occur through GRN posting.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_enforce_grn
BEFORE INSERT ON public.inventory_transactions
FOR EACH ROW EXECUTE FUNCTION enforce_grn_for_increases();

-- 5. UPGRADED STOCK DEDUCTION TRIGGER (Versioning Support)
-- ---------------------------------------------------------
CREATE OR REPLACE FUNCTION explode_order_to_inventory()
RETURNS TRIGGER AS $$
DECLARE
    item_record JSONB;
    v_product_id UUID;
    v_quantity INT;
    v_outlet_id UUID;
    v_order_time TIMESTAMPTZ;
    ingredient_record RECORD;
BEGIN
    IF NEW.event_type = 'ORDER_CREATED' THEN
        v_outlet_id := NEW.outlet_id;
        v_order_time := NEW.created_at;
        
        FOR item_record IN SELECT * FROM jsonb_array_elements(NEW.payload->'items')
        LOOP
            v_product_id := (item_record->>'id')::UUID;
            v_quantity := (item_record->>'quantity')::INT;
            
            -- Find the correct recipe version based on order timestamp
            FOR ingredient_record IN 
                SELECT ri.inventory_item_id, ri.quantity
                FROM public.recipes r
                JOIN public.recipe_versions rv ON r.id = rv.recipe_id
                JOIN public.recipe_items ri ON rv.id = ri.recipe_version_id
                WHERE r.product_id = v_product_id 
                  AND rv.effective_from <= v_order_time 
                  AND (rv.effective_to IS NULL OR rv.effective_to > v_order_time)
            LOOP
                INSERT INTO public.inventory_transactions (
                    tenant_id, outlet_id, inventory_item_id, transaction_type, 
                    quantity_change, unit_cost, reference_type, reference_id, notes
                ) VALUES (
                    NEW.tenant_id, v_outlet_id, ingredient_record.inventory_item_id, 'SALE',
                    -(ingredient_record.quantity * v_quantity), 0, 'ORDER', NEW.order_id, 'Recipe explosion (Version ' || rv.version_number || ')'
                );
            END LOOP;
        END LOOP;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_explode_order_inventory
AFTER INSERT ON public.order_events
FOR EACH ROW EXECUTE FUNCTION explode_order_to_inventory();

-- 6. SUPPLIER SCORECARDS
-- ---------------------------------------------------------
CREATE TABLE public.supplier_scorecards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    supplier_id UUID NOT NULL REFERENCES public.suppliers(id) ON DELETE CASCADE,
    evaluation_period VARCHAR(50), 
    on_time_delivery_score DECIMAL(5,2),
    quality_score DECIMAL(5,2),
    pricing_score DECIMAL(5,2),
    overall_score DECIMAL(5,2) GENERATED ALWAYS AS ((on_time_delivery_score + quality_score + pricing_score) / 3.0) STORED,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. WAREHOUSE TRANSFER WORKFLOW UPGRADE
-- ---------------------------------------------------------
ALTER TABLE public.warehouse_transfers DROP CONSTRAINT IF EXISTS warehouse_transfers_status_check;
ALTER TABLE public.warehouse_transfers ADD CONSTRAINT warehouse_transfers_status_check 
    CHECK (status IN ('DRAFT', 'PENDING', 'APPROVED', 'DISPATCHED', 'IN_TRANSIT', 'COMPLETED', 'CANCELLED'));

-- RLS Policies
ALTER TABLE public.recipe_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.waste_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grn_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supplier_scorecards ENABLE ROW LEVEL SECURITY;

CREATE POLICY rv_isolation ON public.recipe_versions FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY wl_isolation ON public.waste_logs FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY grn_isolation ON public.grns FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY grni_isolation ON public.grn_items FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY ss_isolation ON public.supplier_scorecards FOR ALL USING (tenant_id = public.get_current_tenant_id());
-- ==============================================================================
-- Migration: 00020_kds_architecture
-- Description: Kitchen Display System (Stations, Tickets, Realtime routing)
-- ==============================================================================

-- 1. KITCHEN STATIONS
-- ------------------------------------------------------------------------------
CREATE TABLE public.kitchen_stations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    station_type VARCHAR(50) NOT NULL CHECK (station_type IN ('GRILL', 'FRYER', 'BAR', 'DESSERT', 'EXPO', 'GENERAL')),
    status VARCHAR(50) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    UNIQUE(tenant_id, outlet_id, name)
);

-- 2. LINK PRODUCTS TO STATIONS
-- ------------------------------------------------------------------------------
ALTER TABLE public.menu_items ADD COLUMN kitchen_station_id UUID REFERENCES public.kitchen_stations(id) ON DELETE SET NULL;

-- 3. KITCHEN TICKETS
-- ------------------------------------------------------------------------------
CREATE TABLE public.kitchen_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
    station_id UUID NOT NULL REFERENCES public.kitchen_stations(id) ON DELETE CASCADE,
    order_id UUID NOT NULL, 
    order_number VARCHAR(100),
    order_type VARCHAR(50) NOT NULL DEFAULT 'DINE_IN' CHECK (order_type IN ('DINE_IN', 'TAKEAWAY', 'DELIVERY', 'QR_ORDER')),
    priority VARCHAR(50) NOT NULL DEFAULT 'NORMAL' CHECK (priority IN ('NORMAL', 'HIGH', 'URGENT', 'VIP')),
    status VARCHAR(50) NOT NULL DEFAULT 'NEW' CHECK (status IN ('NEW', 'ACKNOWLEDGED', 'PREPARING', 'READY', 'SERVED', 'CANCELLED')),
    customer_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), -- The actual time it hit the cloud
    order_created_at TIMESTAMPTZ NOT NULL, -- The time it was created on the offline POS
    acknowledged_at TIMESTAMPTZ,
    prep_started_at TIMESTAMPTZ,
    ready_at TIMESTAMPTZ,
    served_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- 4. KITCHEN TICKET ITEMS
-- ------------------------------------------------------------------------------
CREATE TABLE public.kitchen_ticket_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    ticket_id UUID NOT NULL REFERENCES public.kitchen_tickets(id) ON DELETE CASCADE,
    menu_item_id UUID NOT NULL REFERENCES public.menu_items(id),
    product_name VARCHAR(255) NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    modifiers JSONB,
    notes TEXT,
    status VARCHAR(50) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'COMPLETED', 'CANCELLED')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. TRIGGER FOR AUTO-GENERATING KDS TICKETS
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION route_order_to_kds()
RETURNS TRIGGER AS $$
DECLARE
    v_item JSONB;
    v_menu_item_id UUID;
    v_station_id UUID;
    v_ticket_id UUID;
    v_order_type VARCHAR;
    v_priority VARCHAR;
BEGIN
    -- Only trigger on ORDER_CREATED
    IF NEW.event_type = 'ORDER_CREATED' THEN
        
        v_order_type := COALESCE(NEW.payload->>'order_type', 'DINE_IN');
        v_priority := COALESCE(NEW.payload->>'priority', 'NORMAL');

        -- Loop through the payload items
        FOR v_item IN SELECT * FROM jsonb_array_elements(NEW.payload->'items')
        LOOP
            v_menu_item_id := (v_item->>'id')::UUID;
            
            -- Determine the station for this product
            SELECT kitchen_station_id INTO v_station_id
            FROM public.menu_items WHERE id = v_menu_item_id;
            
            -- Fallback to a default 'GENERAL' station if mapping is missing
            IF v_station_id IS NULL THEN
                SELECT id INTO v_station_id FROM public.kitchen_stations 
                WHERE tenant_id = NEW.tenant_id AND outlet_id = NEW.outlet_id 
                ORDER BY created_at ASC LIMIT 1;
            END IF;
            
            IF v_station_id IS NOT NULL THEN
                -- Check if a ticket for this station & order already exists
                SELECT id INTO v_ticket_id 
                FROM public.kitchen_tickets 
                WHERE order_id = NEW.order_id AND station_id = v_station_id;
                
                IF v_ticket_id IS NULL THEN
                    -- Create new ticket
                    INSERT INTO public.kitchen_tickets (
                        tenant_id, outlet_id, station_id, order_id, order_number, order_type, priority, order_created_at
                    ) VALUES (
                        NEW.tenant_id, NEW.outlet_id, v_station_id, NEW.order_id, NEW.payload->>'order_number', v_order_type, v_priority, NEW.created_at
                    ) RETURNING id INTO v_ticket_id;
                END IF;
                
                -- Add item to ticket
                INSERT INTO public.kitchen_ticket_items (
                    tenant_id, ticket_id, menu_item_id, product_name, quantity, modifiers, notes
                ) VALUES (
                    NEW.tenant_id, v_ticket_id, v_menu_item_id, v_item->>'name', (v_item->>'quantity')::INT, v_item->'modifiers', v_item->>'notes'
                );
            END IF;
        END LOOP;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_route_order_kds
AFTER INSERT ON public.order_events
FOR EACH ROW EXECUTE FUNCTION route_order_to_kds();

-- RLS Policies
ALTER TABLE public.kitchen_stations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kitchen_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kitchen_ticket_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY kds_st_isolation ON public.kitchen_stations FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY kds_ti_isolation ON public.kitchen_tickets FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY kds_tii_isolation ON public.kitchen_ticket_items FOR ALL USING (tenant_id = public.get_current_tenant_id());
-- ==============================================================================
-- Migration: 00021_crm_loyalty
-- Description: CRM & Loyalty Ledger, Tiers, Segmentation, and Visit Tracking
-- ==============================================================================

-- 1. CUSTOMER TABLE EXTENSIONS
-- ------------------------------------------------------------------------------
ALTER TABLE public.customers ADD COLUMN loyalty_tier VARCHAR(50) DEFAULT 'BRONZE' CHECK (loyalty_tier IN ('BRONZE', 'SILVER', 'GOLD', 'PLATINUM', 'VIP'));
ALTER TABLE public.customers ADD COLUMN total_visits INT DEFAULT 0 CHECK (total_visits >= 0);
ALTER TABLE public.customers ADD COLUMN customer_segment VARCHAR(100) DEFAULT 'NEW';
ALTER TABLE public.customers ADD COLUMN current_points_balance INT DEFAULT 0;

-- 2. CUSTOMER LOYALTY LEDGER
-- ------------------------------------------------------------------------------
CREATE TABLE public.customer_loyalty_ledger (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    outlet_id UUID REFERENCES public.outlets(id),
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
    transaction_type VARCHAR(50) NOT NULL CHECK (transaction_type IN ('EARN', 'BURN', 'ADJUSTMENT', 'EXPIRE')),
    points INT NOT NULL, -- positive for earn, negative for burn
    reference_type VARCHAR(50), -- e.g., 'ORDER', 'PROMOTION'
    reference_id UUID,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID
);

-- 3. NEGATIVE BALANCE PROTECTION & CACHE UPDATER
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION protect_and_update_loyalty_balance()
RETURNS TRIGGER AS $$
DECLARE
    v_new_balance INT;
BEGIN
    -- Calculate the theoretical new balance for this customer
    SELECT COALESCE(SUM(points), 0) + NEW.points INTO v_new_balance
    FROM public.customer_loyalty_ledger
    WHERE customer_id = NEW.customer_id;

    -- Enforce strict negative balance protection
    IF v_new_balance < 0 THEN
        RAISE EXCEPTION 'Insufficient loyalty points. Attempted to burn % points, but balance would drop to %.', ABS(NEW.points), v_new_balance;
    END IF;

    -- Update the cached balance on the customer table
    UPDATE public.customers 
    SET current_points_balance = v_new_balance
    WHERE id = NEW.customer_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_loyalty_ledger_protection
BEFORE INSERT ON public.customer_loyalty_ledger
FOR EACH ROW EXECUTE FUNCTION protect_and_update_loyalty_balance();


-- 4. AUTO-EARN POINTS & VISIT TRACKING ON ORDER CREATED
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION crm_process_order()
RETURNS TRIGGER AS $$
DECLARE
    v_customer_id UUID;
    v_total_amount DECIMAL;
    v_points_earned INT;
BEGIN
    IF NEW.event_type = 'ORDER_CREATED' THEN
        v_customer_id := (NEW.payload->>'customer_id')::UUID;
        v_total_amount := (NEW.payload->>'total_amount')::DECIMAL;
        
        IF v_customer_id IS NOT NULL THEN
            -- Increment visit count
            UPDATE public.customers 
            SET total_visits = total_visits + 1,
                last_visit_date = NEW.created_at
            WHERE id = v_customer_id;

            -- Calculate standard points (e.g. 1 point per $1 spent)
            v_points_earned := FLOOR(v_total_amount);
            
            IF v_points_earned > 0 THEN
                INSERT INTO public.customer_loyalty_ledger (
                    tenant_id, outlet_id, customer_id, transaction_type, points, reference_type, reference_id, notes
                ) VALUES (
                    NEW.tenant_id, NEW.outlet_id, v_customer_id, 'EARN', v_points_earned, 'ORDER', NEW.order_id, 'Auto-earn from order'
                );
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_crm_process_order
AFTER INSERT ON public.order_events
FOR EACH ROW EXECUTE FUNCTION crm_process_order();

-- RLS
ALTER TABLE public.customer_loyalty_ledger ENABLE ROW LEVEL SECURITY;
CREATE POLICY cll_isolation ON public.customer_loyalty_ledger FOR ALL USING (tenant_id = public.get_current_tenant_id());
-- ==============================================================================
-- Migration: 00023_ai_forecasting
-- Description: Historical Forecasting, Predictive Analytics
-- ==============================================================================

-- 1. AI FORECASTS TABLE
-- ------------------------------------------------------------------------------
CREATE TABLE public.ai_forecasts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    outlet_id UUID REFERENCES public.outlets(id) ON DELETE CASCADE,
    forecast_type VARCHAR(50) NOT NULL CHECK (forecast_type IN ('SALES', 'CUSTOMERS', 'INVENTORY_USAGE')),
    target_date DATE NOT NULL,
    metric_name VARCHAR(100) NOT NULL, -- e.g., 'Total Revenue', 'Burger Buns Usage'
    predicted_value DECIMAL(15,2) NOT NULL,
    confidence_interval_low DECIMAL(15,2),
    confidence_interval_high DECIMAL(15,2),
    model_version VARCHAR(50) DEFAULT 'v1.0-historical',
    weather_impact_factor DECIMAL(5,2), -- Prepared for future integration
    local_event_flag BOOLEAN DEFAULT false, -- Prepared for future integration
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, outlet_id, forecast_type, target_date, metric_name)
);

-- 2. AI FORECAST FEATURES (Prepared Architecture)
-- ------------------------------------------------------------------------------
-- Tracks external features that feed into the AI model for a specific date
CREATE TABLE public.ai_forecast_features (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    outlet_id UUID REFERENCES public.outlets(id) ON DELETE CASCADE,
    target_date DATE NOT NULL,
    weather_condition VARCHAR(100),
    temperature_high DECIMAL(5,2),
    temperature_low DECIMAL(5,2),
    is_holiday BOOLEAN DEFAULT false,
    local_event_name VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, outlet_id, target_date)
);

-- RLS
ALTER TABLE public.ai_forecasts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_forecast_features ENABLE ROW LEVEL SECURITY;

CREATE POLICY aif_isolation ON public.ai_forecasts FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY aiff_isolation ON public.ai_forecast_features FOR ALL USING (tenant_id = public.get_current_tenant_id());
-- ==============================================================================
-- Migration: 00024_enterprise_hierarchy
-- Description: Multi-Brand Org, Menus, Addresses, Order Types
-- ==============================================================================

-- 1. ORGANIZATIONS (Top Level)
-- ------------------------------------------------------------------------------
CREATE TABLE public.organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    status VARCHAR(50) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- 2. BRANDS
-- ------------------------------------------------------------------------------
CREATE TABLE public.brands (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    status VARCHAR(50) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- 3. BRAND SETTINGS
-- ------------------------------------------------------------------------------
CREATE TABLE public.brand_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    brand_id UUID NOT NULL REFERENCES public.brands(id) ON DELETE CASCADE,
    primary_color VARCHAR(50),
    logo_url TEXT,
    support_email VARCHAR(255),
    support_phone VARCHAR(50),
    timezone VARCHAR(100) DEFAULT 'UTC',
    currency VARCHAR(10) DEFAULT 'USD',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(brand_id)
);

-- 4. ATTACH TO TENANTS
-- ------------------------------------------------------------------------------
ALTER TABLE public.tenants ADD COLUMN organization_id UUID REFERENCES public.organizations(id);
ALTER TABLE public.tenants ADD COLUMN brand_id UUID REFERENCES public.brands(id);

-- 5. CUSTOMER ADDRESSES
-- ------------------------------------------------------------------------------
CREATE TABLE public.customer_addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
    label VARCHAR(100) DEFAULT 'HOME', -- e.g. HOME, WORK
    address_line_1 TEXT NOT NULL,
    address_line_2 TEXT,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100),
    postal_code VARCHAR(50),
    country VARCHAR(100) DEFAULT 'USA',
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    is_default BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- 6. PUBLISHED MENUS (Online Commerce)
-- ------------------------------------------------------------------------------
CREATE TABLE public.published_menus (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    outlet_id UUID REFERENCES public.outlets(id) ON DELETE CASCADE, -- Null means brand/tenant wide
    name VARCHAR(255) NOT NULL,
    status VARCHAR(50) DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'PUBLISHED', 'SCHEDULED', 'ARCHIVED')),
    scheduled_for TIMESTAMPTZ,
    menu_data JSONB NOT NULL, -- Point-in-time snapshot of categories and items
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- 7. EXPAND ORDER TYPES (Modifying existing constraint is tricky in Postgres, better to drop/recreate if it was a domain, but for CHECK constraints we alter table)
-- Note: kitchen_tickets has an order_type constraint. We must alter it.
ALTER TABLE public.kitchen_tickets DROP CONSTRAINT IF EXISTS kitchen_tickets_order_type_check;
ALTER TABLE public.kitchen_tickets ADD CONSTRAINT kitchen_tickets_order_type_check 
    CHECK (order_type IN ('DINE_IN', 'TAKEAWAY', 'DELIVERY', 'QR_ORDER', 'DINE_IN_QR', 'PREORDER'));

-- RLS
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.brands ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.brand_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.published_menus ENABLE ROW LEVEL SECURITY;

-- Note: Org/Brand visibility might need cross-tenant logic for Executive views, but for now we default to tenant_id isolation where applicable.
-- Organizations and Brands are top-level, they don't have tenant_id. 
-- For now, allow all authenticated users to read their own Org/Brand.
CREATE POLICY ca_isolation ON public.customer_addresses FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY pm_isolation ON public.published_menus FOR ALL USING (tenant_id = public.get_current_tenant_id());
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
CREATE TABLE public.api_gateway_logs (
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
CREATE INDEX idx_api_gateway_logs_tenant_created ON public.api_gateway_logs(tenant_id, created_at DESC);
CREATE INDEX idx_api_gateway_logs_errors ON public.api_gateway_logs(tenant_id, status_code) WHERE status_code >= 400;

-- RLS
ALTER TABLE public.api_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.api_gateway_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY ak_isolation ON public.api_keys FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY il_isolation ON public.api_gateway_logs FOR ALL USING (tenant_id = public.get_current_tenant_id());
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
-- ==============================================================================
-- Migration: 00029_reporting_suite
-- Description: OLAP Data Warehousing, Materialized Views, and Scheduled Reports
-- ==============================================================================

-- 1. DEDICATED REPORTING SCHEMA
-- ------------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS reporting;

-- 2. MATERIALIZED VIEWS (Pre-aggregated for Dashboard Speed)
-- ------------------------------------------------------------------------------

-- 2A. Daily Sales Aggregation
CREATE MATERIALIZED VIEW reporting.mv_daily_sales AS
SELECT 
    o.tenant_id,
    o.outlet_id,
    DATE(o.created_at) AS sales_date,
    COUNT(o.id) AS total_orders,
    SUM((o.payload->>'total_amount')::DECIMAL) AS total_revenue,
    SUM((o.payload->>'tax_amount')::DECIMAL) AS total_tax,
    AVG((o.payload->>'total_amount')::DECIMAL) AS average_ticket_size
FROM public.order_events o
WHERE o.event_type = 'ORDER_CREATED'
GROUP BY o.tenant_id, o.outlet_id, DATE(o.created_at);

-- 2B. Financials & P&L Rollup
CREATE MATERIALIZED VIEW reporting.mv_financials AS
SELECT 
    jl.tenant_id,
    DATE(je.entry_date) AS entry_date,
    coa.account_type,
    SUM(jl.credit) - SUM(jl.debit) AS net_balance -- Standard accounting rollup logic
FROM public.journal_lines jl
JOIN public.journal_entries je ON jl.journal_entry_id = je.id
JOIN public.accounts coa ON jl.account_id = coa.id
WHERE je.status = 'POSTED'
GROUP BY jl.tenant_id, DATE(je.entry_date), coa.account_type;

-- 2C. Kitchen Performance (KDS)
CREATE MATERIALIZED VIEW reporting.mv_kds AS
SELECT 
    kt.tenant_id,
    kt.outlet_id,
    DATE(kt.created_at) AS kds_date,
    kt.station_id,
    COUNT(kt.id) AS tickets_processed,
    AVG(EXTRACT(EPOCH FROM (kt.ready_at - kt.prep_started_at))/60) AS avg_prep_time_minutes,
    COUNT(CASE WHEN EXTRACT(EPOCH FROM (kt.ready_at - kt.prep_started_at))/60 > 15 THEN 1 END) AS sla_breaches
FROM public.kitchen_tickets kt
WHERE kt.status IN ('READY', 'SERVED')
GROUP BY kt.tenant_id, kt.outlet_id, DATE(kt.created_at), kt.station_id;

-- 2D. Inventory Actual vs Theoretical & Waste
CREATE MATERIALIZED VIEW reporting.mv_inventory AS
SELECT 
    it.tenant_id,
    it.outlet_id,
    DATE(it.created_at) AS inventory_date,
    SUM(CASE WHEN it.transaction_type = 'WASTE_RECORDED' THEN ABS(it.quantity_change) ELSE 0 END) AS total_waste_qty,
    SUM(CASE WHEN it.transaction_type = 'SHRINKAGE' THEN ABS(it.quantity_change) ELSE 0 END) AS total_shrinkage_qty,
    SUM(CASE WHEN it.transaction_type = 'OVERPORTIONING' THEN ABS(it.quantity_change) ELSE 0 END) AS total_overportioning_qty
FROM public.inventory_transactions it
GROUP BY it.tenant_id, it.outlet_id, DATE(it.created_at);

-- Indexes to speed up MV queries
CREATE UNIQUE INDEX idx_mv_sales ON reporting.mv_daily_sales (tenant_id, outlet_id, sales_date);
CREATE UNIQUE INDEX idx_mv_fin ON reporting.mv_financials (tenant_id, entry_date, account_type);
CREATE UNIQUE INDEX idx_mv_kds ON reporting.mv_kds (tenant_id, outlet_id, kds_date, station_id);
CREATE UNIQUE INDEX idx_mv_inv ON reporting.mv_inventory (tenant_id, outlet_id, inventory_date);


-- 3. SCHEDULED REPORTS ENGINE
-- ------------------------------------------------------------------------------
CREATE TABLE reporting.scheduled_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    report_name VARCHAR(255) NOT NULL,
    report_type VARCHAR(50) NOT NULL CHECK (report_type IN ('PNL', 'FOOD_COST', 'SALES_SUMMARY', 'KDS_PERFORMANCE')),
    format VARCHAR(20) DEFAULT 'PDF' CHECK (format IN ('PDF', 'CSV', 'EXCEL')),
    schedule_cron VARCHAR(100) NOT NULL, -- e.g., '0 2 * * *' for 2 AM daily
    recipient_emails JSONB NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE reporting.report_executions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    scheduled_report_id UUID REFERENCES reporting.scheduled_reports(id) ON DELETE CASCADE,
    execution_time TIMESTAMPTZ DEFAULT NOW(),
    status VARCHAR(50) DEFAULT 'PROCESSING' CHECK (status IN ('PROCESSING', 'SUCCESS', 'FAILED')),
    file_url TEXT, -- Link to S3/Supabase Storage bucket
    error_message TEXT
);


-- 4. FORECAST ACCURACY TRACKING (AI Audit)
-- ------------------------------------------------------------------------------
CREATE TABLE reporting.forecast_accuracy (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    forecast_id UUID REFERENCES public.ai_forecasts(id) ON DELETE CASCADE,
    target_date DATE NOT NULL,
    metric_name VARCHAR(100) NOT NULL,
    predicted_value DECIMAL(15,2) NOT NULL,
    actual_value DECIMAL(15,2) NOT NULL,
    variance_value DECIMAL(15,2) NOT NULL,
    accuracy_percentage DECIMAL(5,2) NOT NULL, -- ABS(Actual - Predicted) / Actual
    calculated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Note: In Supabase, Row Level Security (RLS) is not supported on Materialized Views.
-- To enforce tenant isolation on MVs, we will strictly wrap access in Secure RPC functions 
-- or edge functions that explicitly append "WHERE tenant_id = current_tenant_id()".
-- However, we CAN apply RLS to the underlying standard tables.

ALTER TABLE reporting.scheduled_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE reporting.report_executions ENABLE ROW LEVEL SECURITY;
ALTER TABLE reporting.forecast_accuracy ENABLE ROW LEVEL SECURITY;

CREATE POLICY sr_isolation ON reporting.scheduled_reports FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY re_isolation ON reporting.report_executions FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY fa_isolation ON reporting.forecast_accuracy FOR ALL USING (tenant_id = public.get_current_tenant_id());
