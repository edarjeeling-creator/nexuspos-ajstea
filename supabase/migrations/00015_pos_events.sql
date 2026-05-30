-- ==============================================================================
-- Migration: 00015_pos_events
-- Description: Core Event-Sourcing Ledger for POS Orders
-- ==============================================================================

-- Order Events Table (Append-Only Ledger)
CREATE TABLE public.order_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    outlet_id UUID NOT NULL,
    order_id UUID NOT NULL, -- Ties events to a specific logical order
    event_type VARCHAR(100) NOT NULL, -- e.g., ORDER_CREATED, ITEM_ADDED, PAYMENT_CAPTURED, ORDER_VOIDED
    payload JSONB NOT NULL DEFAULT '{}'::jsonb, -- The serialized event data
    device_identifier VARCHAR(255), -- Tracks which physical device generated the event
    created_by UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    FOREIGN KEY (tenant_id) REFERENCES public.tenants(id),
    FOREIGN KEY (outlet_id) REFERENCES public.outlets(id)
);

-- RLS Policies
ALTER TABLE public.order_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY order_events_isolation_policy ON public.order_events
    FOR ALL USING (tenant_id = public.get_current_tenant_id());

-- Indexes for event reconstruction and syncing
CREATE INDEX idx_order_events_tenant ON public.order_events(tenant_id);
CREATE INDEX idx_order_events_order_id ON public.order_events(order_id);
CREATE INDEX idx_order_events_created_at ON public.order_events(created_at);

-- Trigger to prevent UPDATE or DELETE on the append-only ledger
CREATE OR REPLACE FUNCTION public.prevent_event_modification()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Order events are immutable. Updates and Deletes are forbidden.';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_order_events_mutation
    BEFORE UPDATE OR DELETE ON public.order_events
    FOR EACH ROW EXECUTE FUNCTION public.prevent_event_modification();
