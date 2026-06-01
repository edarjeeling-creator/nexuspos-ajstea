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
