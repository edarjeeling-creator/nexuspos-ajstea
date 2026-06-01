-- ==============================================================================
-- Migration: 00032_phase2_modules
-- Description: Adds schema for Customers, Shipments, and Stock Conversions.
-- ==============================================================================

-- 1. MODIFY ORDERS
-- ------------------------------------------------------------------------------
ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS invoice_number VARCHAR(100);

-- Unique index for invoice number (nulls are ignored by default in Postgres unique indexes)
CREATE UNIQUE INDEX IF NOT EXISTS idx_orders_invoice_number ON public.orders(tenant_id, invoice_number) WHERE deleted_at IS NULL AND invoice_number IS NOT NULL;


-- 2. MODIFY CUSTOMERS
-- ------------------------------------------------------------------------------
ALTER TABLE public.customers
ADD COLUMN IF NOT EXISTS gstin VARCHAR(50),
ADD COLUMN IF NOT EXISTS shipping_address TEXT;


-- 3. SHIPMENTS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.shipments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    courier_name VARCHAR(255),
    tracking_number VARCHAR(255),
    dispatch_date TIMESTAMP WITH TIME ZONE,
    estimated_delivery_date TIMESTAMP WITH TIME ZONE,
    status VARCHAR(50) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'DISPATCHED', 'IN_TRANSIT', 'DELIVERED', 'RETURNED')),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);
COMMENT ON TABLE public.shipments IS 'Tracks delivery orders and manual courier details.';

CREATE INDEX IF NOT EXISTS idx_shipments_tenant_id ON public.shipments(tenant_id);
CREATE INDEX IF NOT EXISTS idx_shipments_order_id ON public.shipments(order_id);
CREATE INDEX IF NOT EXISTS idx_shipments_active ON public.shipments(tenant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_shipments_updated_at
BEFORE UPDATE ON public.shipments
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_shipments
AFTER INSERT OR UPDATE OR DELETE ON public.shipments
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.shipments ENABLE ROW LEVEL SECURITY;

CREATE POLICY shipments_isolation_policy ON public.shipments
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- 4. STOCK CONVERSIONS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.stock_conversions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    warehouse_id UUID REFERENCES public.warehouses(id) ON DELETE RESTRICT,
    source_item_id UUID NOT NULL REFERENCES public.inventory_items(id) ON DELETE RESTRICT,
    target_item_id UUID NOT NULL REFERENCES public.inventory_items(id) ON DELETE RESTRICT,
    source_qty_deducted DECIMAL(12,3) NOT NULL CHECK (source_qty_deducted > 0),
    target_qty_produced DECIMAL(12,3) NOT NULL CHECK (target_qty_produced > 0),
    conversion_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    batch_number VARCHAR(100),
    notes TEXT,
    created_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);
COMMENT ON TABLE public.stock_conversions IS 'Records the conversion of bulk inventory (source) into packaged inventory (target). Does not track labor/costs in this phase.';

CREATE INDEX IF NOT EXISTS idx_stock_conversions_tenant_id ON public.stock_conversions(tenant_id);
CREATE INDEX IF NOT EXISTS idx_stock_conversions_warehouse_id ON public.stock_conversions(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_stock_conversions_active ON public.stock_conversions(tenant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_stock_conversions_updated_at
BEFORE UPDATE ON public.stock_conversions
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_stock_conversions
AFTER INSERT OR UPDATE OR DELETE ON public.stock_conversions
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.stock_conversions ENABLE ROW LEVEL SECURITY;

CREATE POLICY stock_conversions_isolation_policy ON public.stock_conversions
    FOR ALL USING (tenant_id = public.get_current_tenant_id());
