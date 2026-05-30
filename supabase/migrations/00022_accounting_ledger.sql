-- ==============================================================================
-- Migration: 00022_accounting_ledger
-- Description: Automated Journal Entries, COA, and Double-Entry Validation
-- ==============================================================================

-- 1. CHART OF ACCOUNTS (COA)
-- ------------------------------------------------------------------------------
CREATE TABLE public.chart_of_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    account_code VARCHAR(50) NOT NULL,
    name VARCHAR(255) NOT NULL,
    account_type VARCHAR(50) NOT NULL CHECK (account_type IN ('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE', 'COGS')),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, account_code)
);

-- 2. ACCOUNTING EVENTS (Bridge Table)
-- ------------------------------------------------------------------------------
CREATE TABLE public.accounting_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    event_type VARCHAR(100) NOT NULL CHECK (event_type IN ('SALES', 'INVENTORY_CONSUMPTION', 'GRN_POSTING', 'WASTE_POSTING', 'REFUND')),
    reference_id UUID NOT NULL, -- Points to order_id, grn_id, etc.
    event_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status VARCHAR(50) DEFAULT 'PROCESSED' CHECK (status IN ('PENDING', 'PROCESSED', 'FAILED')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. JOURNAL ENTRIES
-- ------------------------------------------------------------------------------
CREATE TABLE public.journal_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    accounting_event_id UUID REFERENCES public.accounting_events(id) ON DELETE CASCADE,
    entry_number VARCHAR(100) NOT NULL,
    entry_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    description TEXT,
    status VARCHAR(50) DEFAULT 'POSTED' CHECK (status IN ('DRAFT', 'POSTED', 'VOIDED')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, entry_number)
);

-- 4. JOURNAL LINES (Double-Entry)
-- ------------------------------------------------------------------------------
CREATE TABLE public.journal_lines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    journal_entry_id UUID NOT NULL REFERENCES public.journal_entries(id) ON DELETE CASCADE,
    account_id UUID NOT NULL REFERENCES public.chart_of_accounts(id),
    debit DECIMAL(15,2) DEFAULT 0 CHECK (debit >= 0),
    credit DECIMAL(15,2) DEFAULT 0 CHECK (credit >= 0),
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    -- Ensure line cannot have both debit and credit
    CONSTRAINT chk_debit_credit_mutually_exclusive CHECK ((debit > 0 AND credit = 0) OR (credit > 0 AND debit = 0) OR (debit = 0 AND credit = 0))
);

-- 5. STRICT DOUBLE-ENTRY VALIDATION
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION validate_double_entry()
RETURNS TRIGGER AS $$
DECLARE
    v_total_debit DECIMAL;
    v_total_credit DECIMAL;
    v_status VARCHAR;
BEGIN
    -- We only validate when a journal entry status changes to POSTED (or when lines are modified on a POSTED entry)
    -- This allows DRAFT entries to be temporarily unbalanced during creation
    
    SELECT status INTO v_status FROM public.journal_entries WHERE id = NEW.journal_entry_id;
    
    IF v_status = 'POSTED' THEN
        SELECT COALESCE(SUM(debit), 0), COALESCE(SUM(credit), 0)
        INTO v_total_debit, v_total_credit
        FROM public.journal_lines
        WHERE journal_entry_id = NEW.journal_entry_id;
        
        -- Include the current row being inserted/updated in the sum calculation logic correctly
        -- Note: For an AFTER trigger doing aggregate sum, the NEW row is already in the table.
        IF v_total_debit != v_total_credit THEN
            RAISE EXCEPTION 'Double-entry validation failed. Debits (%) must equal Credits (%).', v_total_debit, v_total_credit;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- To truly validate at the entry level, we use an AFTER trigger
-- WARNING: In a production environment, deferred constraint triggers are safer for multi-row inserts.
CREATE CONSTRAINT TRIGGER trg_validate_journal
AFTER INSERT OR UPDATE ON public.journal_lines
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION validate_double_entry();

-- RLS
ALTER TABLE public.chart_of_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.accounting_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journal_lines ENABLE ROW LEVEL SECURITY;

CREATE POLICY coa_isolation ON public.chart_of_accounts FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY ae_isolation ON public.accounting_events FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY je_isolation ON public.journal_entries FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY jl_isolation ON public.journal_lines FOR ALL USING (tenant_id = public.get_current_tenant_id());
