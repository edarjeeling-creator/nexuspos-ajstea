-- ==============================================================================
-- Migration: 00014_auth_hooks
-- Description: Supabase Auth Hooks for Auto-creating Tenants and Seed Roles
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS TRIGGER AS $$
DECLARE
    target_tenant_id UUID;
    target_outlet_id UUID;
    owner_role_id UUID;
BEGIN
    -- If the user was invited to an existing tenant (via metadata)
    IF NEW.raw_user_meta_data->>'tenant_id' IS NOT NULL THEN
        target_tenant_id := (NEW.raw_user_meta_data->>'tenant_id')::UUID;
        
        -- Get the oldest/main outlet for this tenant
        SELECT id INTO target_outlet_id FROM public.outlets WHERE tenant_id = target_tenant_id ORDER BY created_at ASC LIMIT 1;
        
        -- Create the Profile linked to the existing tenant
        INSERT INTO public.profiles (id, tenant_id, default_outlet_id, email, is_active)
        VALUES (NEW.id, target_tenant_id, target_outlet_id, NEW.email, true);
        
        -- Note: For invited users, their specific role (e.g. Cashier) is typically assigned by the 
        -- inviting admin via a separate API call, so we do not auto-assign the OWNER role here.

    ELSE
        -- 1. Create a new Tenant (Self-serve Registration)
        INSERT INTO public.tenants (name)
        VALUES (COALESCE(NEW.raw_user_meta_data->>'tenant_name', 'My Business'))
        RETURNING id INTO target_tenant_id;

        -- 2. Create a default Outlet
        INSERT INTO public.outlets (tenant_id, name)
        VALUES (target_tenant_id, 'Main Outlet')
        RETURNING id INTO target_outlet_id;

        -- 3. Create the Profile
        INSERT INTO public.profiles (id, tenant_id, default_outlet_id, email, is_active)
        VALUES (NEW.id, target_tenant_id, target_outlet_id, NEW.email, true);

        -- 4. Seed system roles for the newly created tenant
        -- This prevents duplicate roles from being created for subsequent users.
        INSERT INTO public.roles (tenant_id, name, permissions) VALUES 
            (target_tenant_id, 'OWNER', '["*"]'),
            (target_tenant_id, 'ADMIN', '["*"]'),
            (target_tenant_id, 'MANAGER', '["pos.*", "inventory.*", "hrms.*"]'),
            (target_tenant_id, 'CASHIER', '["pos.orders.create", "pos.orders.read"]');

        -- Retrieve the newly created OWNER role
        SELECT id INTO owner_role_id FROM public.roles WHERE tenant_id = target_tenant_id AND name = 'OWNER' LIMIT 1;

        -- 5. Assign the OWNER role to the foundational user
        INSERT INTO public.user_roles (tenant_id, profile_id, role_id)
        VALUES (target_tenant_id, NEW.id, owner_role_id);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop trigger if it exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Create the trigger
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
