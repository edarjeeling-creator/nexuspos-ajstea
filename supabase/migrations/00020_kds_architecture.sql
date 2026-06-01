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
