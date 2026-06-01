# Production Launch Checklist

Follow these steps before officially launching NexusPOS to external customers.

## 1. Environment Configuration
- [ ] Verify `NEXT_PUBLIC_SUPABASE_URL` is set to the production instance URL.
- [ ] Verify `NEXT_PUBLIC_SUPABASE_ANON_KEY` is set to the production anon key.
- [ ] Ensure `SUPABASE_SERVICE_ROLE_KEY` is strictly managed and injected only into server-side CI/CD pipelines or backend environments.
- [ ] Set `NODE_ENV=production` for standard Next.js optimizations.

## 2. Security & Compliance
- [ ] Double-check all RLS policies against edge cases in the Supabase Dashboard.
- [ ] Enable Multi-Factor Authentication (MFA) for Super Admins in the Supabase Dashboard.
- [ ] Enforce strong password requirements in Supabase Auth settings.
- [ ] Set up an SSL certificate for custom domains (handled by Vercel/Netlify natively).

## 3. Database & Storage Readiness
- [ ] Ensure Point-in-Time Recovery (PITR) is enabled.
- [ ] Increase database instance size if expecting high concurrent load.
- [ ] Ensure the Storage Bucket for logos/receipts is set to 'Public' but restricted to authentic users for uploads.

## 4. Performance Optimization
- [ ] Check Supabase Dashboard for index suggestions via the Query Performance Analyzer.
- [ ] Run Lighthouse performance audit on the Next.js frontend to ensure fast POS load times.

## 5. Monitoring & Observability
- [ ] Integrate an error monitoring tool (e.g., Sentry, Datadog) to track client and server-side errors.
- [ ] Setup Uptime monitoring (e.g., BetterUptime, Pingdom) alerting the engineering team on downtime.
- [ ] Enable Vercel Speed Insights and Web Analytics.

## 6. Onboarding Data Setup
- [ ] Initialize standard tax codes required by law in target regions.
- [ ] Ensure standard units of measurement (kg, g, L, ml, pcs) are seeded in the DB.
- [ ] Prepare standard "Demo" tenant structures (Cafe, Restaurant, Tea Shop) for sales team usage.

## 7. Documentation Handover
- [ ] Verify "Owner User Guide" is available in the Help Center.
- [ ] Verify "Cashier User Guide" and "Kitchen Staff User Guide" are accessible natively from the POS interface.
