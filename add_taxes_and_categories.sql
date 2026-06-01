-- Add missing columns to categories
ALTER TABLE public.categories ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE public.categories ADD COLUMN IF NOT EXISTS display_order INT DEFAULT 0;

-- Add missing columns to menu_items
ALTER TABLE public.menu_items ADD COLUMN IF NOT EXISTS tax_rate DECIMAL(5,2) DEFAULT 0 CHECK (tax_rate >= 0);
ALTER TABLE public.menu_items ADD COLUMN IF NOT EXISTS tax_inclusive BOOLEAN DEFAULT false;
