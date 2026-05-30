-- ==============================================================================
-- Migration: 00029_reporting_suite
-- Description: OLAP Data Warehousing, Materialized Views, and Scheduled Reports
-- ==============================================================================

-- 1. DEDICATED REPORTING SCHEMA
-- ------------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS reporting;

-- 2. MATERIALIZED VIEWS (Pre-aggregated for Dashboard Speed)
-- ------------------------------------------------------------------------------

-- 2A. Daily Sales Aggregation
CREATE MATERIALIZED VIEW reporting.mv_daily_sales AS
SELECT 
    o.tenant_id,
    o.outlet_id,
    DATE(o.created_at) AS sales_date,
    COUNT(o.id) AS total_orders,
    SUM((o.payload->>'total_amount')::DECIMAL) AS total_revenue,
    SUM((o.payload->>'tax_amount')::DECIMAL) AS total_tax,
    AVG((o.payload->>'total_amount')::DECIMAL) AS average_ticket_size
FROM public.order_events o
WHERE o.event_type = 'ORDER_CREATED'
GROUP BY o.tenant_id, o.outlet_id, DATE(o.created_at);

-- 2B. Financials & P&L Rollup
CREATE MATERIALIZED VIEW reporting.mv_financials AS
SELECT 
    jl.tenant_id,
    DATE(je.entry_date) AS entry_date,
    coa.account_type,
    SUM(jl.credit) - SUM(jl.debit) AS net_balance -- Standard accounting rollup logic
FROM public.journal_lines jl
JOIN public.journal_entries je ON jl.journal_entry_id = je.id
JOIN public.chart_of_accounts coa ON jl.account_id = coa.id
WHERE je.status = 'POSTED'
GROUP BY jl.tenant_id, DATE(je.entry_date), coa.account_type;

-- 2C. Kitchen Performance (KDS)
CREATE MATERIALIZED VIEW reporting.mv_kds AS
SELECT 
    kt.tenant_id,
    kt.outlet_id,
    DATE(kt.created_at) AS kds_date,
    kt.kitchen_station_id,
    COUNT(kt.id) AS tickets_processed,
    AVG(EXTRACT(EPOCH FROM (kt.ready_at - kt.prep_started_at))/60) AS avg_prep_time_minutes,
    COUNT(CASE WHEN EXTRACT(EPOCH FROM (kt.ready_at - kt.prep_started_at))/60 > 15 THEN 1 END) AS sla_breaches
FROM public.kitchen_tickets kt
WHERE kt.status IN ('READY', 'SERVED')
GROUP BY kt.tenant_id, kt.outlet_id, DATE(kt.created_at), kt.kitchen_station_id;

-- 2D. Inventory Actual vs Theoretical & Waste
CREATE MATERIALIZED VIEW reporting.mv_inventory AS
SELECT 
    it.tenant_id,
    it.outlet_id,
    DATE(it.created_at) AS inventory_date,
    SUM(CASE WHEN it.transaction_type = 'WASTE_RECORDED' THEN ABS(it.quantity) ELSE 0 END) AS total_waste_qty,
    SUM(CASE WHEN it.transaction_type = 'SHRINKAGE' THEN ABS(it.quantity) ELSE 0 END) AS total_shrinkage_qty,
    SUM(CASE WHEN it.transaction_type = 'OVERPORTIONING' THEN ABS(it.quantity) ELSE 0 END) AS total_overportioning_qty
FROM public.inventory_transactions it
GROUP BY it.tenant_id, it.outlet_id, DATE(it.created_at);

-- Indexes to speed up MV queries
CREATE UNIQUE INDEX idx_mv_sales ON reporting.mv_daily_sales (tenant_id, outlet_id, sales_date);
CREATE UNIQUE INDEX idx_mv_fin ON reporting.mv_financials (tenant_id, entry_date, account_type);
CREATE UNIQUE INDEX idx_mv_kds ON reporting.mv_kds (tenant_id, outlet_id, kds_date, kitchen_station_id);
CREATE UNIQUE INDEX idx_mv_inv ON reporting.mv_inventory (tenant_id, outlet_id, inventory_date);


-- 3. SCHEDULED REPORTS ENGINE
-- ------------------------------------------------------------------------------
CREATE TABLE reporting.scheduled_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    report_name VARCHAR(255) NOT NULL,
    report_type VARCHAR(50) NOT NULL CHECK (report_type IN ('PNL', 'FOOD_COST', 'SALES_SUMMARY', 'KDS_PERFORMANCE')),
    format VARCHAR(20) DEFAULT 'PDF' CHECK (format IN ('PDF', 'CSV', 'EXCEL')),
    schedule_cron VARCHAR(100) NOT NULL, -- e.g., '0 2 * * *' for 2 AM daily
    recipient_emails JSONB NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE reporting.report_executions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    scheduled_report_id UUID REFERENCES reporting.scheduled_reports(id) ON DELETE CASCADE,
    execution_time TIMESTAMPTZ DEFAULT NOW(),
    status VARCHAR(50) DEFAULT 'PROCESSING' CHECK (status IN ('PROCESSING', 'SUCCESS', 'FAILED')),
    file_url TEXT, -- Link to S3/Supabase Storage bucket
    error_message TEXT
);


-- 4. FORECAST ACCURACY TRACKING (AI Audit)
-- ------------------------------------------------------------------------------
CREATE TABLE reporting.forecast_accuracy (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    forecast_id UUID REFERENCES public.ai_forecasts(id) ON DELETE CASCADE,
    target_date DATE NOT NULL,
    metric_name VARCHAR(100) NOT NULL,
    predicted_value DECIMAL(15,2) NOT NULL,
    actual_value DECIMAL(15,2) NOT NULL,
    variance_value DECIMAL(15,2) NOT NULL,
    accuracy_percentage DECIMAL(5,2) NOT NULL, -- ABS(Actual - Predicted) / Actual
    calculated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Note: In Supabase, Row Level Security (RLS) is not supported on Materialized Views.
-- To enforce tenant isolation on MVs, we will strictly wrap access in Secure RPC functions 
-- or edge functions that explicitly append "WHERE tenant_id = current_tenant_id()".
-- However, we CAN apply RLS to the underlying standard tables.

ALTER TABLE reporting.scheduled_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE reporting.report_executions ENABLE ROW LEVEL SECURITY;
ALTER TABLE reporting.forecast_accuracy ENABLE ROW LEVEL SECURITY;

CREATE POLICY sr_isolation ON reporting.scheduled_reports FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY re_isolation ON reporting.report_executions FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY fa_isolation ON reporting.forecast_accuracy FOR ALL USING (tenant_id = public.get_current_tenant_id());
