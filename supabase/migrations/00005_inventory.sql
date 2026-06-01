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



