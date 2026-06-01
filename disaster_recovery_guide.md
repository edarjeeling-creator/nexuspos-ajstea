# Disaster Recovery & Backup Guide

## Database Backups

NexusPOS utilizes Supabase PostgreSQL, which provides managed backups.

### 1. Daily Automated Backups
- Supabase automatically takes daily logical backups.
- These backups are retained for 7 days (Free/Pro tiers) or up to 30 days (Enterprise).
- No manual intervention is required to trigger these.

### 2. Point in Time Recovery (PITR)
- **Requirement**: Must be enabled in the Supabase Dashboard (requires Pro Plan + PITR add-on).
- **Mechanism**: Backs up the WAL (Write-Ahead Log) every 2 minutes.
- **Usage**: Allows restoring the database to *any precise minute* within the retention window (e.g., right before a catastrophic accidental deletion).

### 3. Manual Logical Backups
For off-site archiving, you should schedule a monthly `pg_dump`:
```bash
pg_dump "postgres://postgres.[PROJECT-REF]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres" -Fc > backup.dump
```

---

## Restore Procedure

### Scenario A: Minor Data Corruption (PITR Restore)
If a user accidentally deleted menu items or orders:
1. Navigate to **Supabase Dashboard -> Database -> Backups**.
2. Select **Point in Time Recovery**.
3. Choose the exact date and time immediately *prior* to the corruption event.
4. Click **Restore**. 
5. *Note: The database will be briefly unavailable during restoration (typically 2-10 minutes).*

### Scenario B: Catastrophic Project Loss (Full Dump Restore)
If the entire Supabase project was deleted:
1. Create a **New Supabase Project**.
2. Provision a new PostgreSQL instance.
3. Use `pg_restore` from your latest off-site logical backup:
```bash
pg_restore -d "postgres://postgres.[NEW-PROJECT-REF]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres" -1 backup.dump
```
4. Update the `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` in your Vercel/hosting environment variables to point to the new project.
5. Trigger a new production deployment.

## Disaster Recovery Objectives
*   **Recovery Point Objective (RPO)**: < 5 minutes (data loss window) with PITR enabled.
*   **Recovery Time Objective (RTO)**: < 1 hour for full restoration of services to a new cluster in the event of catastrophic failure.
