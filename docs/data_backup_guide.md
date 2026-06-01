# Data Backup & Security Guide

**Project**: NexusPOS AI
**Phase**: Pilot Launch

Because NexusPOS is a cloud-native platform, you do not need to manually backup data to USB drives at the end of every night.

## 1. Automated Cloud Backups
*   **Infrastructure**: All transaction and inventory data is stored securely in our enterprise-grade Supabase PostgreSQL cluster.
*   **Daily Backups**: The system automatically captures a full logical backup of your entire restaurant's data every 24 hours.
*   **Point-in-Time Recovery (PITR)**: For premium accounts, the database logs every single transaction in real-time. If catastrophic accidental data deletion occurs, the IT team can roll the database back to any specific minute within the last 7 days.

## 2. Offline Mode Limitations (Phase 1)
*   **Requirement**: NexusPOS requires a constant internet connection to process sales and sync with the Kitchen Display System (KDS).
*   **Contingency**: If your internet goes down, you must switch to a cellular hotspot or pause operations. Offline-first synchronization is a planned feature for a future commercial release.

## 3. Data Export (For Accounting)
If your accountant requests a backup of your financial data:
1. Navigate to **Reports** in the Administrator Dashboard.
2. Select **Daily Sales Report** or **Monthly Tax Summary**.
3. Select the date range.
4. Click **Export CSV**. This generates an Excel-compatible spreadsheet that serves as your local financial backup.
