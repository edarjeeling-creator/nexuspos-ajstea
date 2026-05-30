-- ==============================================================================
-- Migration: 00010_accounting
-- Description: Chart of Accounts and Double-Entry General Ledger.
-- ==============================================================================

-- NOTE: Future migrations will introduce `accounting_periods` to handle 
-- fiscal years, period closures, and retained earnings roll-forward.

-- 1. ACCOUNTS (Chart of Accounts)
-- ------------------------------------------------------------------------------
-- NOTE: Application initialization should seed system accounts (e.g., Accounts Receivable, 
-- Accounts Payable, Sales Tax, Retained Earnings) and mark them with `is_system_account = true`.
CREATE TABLE IF NOT EXISTS public.accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    parent_id UUID REFERENCES public.accounts(id) ON DELETE SET NULL,
    account_code VARCHAR(100) NOT NULL,
    name VARCHAR(255) NOT NULL,
    account_type VARCHAR(50) NOT NULL CHECK (account_type IN ('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE')),
    normal_balance VARCHAR(50) NOT NULL CHECK (normal_balance IN ('DEBIT', 'CREDIT')),
    is_system_account BOOLEAN DEFAULT false,
    is_tax_account BOOLEAN DEFAULT false,
    description TEXT,
    status VARCHAR(50) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(tenant_id, account_code)
);
COMMENT ON TABLE public.accounts IS 'Standard Chart of Accounts (COA) for double-entry bookkeeping.';

CREATE INDEX IF NOT EXISTS idx_accounts_tenant_id ON public.accounts(tenant_id);
CREATE INDEX IF NOT EXISTS idx_accounts_parent_id ON public.accounts(parent_id);
CREATE INDEX IF NOT EXISTS idx_accounts_active ON public.accounts(tenant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_accounts_updated_at
BEFORE UPDATE ON public.accounts
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_accounts
AFTER INSERT OR UPDATE OR DELETE ON public.accounts
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;

CREATE POLICY accounts_isolation_policy ON public.accounts
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- 2. JOURNAL ENTRIES
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.journal_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    outlet_id UUID REFERENCES public.outlets(id) ON DELETE SET NULL, -- Optional context
    reversal_entry_id UUID REFERENCES public.journal_entries(id) ON DELETE SET NULL,
    entry_number VARCHAR(100) NOT NULL,
    entry_date DATE NOT NULL DEFAULT CURRENT_DATE,
    description TEXT,
    source_module VARCHAR(50) NOT NULL CHECK (source_module IN ('POS', 'INVENTORY', 'PROCUREMENT', 'PAYROLL', 'MANUAL', 'SYSTEM')),
    reference_type VARCHAR(100) CHECK (reference_type IN ('ORDER', 'PURCHASE_ORDER', 'PAYMENT', 'PAYROLL', 'INVENTORY_ADJUSTMENT', 'MANUAL')),
    reference_id UUID,
    currency VARCHAR(10) DEFAULT 'INR',
    status VARCHAR(50) NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'POSTED', 'VOIDED')),
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    posted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    posted_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(tenant_id, entry_number)
);
COMMENT ON TABLE public.journal_entries IS 'Header records for all accounting journal transactions.';

CREATE INDEX IF NOT EXISTS idx_journal_entries_tenant_id ON public.journal_entries(tenant_id);
CREATE INDEX IF NOT EXISTS idx_journal_entries_date ON public.journal_entries(tenant_id, entry_date);
CREATE INDEX IF NOT EXISTS idx_journal_entries_active ON public.journal_entries(tenant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_journal_entries_updated_at
BEFORE UPDATE ON public.journal_entries
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_journal_entries
AFTER INSERT OR UPDATE OR DELETE ON public.journal_entries
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.journal_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY journal_entries_isolation_policy ON public.journal_entries
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- 3. JOURNAL LINES
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.journal_lines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    journal_entry_id UUID NOT NULL REFERENCES public.journal_entries(id) ON DELETE CASCADE,
    account_id UUID NOT NULL REFERENCES public.accounts(id) ON DELETE RESTRICT,
    line_number INT NOT NULL CHECK (line_number > 0),
    cost_center VARCHAR(100),
    debit DECIMAL(14,2) NOT NULL DEFAULT 0 CHECK (debit >= 0),
    credit DECIMAL(14,2) NOT NULL DEFAULT 0 CHECK (credit >= 0),
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT chk_debit_credit_mutex CHECK (
        (debit > 0 AND credit = 0) OR (credit > 0 AND debit = 0) OR (debit = 0 AND credit = 0)
    ),
    UNIQUE(tenant_id, journal_entry_id, line_number)
);
COMMENT ON TABLE public.journal_lines IS 'Individual debit/credit lines.';

CREATE INDEX IF NOT EXISTS idx_journal_lines_tenant_id ON public.journal_lines(tenant_id);
CREATE INDEX IF NOT EXISTS idx_journal_lines_entry_id ON public.journal_lines(journal_entry_id);
CREATE INDEX IF NOT EXISTS idx_journal_lines_account_id ON public.journal_lines(account_id);
CREATE INDEX IF NOT EXISTS idx_journal_lines_active ON public.journal_lines(tenant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_journal_lines_updated_at
BEFORE UPDATE ON public.journal_lines
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_journal_lines
AFTER INSERT OR UPDATE OR DELETE ON public.journal_lines
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.journal_lines ENABLE ROW LEVEL SECURITY;

CREATE POLICY journal_lines_isolation_policy ON public.journal_lines
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- 4. ACCOUNTING TRIGGERS (IMMUTABILITY AND BALANCING)
-- ------------------------------------------------------------------------------
-- A. Prevent modification of posted entries
CREATE OR REPLACE FUNCTION public.prevent_posted_modification()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status = 'POSTED' THEN
        -- Allow updates only to transition to VOIDED or setting reversal_entry_id
        IF NEW.status = 'VOIDED' OR NEW.reversal_entry_id IS NOT NULL THEN
            RETURN NEW;
        END IF;
        RAISE EXCEPTION 'Cannot modify a POSTED journal entry';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_posted_modification
BEFORE UPDATE ON public.journal_entries
FOR EACH ROW EXECUTE FUNCTION public.prevent_posted_modification();

-- B. Validate double-entry balance on POST
CREATE OR REPLACE FUNCTION public.validate_journal_balance()
RETURNS TRIGGER AS $$
DECLARE
    total_debits DECIMAL(14,2);
    total_credits DECIMAL(14,2);
BEGIN
    IF NEW.status = 'POSTED' THEN
        SELECT COALESCE(SUM(debit), 0), COALESCE(SUM(credit), 0)
        INTO total_debits, total_credits
        FROM public.journal_lines
        WHERE journal_entry_id = NEW.id AND deleted_at IS NULL;

        IF total_debits != total_credits THEN
            RAISE EXCEPTION 'Journal entry does not balance. Debits: %, Credits: %', total_debits, total_credits;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_journal_balance
BEFORE UPDATE OF status ON public.journal_entries
FOR EACH ROW
WHEN (NEW.status = 'POSTED' AND (OLD.status IS DISTINCT FROM NEW.status))
EXECUTE FUNCTION public.validate_journal_balance();


-- ==============================================================================
-- ROLLBACK INSTRUCTIONS
-- ==============================================================================
/*
DROP TRIGGER IF EXISTS trg_validate_journal_balance ON public.journal_entries;
DROP FUNCTION IF EXISTS public.validate_journal_balance();
DROP TRIGGER IF EXISTS trg_prevent_posted_modification ON public.journal_entries;
DROP FUNCTION IF EXISTS public.prevent_posted_modification();

DROP POLICY IF EXISTS journal_lines_isolation_policy ON public.journal_lines;
DROP POLICY IF EXISTS journal_entries_isolation_policy ON public.journal_entries;
DROP POLICY IF EXISTS accounts_isolation_policy ON public.accounts;

DROP TABLE IF EXISTS public.journal_lines CASCADE;
DROP TABLE IF EXISTS public.journal_entries CASCADE;
DROP TABLE IF EXISTS public.accounts CASCADE;
*/
