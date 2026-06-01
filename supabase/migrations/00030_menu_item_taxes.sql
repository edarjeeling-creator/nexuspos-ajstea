-- Migration: 00030_menu_item_taxes
-- Description: Add tax rules to menu items

ALTER TABLE public.menu_items 
ADD COLUMN tax_rate DECIMAL(5,2) DEFAULT 0 CHECK (tax_rate >= 0),
ADD COLUMN tax_inclusive BOOLEAN DEFAULT false;
