-- ==============================================================================
-- Migration: 00023_ai_forecasting
-- Description: Historical Forecasting, Predictive Analytics
-- ==============================================================================

-- 1. AI FORECASTS TABLE
-- ------------------------------------------------------------------------------
CREATE TABLE public.ai_forecasts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    outlet_id UUID REFERENCES public.outlets(id) ON DELETE CASCADE,
    forecast_type VARCHAR(50) NOT NULL CHECK (forecast_type IN ('SALES', 'CUSTOMERS', 'INVENTORY_USAGE')),
    target_date DATE NOT NULL,
    metric_name VARCHAR(100) NOT NULL, -- e.g., 'Total Revenue', 'Burger Buns Usage'
    predicted_value DECIMAL(15,2) NOT NULL,
    confidence_interval_low DECIMAL(15,2),
    confidence_interval_high DECIMAL(15,2),
    model_version VARCHAR(50) DEFAULT 'v1.0-historical',
    weather_impact_factor DECIMAL(5,2), -- Prepared for future integration
    local_event_flag BOOLEAN DEFAULT false, -- Prepared for future integration
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, outlet_id, forecast_type, target_date, metric_name)
);

-- 2. AI FORECAST FEATURES (Prepared Architecture)
-- ------------------------------------------------------------------------------
-- Tracks external features that feed into the AI model for a specific date
CREATE TABLE public.ai_forecast_features (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    outlet_id UUID REFERENCES public.outlets(id) ON DELETE CASCADE,
    target_date DATE NOT NULL,
    weather_condition VARCHAR(100),
    temperature_high DECIMAL(5,2),
    temperature_low DECIMAL(5,2),
    is_holiday BOOLEAN DEFAULT false,
    local_event_name VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, outlet_id, target_date)
);

-- RLS
ALTER TABLE public.ai_forecasts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_forecast_features ENABLE ROW LEVEL SECURITY;

CREATE POLICY aif_isolation ON public.ai_forecasts FOR ALL USING (tenant_id = public.get_current_tenant_id());
CREATE POLICY aiff_isolation ON public.ai_forecast_features FOR ALL USING (tenant_id = public.get_current_tenant_id());
