-- ==============================================================================
-- Migration: 00018_inventory_recipes
-- Description: Recipe mapping and automatic stock deduction trigger.
-- ==============================================================================

-- 1. RECIPES TABLE
CREATE TABLE public.recipes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE, -- The finished good / menu item
    name VARCHAR(255) NOT NULL,
    status VARCHAR(50) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE', 'DRAFT')),
    yield DECIMAL(12,2) DEFAULT 1.00,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, product_id)
);

-- 2. RECIPE INGREDIENTS TABLE
CREATE TABLE public.recipe_ingredients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    recipe_id UUID NOT NULL REFERENCES public.recipes(id) ON DELETE CASCADE,
    inventory_item_id UUID NOT NULL REFERENCES public.inventory_items(id) ON DELETE RESTRICT,
    quantity DECIMAL(12,4) NOT NULL CHECK (quantity > 0),
    unit_of_measure VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, recipe_id, inventory_item_id)
);

-- 3. RLS
ALTER TABLE public.recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recipe_ingredients ENABLE ROW LEVEL SECURITY;

CREATE POLICY recipes_isolation ON public.recipes FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY ri_isolation ON public.recipe_ingredients FOR ALL USING (tenant_id = public.get_current_tenant_id());

-- 4. STOCK DEDUCTION FUNCTION (TRIGGER)
CREATE OR REPLACE FUNCTION explode_order_to_inventory()
RETURNS TRIGGER AS $$
DECLARE
    item_record JSONB;
    v_product_id UUID;
    v_quantity INT;
    v_outlet_id UUID;
    ingredient_record RECORD;
BEGIN
    -- Only trigger on ORDER_CREATED events
    IF NEW.event_type = 'ORDER_CREATED' THEN
        v_outlet_id := NEW.outlet_id;
        
        -- Loop through the payload items
        FOR item_record IN SELECT * FROM jsonb_array_elements(NEW.payload->'items')
        LOOP
            v_product_id := (item_record->>'id')::UUID;
            v_quantity := (item_record->>'quantity')::INT;
            
            -- Does this product have an active recipe?
            FOR ingredient_record IN 
                SELECT ri.inventory_item_id, ri.quantity
                FROM public.recipes r
                JOIN public.recipe_ingredients ri ON r.id = ri.recipe_id
                WHERE r.product_id = v_product_id AND r.status = 'ACTIVE'
            LOOP
                -- Insert a negative transaction into the ledger
                INSERT INTO public.inventory_transactions (
                    tenant_id, outlet_id, inventory_item_id, transaction_type, 
                    quantity_change, unit_cost, reference_type, reference_id, notes
                ) VALUES (
                    NEW.tenant_id, v_outlet_id, ingredient_record.inventory_item_id, 'SALE',
                    -(ingredient_record.quantity * v_quantity), 0, 'ORDER', NEW.order_id, 'Recipe explosion from POS'
                );
            END LOOP;
        END LOOP;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach Trigger to the Event Ledger
CREATE TRIGGER trg_explode_order_inventory
AFTER INSERT ON public.order_events
FOR EACH ROW EXECUTE FUNCTION explode_order_to_inventory();
