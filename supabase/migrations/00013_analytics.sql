-- ==============================================================================
-- Migration: 00013_analytics
-- Description: Dashboards, Reports, and Aggregated Metrics.
-- ==============================================================================

-- NOTE: In the future, as data volume grows, we will likely migrate these analytics 
-- tables and views to a dedicated OLAP database like ClickHouse to offload 
-- heavy aggregation workloads from PostgreSQL.

-- NOTE: Future migrations will introduce `analytics_events` to capture 
-- granular user and system telemetry events.

-- 1. DAILY SALES AGGREGATES
-- ------------------------------------------------------------------------------
-- NOTE: Populated by a nightly CRON job or pg_cron to prevent real-time analytical queries 
-- from impacting POS transaction performance.
-- NOTE: Future migrations will introduce `daily_inventory_aggregates` for stock trending.
-- NOTE: Future migrations will introduce daily profitability metrics (combining COGS and OPEX).
CREATE TABLE IF NOT EXISTS public.daily_sales_aggregates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    outlet_id UUID REFERENCES public.outlets(id) ON DELETE CASCADE,
    report_date DATE NOT NULL,
    total_orders INT NOT NULL DEFAULT 0 CHECK (total_orders >= 0),
    total_sales DECIMAL(15,2) NOT NULL DEFAULT 0 CHECK (total_sales >= 0),
    total_tax DECIMAL(15,2) NOT NULL DEFAULT 0 CHECK (total_tax >= 0),
    total_discount DECIMAL(15,2) NOT NULL DEFAULT 0 CHECK (total_discount >= 0),
    guest_count INT NOT NULL DEFAULT 0 CHECK (guest_count >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(tenant_id, outlet_id, report_date)
);
COMMENT ON TABLE public.daily_sales_aggregates IS 'Pre-calculated daily sales metrics to power fast dashboard rendering.';

CREATE INDEX IF NOT EXISTS idx_sales_agg_tenant_id ON public.daily_sales_aggregates(tenant_id);
CREATE INDEX IF NOT EXISTS idx_sales_agg_outlet_id ON public.daily_sales_aggregates(outlet_id);
CREATE INDEX IF NOT EXISTS idx_sales_agg_date ON public.daily_sales_aggregates(tenant_id, report_date);
CREATE INDEX IF NOT EXISTS idx_sales_agg_active ON public.daily_sales_aggregates(tenant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_sales_agg_updated_at
BEFORE UPDATE ON public.daily_sales_aggregates
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Aggregates don't typically need heavy auditing, but to maintain the 15-point rule:
CREATE TRIGGER audit_daily_sales_aggregates
AFTER INSERT OR UPDATE OR DELETE ON public.daily_sales_aggregates
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.daily_sales_aggregates ENABLE ROW LEVEL SECURITY;

CREATE POLICY sales_aggregates_isolation_policy ON public.daily_sales_aggregates
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- 2. REPORTS CONFIGURATION
-- ------------------------------------------------------------------------------
-- NOTE: Future migrations will introduce `report_executions` to track when reports 
-- are run and cache their heavy computational results.
-- NOTE: Future support will be added for diverse export formats (e.g. PDF, CSV, EXCEL) 
-- defined within the report configuration.
CREATE TABLE IF NOT EXISTS public.reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    report_type VARCHAR(50) NOT NULL CHECK (report_type IN ('SALES', 'INVENTORY', 'FINANCE', 'HR', 'CUSTOM')),
    query_configuration JSONB NOT NULL, -- The structure or identifiers of what to query
    schedule_cron VARCHAR(100), -- E.g., '0 0 * * *' for daily
    status VARCHAR(50) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE', 'ARCHIVED')),
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);
COMMENT ON TABLE public.reports IS 'Configurations and schedules for custom tenant reports.';

CREATE INDEX IF NOT EXISTS idx_reports_tenant_id ON public.reports(tenant_id);
CREATE INDEX IF NOT EXISTS idx_reports_active ON public.reports(tenant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_reports_updated_at
BEFORE UPDATE ON public.reports
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_reports
AFTER INSERT OR UPDATE OR DELETE ON public.reports
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY reports_isolation_policy ON public.reports
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- 3. DASHBOARDS
-- ------------------------------------------------------------------------------
-- NOTE: Future migrations will extract `dashboard_widgets` into a separate table 
-- to allow fine-grained widget reusability across multiple dashboards.
-- NOTE: Future updates will introduce dashboard scope support (e.g., GLOBAL, OUTLET-SPECIFIC, USER-SPECIFIC).
CREATE TABLE IF NOT EXISTS public.dashboards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    layout JSONB NOT NULL, -- Grid layouts, widget configurations
    is_default BOOLEAN DEFAULT false,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);
COMMENT ON TABLE public.dashboards IS 'User or tenant-specific analytical dashboard layouts.';

CREATE INDEX IF NOT EXISTS idx_dashboards_tenant_id ON public.dashboards(tenant_id);
CREATE INDEX IF NOT EXISTS idx_dashboards_active ON public.dashboards(tenant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_dashboards_updated_at
BEFORE UPDATE ON public.dashboards
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_dashboards
AFTER INSERT OR UPDATE OR DELETE ON public.dashboards
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.dashboards ENABLE ROW LEVEL SECURITY;

CREATE POLICY dashboards_isolation_policy ON public.dashboards
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- ==============================================================================
-- ROLLBACK INSTRUCTIONS
-- ==============================================================================
/*
DROP POLICY IF EXISTS dashboards_isolation_policy ON public.dashboards;
DROP POLICY IF EXISTS reports_isolation_policy ON public.reports;
DROP POLICY IF EXISTS sales_aggregates_isolation_policy ON public.daily_sales_aggregates;

DROP TABLE IF EXISTS public.dashboards CASCADE;
DROP TABLE IF EXISTS public.reports CASCADE;
DROP TABLE IF EXISTS public.daily_sales_aggregates CASCADE;
*/
