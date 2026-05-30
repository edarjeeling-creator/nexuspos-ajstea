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
