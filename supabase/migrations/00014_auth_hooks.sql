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
        INSERT INTO public.profiles (id, tenant_id, outlet_id, status)
        VALUES (NEW.id, target_tenant_id, target_outlet_id, 'ACTIVE');

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
        INSERT INTO public.profiles (id, tenant_id, outlet_id, status)
        VALUES (NEW.id, target_tenant_id, target_outlet_id, 'ACTIVE');

        -- 4. Seed system roles for the newly created tenant
        INSERT INTO public.roles (tenant_id, name, description) VALUES 
            (target_tenant_id, 'OWNER', 'Full access'),
            (target_tenant_id, 'ADMIN', 'Administrative access'),
            (target_tenant_id, 'MANAGER', 'Store manager'),
            (target_tenant_id, 'CASHIER', 'Cashier');

        -- Retrieve the newly created OWNER role
        SELECT id INTO owner_role_id FROM public.roles WHERE tenant_id = target_tenant_id AND name = 'OWNER' LIMIT 1;

        -- 5. Assign the OWNER role to the foundational user
        INSERT INTO public.user_roles (user_id, role_id, outlet_id)
        VALUES (NEW.id, owner_role_id, target_outlet_id);
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
