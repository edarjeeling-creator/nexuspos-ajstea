-- ==============================================================================
-- Migration: 00017_shift_management
-- Description: Advanced Shift Control, Overrides, and POS Settings
-- ==============================================================================

-- POS Settings Configuration
CREATE TABLE public.pos_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    outlet_id UUID NOT NULL,
    blind_close_enabled BOOLEAN NOT NULL DEFAULT false,
    variance_threshold NUMERIC(15, 4) NOT NULL DEFAULT 5.00,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    FOREIGN KEY (tenant_id) REFERENCES public.tenants(id),
    FOREIGN KEY (outlet_id) REFERENCES public.outlets(id),
    UNIQUE(tenant_id, outlet_id)
);

-- Shift Events Table (Append-Only Ledger for Drawer Operations)
CREATE TABLE public.shift_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    outlet_id UUID NOT NULL,
    shift_id UUID NOT NULL,
    event_type VARCHAR(100) NOT NULL, -- CASH_IN, CASH_OUT, PETTY_CASH, CASH_DROP
    amount NUMERIC(15, 4) NOT NULL,
    reason TEXT,
    created_by UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    FOREIGN KEY (tenant_id) REFERENCES public.tenants(id),
    FOREIGN KEY (outlet_id) REFERENCES public.outlets(id),
    FOREIGN KEY (shift_id) REFERENCES public.cash_shifts(id)
);

-- Manager Overrides Table
CREATE TABLE public.manager_overrides (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    outlet_id UUID NOT NULL,
    shift_id UUID NOT NULL,
    approved_by UUID NOT NULL, -- The manager who provided the PIN
    approval_reason TEXT NOT NULL,
    approval_method VARCHAR(50) NOT NULL DEFAULT 'LOCAL_PIN',
    approved_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'::jsonb, -- e.g., expected variance vs actual
    
    FOREIGN KEY (tenant_id) REFERENCES public.tenants(id),
    FOREIGN KEY (outlet_id) REFERENCES public.outlets(id),
    FOREIGN KEY (shift_id) REFERENCES public.cash_shifts(id)
);

-- Enforce One Active Shift per Register Constraint
CREATE UNIQUE INDEX idx_one_active_shift_per_register 
ON public.cash_shifts (cash_register_id) 
WHERE closed_at IS NULL;

-- Link order_events rigidly to Shifts and Registers
ALTER TABLE public.order_events ADD COLUMN shift_id UUID;
ALTER TABLE public.order_events ADD COLUMN cash_register_id UUID;

ALTER TABLE public.order_events
    ADD CONSTRAINT fk_oe_shift FOREIGN KEY (shift_id) REFERENCES public.cash_shifts(id) ON DELETE SET NULL;
ALTER TABLE public.order_events
    ADD CONSTRAINT fk_oe_register FOREIGN KEY (cash_register_id) REFERENCES public.cash_registers(id) ON DELETE SET NULL;

-- RLS Policies
ALTER TABLE public.pos_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shift_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.manager_overrides ENABLE ROW LEVEL SECURITY;

CREATE POLICY ps_isolation ON public.pos_settings FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY se_isolation ON public.shift_events FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY mo_isolation ON public.manager_overrides FOR ALL USING (tenant_id = public.get_current_tenant_id());

-- Prevent Modification of Shift Events
CREATE TRIGGER trg_prevent_shift_events_mutation
    BEFORE UPDATE OR DELETE ON public.shift_events
    FOR EACH ROW EXECUTE FUNCTION public.prevent_event_modification();

-- Audit Triggers
CREATE TRIGGER trg_audit_pos_settings AFTER INSERT OR UPDATE OR DELETE ON public.pos_settings FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();
