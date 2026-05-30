-- ==============================================================================
-- Migration: 00021_crm_loyalty
-- Description: CRM & Loyalty Ledger, Tiers, Segmentation, and Visit Tracking
-- ==============================================================================

-- 1. CUSTOMER TABLE EXTENSIONS
-- ------------------------------------------------------------------------------
ALTER TABLE public.customers ADD COLUMN loyalty_tier VARCHAR(50) DEFAULT 'BRONZE' CHECK (loyalty_tier IN ('BRONZE', 'SILVER', 'GOLD', 'PLATINUM', 'VIP'));
ALTER TABLE public.customers ADD COLUMN total_visits INT DEFAULT 0 CHECK (total_visits >= 0);
ALTER TABLE public.customers ADD COLUMN customer_segment VARCHAR(100) DEFAULT 'NEW';
ALTER TABLE public.customers ADD COLUMN current_points_balance INT DEFAULT 0;

-- 2. CUSTOMER LOYALTY LEDGER
-- ------------------------------------------------------------------------------
CREATE TABLE public.customer_loyalty_ledger (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    outlet_id UUID REFERENCES public.outlets(id),
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
    transaction_type VARCHAR(50) NOT NULL CHECK (transaction_type IN ('EARN', 'BURN', 'ADJUSTMENT', 'EXPIRE')),
    points INT NOT NULL, -- positive for earn, negative for burn
    reference_type VARCHAR(50), -- e.g., 'ORDER', 'PROMOTION'
    reference_id UUID,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID
);

-- 3. NEGATIVE BALANCE PROTECTION & CACHE UPDATER
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION protect_and_update_loyalty_balance()
RETURNS TRIGGER AS $$
DECLARE
    v_new_balance INT;
BEGIN
    -- Calculate the theoretical new balance for this customer
    SELECT COALESCE(SUM(points), 0) + NEW.points INTO v_new_balance
    FROM public.customer_loyalty_ledger
    WHERE customer_id = NEW.customer_id;

    -- Enforce strict negative balance protection
    IF v_new_balance < 0 THEN
        RAISE EXCEPTION 'Insufficient loyalty points. Attempted to burn % points, but balance would drop to %.', ABS(NEW.points), v_new_balance;
    END IF;

    -- Update the cached balance on the customer table
    UPDATE public.customers 
    SET current_points_balance = v_new_balance
    WHERE id = NEW.customer_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_loyalty_ledger_protection
BEFORE INSERT ON public.customer_loyalty_ledger
FOR EACH ROW EXECUTE FUNCTION protect_and_update_loyalty_balance();


-- 4. AUTO-EARN POINTS & VISIT TRACKING ON ORDER CREATED
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION crm_process_order()
RETURNS TRIGGER AS $$
DECLARE
    v_customer_id UUID;
    v_total_amount DECIMAL;
    v_points_earned INT;
BEGIN
    IF NEW.event_type = 'ORDER_CREATED' THEN
        v_customer_id := (NEW.payload->>'customer_id')::UUID;
        v_total_amount := (NEW.payload->>'total_amount')::DECIMAL;
        
        IF v_customer_id IS NOT NULL THEN
            -- Increment visit count
            UPDATE public.customers 
            SET total_visits = total_visits + 1,
                last_visit_date = NEW.created_at
            WHERE id = v_customer_id;

            -- Calculate standard points (e.g. 1 point per $1 spent)
            v_points_earned := FLOOR(v_total_amount);
            
            IF v_points_earned > 0 THEN
                INSERT INTO public.customer_loyalty_ledger (
                    tenant_id, outlet_id, customer_id, transaction_type, points, reference_type, reference_id, notes
                ) VALUES (
                    NEW.tenant_id, NEW.outlet_id, v_customer_id, 'EARN', v_points_earned, 'ORDER', NEW.order_id, 'Auto-earn from order'
                );
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_crm_process_order
AFTER INSERT ON public.order_events
FOR EACH ROW EXECUTE FUNCTION crm_process_order();

-- RLS
ALTER TABLE public.customer_loyalty_ledger ENABLE ROW LEVEL SECURITY;
CREATE POLICY cll_isolation ON public.customer_loyalty_ledger FOR ALL USING (tenant_id = public.get_current_tenant_id());
