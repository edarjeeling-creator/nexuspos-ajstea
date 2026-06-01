-- Enable Supabase Realtime for KDS tables
BEGIN;

  -- Create the publication if it doesn't exist (Supabase usually has this by default, but safe to check)
  DO $$ 
  BEGIN 
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
      CREATE PUBLICATION supabase_realtime;
    END IF;
  END $$;

  -- Add orders and order_items to the realtime publication
  ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
  ALTER PUBLICATION supabase_realtime ADD TABLE public.order_items;

COMMIT;
