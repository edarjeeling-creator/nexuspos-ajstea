-- ==============================================================================
-- Migration: 00002_auth_rbac
-- Description: Supabase Auth integration, Profiles, and strict Role-Based Access Control.
-- ==============================================================================

-- 1. PROFILES (Linked to auth.users)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    tenant_id UUID REFERENCES public.tenants(id) ON DELETE RESTRICT,
    outlet_id UUID REFERENCES public.outlets(id) ON DELETE SET NULL,
    full_name VARCHAR(255),
    phone VARCHAR(50),
    status VARCHAR(50) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);
COMMENT ON TABLE public.profiles IS 'System users, mapped 1-to-1 with Supabase auth.users.';

CREATE INDEX IF NOT EXISTS idx_profiles_tenant_id ON public.profiles(tenant_id);
CREATE INDEX IF NOT EXISTS idx_profiles_outlet_id ON public.profiles(outlet_id);
CREATE INDEX IF NOT EXISTS idx_profiles_active ON public.profiles(tenant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_profiles_updated_at
BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_profiles
AFTER INSERT OR UPDATE OR DELETE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY profiles_isolation_policy ON public.profiles
    FOR ALL USING (tenant_id = public.get_current_tenant_id());


-- 2. REPLACE TENANT LOOKUP FUNCTION & ADD OUTLET LOOKUP
-- ------------------------------------------------------------------------------
-- Overwrite the stub from 00001 with secure implementation.
CREATE OR REPLACE FUNCTION public.get_current_tenant_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT public.profiles.tenant_id 
    FROM public.profiles 
    WHERE public.profiles.id = auth.uid();
$$;

-- Add outlet lookup for finer granularity.
CREATE OR REPLACE FUNCTION public.get_current_outlet_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT public.profiles.outlet_id 
    FROM public.profiles 
    WHERE public.profiles.id = auth.uid();
$$;


-- 3. RBAC (Role-Based Access Control)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE, -- NULL for system/global roles
    parent_role_id UUID REFERENCES public.roles(id) ON DELETE SET NULL, -- Role inheritance
    name VARCHAR(100) NOT NULL,
    description TEXT,
    status VARCHAR(50) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(tenant_id, name)
);
COMMENT ON TABLE public.roles IS 'Tenant-specific and global user roles with optional inheritance.';

CREATE INDEX IF NOT EXISTS idx_roles_tenant_id ON public.roles(tenant_id);
CREATE INDEX IF NOT EXISTS idx_roles_parent_id ON public.roles(parent_role_id);
CREATE INDEX IF NOT EXISTS idx_roles_active ON public.roles(tenant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER set_roles_updated_at
BEFORE UPDATE ON public.roles
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_roles
AFTER INSERT OR UPDATE OR DELETE ON public.roles
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;

CREATE POLICY roles_isolation_policy ON public.roles
    FOR ALL USING (tenant_id IS NULL OR tenant_id = public.get_current_tenant_id());


CREATE TABLE IF NOT EXISTS public.permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) UNIQUE NOT NULL, -- e.g., 'pos:sales:create', 'inventory:view'
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE public.permissions IS 'System-wide atomic permission flags. Not tenant-specific.';

CREATE TRIGGER set_permissions_updated_at
BEFORE UPDATE ON public.permissions
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.permissions ENABLE ROW LEVEL SECURITY;

CREATE POLICY permissions_read_policy ON public.permissions
    FOR SELECT USING (true); -- Global read access


CREATE TABLE IF NOT EXISTS public.role_permissions (
    role_id UUID NOT NULL REFERENCES public.roles(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES public.permissions(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY(role_id, permission_id)
);
COMMENT ON TABLE public.role_permissions IS 'Mapping of permissions to roles.';

CREATE INDEX IF NOT EXISTS idx_role_permissions_role ON public.role_permissions(role_id);
CREATE INDEX IF NOT EXISTS idx_role_permissions_perm ON public.role_permissions(permission_id);

CREATE TRIGGER audit_role_permissions
AFTER INSERT OR UPDATE OR DELETE ON public.role_permissions
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;

CREATE POLICY role_permissions_isolation_policy ON public.role_permissions
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.roles r 
            WHERE r.id = role_permissions.role_id 
            AND (r.tenant_id IS NULL OR r.tenant_id = public.get_current_tenant_id())
        )
    );


CREATE TABLE IF NOT EXISTS public.user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES public.roles(id) ON DELETE CASCADE,
    outlet_id UUID REFERENCES public.outlets(id) ON DELETE CASCADE, -- Role might be specific to an outlet
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE public.user_roles IS 'Assignment of roles to users, optionally scoped to an outlet.';

CREATE INDEX IF NOT EXISTS idx_user_roles_user ON public.user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_outlet ON public.user_roles(outlet_id);

-- Enforce uniqueness across user + role + outlet combo handling nulls distinctly
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_roles_unique ON public.user_roles (
    user_id, 
    role_id, 
    COALESCE(outlet_id, '00000000-0000-0000-0000-000000000000'::UUID)
);

CREATE TRIGGER set_user_roles_updated_at
BEFORE UPDATE ON public.user_roles
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER audit_user_roles
AFTER INSERT OR UPDATE OR DELETE ON public.user_roles
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_roles_isolation_policy ON public.user_roles
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.profiles p 
            WHERE p.id = user_roles.user_id 
            AND p.tenant_id = public.get_current_tenant_id()
        )
    );


-- 4. EXAMPLE PERMISSIONS SEED
-- ------------------------------------------------------------------------------
INSERT INTO public.permissions (name, description) VALUES
('pos:order:create', 'Create a new POS order'),
('inventory:item:view', 'View inventory items'),
('inventory:stock:adjust', 'Adjust inventory stock'),
('accounting:ledger:view', 'View accounting ledgers')
ON CONFLICT DO NOTHING;


-- ==============================================================================
-- ROLLBACK INSTRUCTIONS
-- ==============================================================================
/*
-- To rollback this migration, run the following commands:
DROP POLICY IF EXISTS user_roles_isolation_policy ON public.user_roles;
DROP POLICY IF EXISTS role_permissions_isolation_policy ON public.role_permissions;
DROP POLICY IF EXISTS permissions_read_policy ON public.permissions;
DROP POLICY IF EXISTS roles_isolation_policy ON public.roles;
DROP POLICY IF EXISTS profiles_isolation_policy ON public.profiles;

DROP TABLE IF EXISTS public.user_roles CASCADE;
DROP TABLE IF EXISTS public.role_permissions CASCADE;
DROP TABLE IF EXISTS public.permissions CASCADE;
DROP TABLE IF EXISTS public.roles CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

DROP FUNCTION IF EXISTS public.get_current_outlet_id() CASCADE;

-- Revert the tenant_id function to the stub from 00001
CREATE OR REPLACE FUNCTION public.get_current_tenant_id()
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN (current_setting('request.jwt.claims', true)::jsonb->>'tenant_id')::UUID;
END;
$$;
*/
