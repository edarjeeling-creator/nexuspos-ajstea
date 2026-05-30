-- ==============================================================================
-- Migration: 00016_pos_operations
-- Description: Cash Registers, Shifts, Table Service, and Receipt Archives
-- ==============================================================================

-- Cash Registers
CREATE TABLE public.cash_registers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    outlet_id UUID NOT NULL,
    name VARCHAR(255) NOT NULL,
    device_identifier VARCHAR(255) UNIQUE, -- Binds a register to a specific hardware device
    status VARCHAR(50) NOT NULL DEFAULT 'OFFLINE', -- ONLINE, OFFLINE
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    
    FOREIGN KEY (tenant_id) REFERENCES public.tenants(id),
    FOREIGN KEY (outlet_id) REFERENCES public.outlets(id)
);

-- Cash Shifts (Till Management)
CREATE TABLE public.cash_shifts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    outlet_id UUID NOT NULL,
    cash_register_id UUID NOT NULL,
    opened_by UUID NOT NULL,
    closed_by UUID,
    opened_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    closed_at TIMESTAMPTZ,
    starting_balance NUMERIC(15, 4) NOT NULL DEFAULT 0,
    expected_balance NUMERIC(15, 4),
    actual_balance NUMERIC(15, 4),
    variance_amount NUMERIC(15, 4),
    notes TEXT,
    
    FOREIGN KEY (tenant_id) REFERENCES public.tenants(id),
    FOREIGN KEY (outlet_id) REFERENCES public.outlets(id),
    FOREIGN KEY (cash_register_id) REFERENCES public.cash_registers(id)
);

-- Draft Orders (For Table Service / Open Tabs)
CREATE TABLE public.draft_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    outlet_id UUID NOT NULL,
    name VARCHAR(255), -- e.g. "Table 4" or "John's Tab"
    table_number VARCHAR(50),
    state JSONB NOT NULL DEFAULT '{}'::jsonb, -- The serialized cart state
    created_by UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    
    FOREIGN KEY (tenant_id) REFERENCES public.tenants(id),
    FOREIGN KEY (outlet_id) REFERENCES public.outlets(id)
);

-- Receipt Archives (Sequential Receipt Strategy)
CREATE TABLE public.receipt_archives (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    outlet_id UUID NOT NULL,
    order_id UUID NOT NULL,
    receipt_number VARCHAR(255) NOT NULL, -- Hybrid ID: OUTLET-REG-DATE-SEQ
    receipt_html TEXT, -- Cached HTML/Text payload for instant re-printing
    printed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    printed_by UUID,
    
    FOREIGN KEY (tenant_id) REFERENCES public.tenants(id),
    FOREIGN KEY (outlet_id) REFERENCES public.outlets(id)
);

-- RLS Policies
ALTER TABLE public.cash_registers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cash_shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.draft_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.receipt_archives ENABLE ROW LEVEL SECURITY;

CREATE POLICY cr_isolation ON public.cash_registers FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY cs_isolation ON public.cash_shifts FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY do_isolation ON public.draft_orders FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY ra_isolation ON public.receipt_archives FOR ALL USING (tenant_id = public.get_current_tenant_id());

-- Audit Triggers
CREATE TRIGGER trg_audit_cash_registers AFTER INSERT OR UPDATE OR DELETE ON public.cash_registers FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();
CREATE TRIGGER trg_audit_cash_shifts AFTER INSERT OR UPDATE OR DELETE ON public.cash_shifts FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();
CREATE TRIGGER trg_audit_draft_orders AFTER INSERT OR UPDATE OR DELETE ON public.draft_orders FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

-- Indexes
CREATE INDEX idx_cash_registers_tenant ON public.cash_registers(tenant_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_cash_shifts_tenant ON public.cash_shifts(tenant_id);
CREATE INDEX idx_draft_orders_tenant ON public.draft_orders(tenant_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_receipt_archives_tenant ON public.receipt_archives(tenant_id);
