-- Fix RLS for profiles by adding a direct self-read policy to prevent recursion issues
CREATE POLICY profiles_self_read ON public.profiles FOR SELECT USING (id = auth.uid());
CREATE POLICY profiles_self_update ON public.profiles FOR UPDATE USING (id = auth.uid());

-- Ensure the get_current_tenant_id function is properly set to SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.get_current_tenant_id()
RETURNS UUID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    RETURN (
        SELECT public.profiles.tenant_id 
        FROM public.profiles 
        WHERE public.profiles.id = auth.uid()
    );
END;
$$;
