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
