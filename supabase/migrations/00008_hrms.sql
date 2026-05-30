-- ==============================================================================
-- Migration: 00008_hrms
-- Description: Human Resource Management System (Employees, Attendance).
-- ==============================================================================

-- 1. EMPLOYEES
-- ------------------------------------------------------------------------------
-- NOTE: Future migrations may introduce `employee_outlet_history` to track
-- reassignments across multiple outlets over time.
CREATE TABLE IF NOT EXISTS public.employees (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    outlet_id UUID REFERENCES public.outlets(id) ON DELETE SET NULL,
    profile_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL, -- Mapping to auth/login if they have system access
    manager_employee_id UUID REFERENCES public.employees(id) ON DELETE SET NULL,
    employee_code VARCHAR(100),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    full_name VARCHAR(255) GENERATED ALWAYS AS (
        TRIM(COALESCE(first_name, '') || ' ' || COALESCE(last_name, ''))
    ) STORED,
    email VARCHAR(255),
    phone VARCHAR(50),
    designation VARCHAR(100),
    department VARCHAR(100),
    cost_center VARCHAR(100),
    employment_type VARCHAR(50) DEFAULT 'FULL_TIME' CHECK (employment_type IN ('FULL_TIME', 'PART_TIME', 'CONTRACT', 'SEASONAL')),
    status VARCHAR(50) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'ON_LEAVE', 'SUSPENDED', 'TERMINATED')),
    hire_date DATE,
    probation_end_date DATE,
    termination_date DATE,
    hourly_rate DECIMAL(10,2) DEFAULT 0 CHECK (hourly_rate >= 0),
    monthly_salary DECIMAL(12,2) DEFAULT 0 CHECK (monthly_salary >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(tenant_id, profile_id),
    CONSTRAINT chk_term_date CHECK (termination_date IS NULL OR termination_date >= hire_date)
);
COMMENT ON TABLE public.employees IS 'Core HR table tracking staff details and employment status.';

CREATE INDEX IF NOT EXISTS idx_employees_tenant_id ON public.employees(tenant_id);
CREATE INDEX IF NOT EXISTS idx_employees_outlet_id ON public.employees(outlet_id);
CREATE INDEX IF NOT EXISTS idx_employees_manager_id ON public.employees(manager_employee_id);
CREATE INDEX IF NOT EXISTS idx_employees_active ON public.employees(tenant_id) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_employees_code ON public.employees(tenant_id, employee_code) WHERE deleted_at IS NULL AND employee_code IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_employees_email ON public.employees(tenant_id, email) WHERE deleted_at IS NULL AND email IS NOT NULL;

CREATE TRIGGER set_employees_updated_at
BEFORE UPDATE ON public.employees
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_employees
AFTER INSERT OR UPDATE OR DELETE ON public.employees
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;

CREATE POLICY employees_isolation_policy ON public.employees
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- 2. ATTENDANCE
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    outlet_id UUID REFERENCES public.outlets(id) ON DELETE SET NULL,
    employee_id UUID NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
    shift_date DATE NOT NULL,
    shift_name VARCHAR(100), -- E.g., 'MORNING', 'EVENING', 'NIGHT'
    clock_in_time TIMESTAMP WITH TIME ZONE,
    clock_out_time TIMESTAMP WITH TIME ZONE,
    -- NOTE: total_hours acts as a cached calculation (clock_out - clock_in) to speed up payroll queries.
    total_hours DECIMAL(5,2) DEFAULT 0 CHECK (total_hours >= 0),
    attendance_source VARCHAR(50) DEFAULT 'POS' CHECK (attendance_source IN ('POS', 'WEB', 'APP', 'BIOMETRIC', 'MANUAL')),
    status VARCHAR(50) DEFAULT 'PRESENT' CHECK (status IN ('PRESENT', 'ABSENT', 'LATE', 'HALF_DAY', 'ON_LEAVE', 'HOLIDAY')),
    approved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    approved_at TIMESTAMP WITH TIME ZONE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT chk_clock_times CHECK (clock_out_time IS NULL OR clock_out_time >= clock_in_time)
);
COMMENT ON TABLE public.attendance IS 'Daily time-tracking and attendance logs for employees.';

CREATE INDEX IF NOT EXISTS idx_attendance_tenant_id ON public.attendance(tenant_id);
CREATE INDEX IF NOT EXISTS idx_attendance_employee ON public.attendance(employee_id);
CREATE INDEX IF NOT EXISTS idx_attendance_date ON public.attendance(tenant_id, shift_date);
CREATE INDEX IF NOT EXISTS idx_attendance_active ON public.attendance(tenant_id) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_attendance_unique_shift ON public.attendance(tenant_id, employee_id, shift_date) WHERE deleted_at IS NULL;

CREATE TRIGGER set_attendance_updated_at
BEFORE UPDATE ON public.attendance
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_attendance
AFTER INSERT OR UPDATE OR DELETE ON public.attendance
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;

CREATE POLICY attendance_isolation_policy ON public.attendance
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- ==============================================================================
-- ROLLBACK INSTRUCTIONS
-- ==============================================================================
/*
DROP POLICY IF EXISTS attendance_isolation_policy ON public.attendance;
DROP POLICY IF EXISTS employees_isolation_policy ON public.employees;

DROP TABLE IF EXISTS public.attendance CASCADE;
DROP TABLE IF EXISTS public.employees CASCADE;
*/
