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
