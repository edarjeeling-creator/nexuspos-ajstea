---
title: "NexusPOS AI: Administrator Manual"
subtitle: "Pilot Launch Edition"
author: "NexusPOS Team"
date: "June 2026"
---

# Administrator Manual

Welcome to the **NexusPOS AI Infrastructure Guide**. This manual is intended for IT staff and super-administrators responsible for maintaining the backend systems, database, and deployments.

---

## 1. Supabase Management

NexusPOS uses Supabase as its backend-as-a-service (BaaS) providing PostgreSQL, Auth, and Realtime capabilities.

### 1.1 Database Access
*   Access the database directly via the Supabase Dashboard -> **Table Editor** or **SQL Editor**.
*   **Row Level Security (RLS)** is strictly enforced on all tables. If you must run a script to manipulate data across tenants, ensure you use the `SERVICE_ROLE_KEY` to bypass RLS.
*   **Never expose the `SERVICE_ROLE_KEY` to the client-side Next.js application.**

### 1.2 Auth & User Management
*   User accounts are managed under **Authentication > Users** in Supabase.
*   To reset a password manually, locate the user and click "Send Password Reset".
*   Multi-Factor Authentication (MFA) is highly recommended for all Super Admin accounts accessing the Supabase Dashboard.

![Supabase Dashboard Overview](./screenshots/supabase_dashboard.png)

---

## 2. Coolify Deployment

NexusPOS AI is designed to be easily deployed via Coolify (or Vercel).

### 2.1 Deployment Steps
1. Connect your GitHub repository to Coolify.
2. Select the `nexuspos_web` directory.
3. Configure the Build Command: `npm run build`.
4. Configure the Start Command: `npm run start`.
5. Under Environment Variables, strictly set:
   *   `NEXT_PUBLIC_SUPABASE_URL`
   *   `NEXT_PUBLIC_SUPABASE_ANON_KEY`
   *   `SUPABASE_SERVICE_ROLE_KEY`
6. Click **Deploy**.

### 2.2 SSL & Domains
*   Coolify natively provisions Let's Encrypt SSL certificates. Ensure your DNS A-records point to the Coolify instance IP before provisioning.

---

## 3. Backup and Restore Procedures

Data integrity is the highest priority.

### 3.1 Point-in-Time Recovery (PITR)
*   **Enabled via Supabase Pro Plan**. PITR backs up the Write-Ahead Log (WAL) every 2 minutes.
*   If a tenant accidentally corrupts their menu, navigate to **Database > Backups > PITR**, select the exact minute prior to the corruption, and click **Restore**. The database will reboot in ~5 minutes.

### 3.2 Manual Cold Backups
For compliance, take a monthly logical dump:
```bash
pg_dump "postgres://postgres.[PROJECT-REF]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres" -Fc > backup.dump
```

---

## 4. Tenant & User Provisioning

NexusPOS is a multi-tenant B2B system.

### 4.1 Onboarding a New Tenant
Currently (Phase 1), tenant onboarding is handled via SQL script or admin dashboard.
1. Insert a new record into `public.tenants`.
2. Insert a new record into `public.outlets` linked to the `tenant_id`.
3. Create the Owner user via Supabase Auth.
4. Insert the Owner's UUID into `public.users` linked to the `tenant_id`.

---

## 5. Security Checklist

Before finalizing any major update, audit the following:
*   [ ] **RLS Verification**: Are all new tables created with `ENABLE ROW LEVEL SECURITY`?
*   [ ] **Tenant Isolation**: Does the RLS policy explicitly check `tenant_id = (select tenant_id from users where id = auth.uid())`?
*   [ ] **Env Variables**: Are there any hardcoded secrets in the `/src` directory? (Use `dotenv` only).
*   [ ] **Dependencies**: Run `npm audit` monthly to patch vulnerable packages.
