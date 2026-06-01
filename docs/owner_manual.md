---
title: "NexusPOS AI: Owner Manual"
subtitle: "Pilot Launch Edition"
author: "NexusPOS Team"
date: "June 2026"
---

# Owner Manual

Welcome to **NexusPOS AI - Pilot Launch Edition**. This manual provides comprehensive instructions for owners to configure and manage their restaurant operations.

---

## 1. Initial Setup

When you log in for the first time, you must configure your core store settings.

### 1.1 Business Settings
1. Navigate to **Settings > Business Settings** in the left sidebar.
2. Enter your **Store Name**, **Legal Entity Name**, and **Tax ID (GSTIN)**.
3. Upload your **Business Logo**.
4. Set your local **Timezone** and **Currency Symbol**.
5. Click **Save Settings**.

![Business Settings Dashboard](./screenshots/business_settings.png)

### 1.2 Tax Settings
1. Navigate to **Settings > Taxes**.
2. Set your **Global Default Tax Rate** (e.g., 5%).
3. Toggle whether tax should automatically apply to **Dine-In**, **Takeaway**, or **Delivery** orders.
4. Toggle **Print GSTIN on Receipts** to ensure legal compliance.

![Tax Configuration Options](./screenshots/tax_settings.png)

### 1.3 Receipt Settings
1. Navigate to **Settings > Receipts**.
2. Select your printer format: **Thermal 80mm** (standard POS) or **A4 Invoice**.
3. Customize your **Header** and **Footer** text (e.g., "Thank you for visiting!").
4. Choose between **Tax Inclusive** (hidden in line items) or **Tax Exclusive** (added at the end).
5. Preview your receipt on the right side of the screen before saving.

![Receipt Preview](./screenshots/receipt_settings.png)

---

## 2. Menu & Inventory Management

NexusPOS AI uses a powerful recipe-based inventory system to automatically deduct stock as you sell items.

### 2.1 Adding Raw Ingredients
1. Go to **Inventory > Items**.
2. Click **Add New Item**.
3. Check the box **Is Raw Ingredient**.
4. Enter the Name (e.g., "Coffee Beans"), SKU, Unit of Measure (e.g., "kg"), and Unit Cost.
5. Set a **Reorder Level** to receive alerts when stock runs low.

### 2.2 Adding Menu Items (Sellable Goods)
1. Go to **Menu > Items**.
2. Click **Create Menu Item**.
3. Enter the Name (e.g., "Cappuccino"), Price, and assign it to a Category (e.g., "Beverages").
4. Upload an image for the POS interface.

### 2.3 Linking Recipes
To deduct coffee beans automatically when a cappuccino is sold:
1. Edit the "Cappuccino" menu item and click **Manage Recipe**.
2. Add "Coffee Beans" as an ingredient.
3. Set the quantity (e.g., `0.015` kg for 15 grams).
4. Save the recipe.

![Recipe Management Interface](./screenshots/recipe_management.png)

---

## 3. Analytics & Reporting

NexusPOS AI provides real-time insights into your business performance.

### 3.1 Analytics Dashboard
Navigate to **Analytics**. You will see:
*   **Today's Sales**: Real-time revenue for the current day.
*   **Hourly Sales Trends**: A line chart showing your busiest hours.
*   **Payment Breakdown**: A pie chart showing Cash vs. UPI vs. Card usage.
*   **Top Selling Items**: A bar chart of your most popular dishes.

![Analytics Dashboard](./screenshots/analytics_dashboard.png)

### 3.2 Generating Reports
1. Go to **Reports**.
2. Select a report type (e.g., **Daily Sales Report**, **Inventory Movement**).
3. Select a date range and click **Generate**.
4. Export the data as CSV or PDF for your accountant.

---

## 4. Staff Management

*(Note: Advanced role management is coming in Phase 2. Currently, roles are assigned during tenant creation.)*

### 4.1 Best Practices for Staff Security
*   **Do not share credentials**. Ensure Cashiers and Kitchen Staff use their dedicated logins.
*   **Cashier accounts cannot access Analytics or Settings**. If a cashier needs a refund override, a Manager must authorize it.

---

## 5. Troubleshooting & Best Practices

### Common Mistakes
*   **Negative Inventory**: If you sell a menu item but forgot to add the raw ingredient stock via a Goods Received Note (GRN), your inventory will drop below zero. **Fix**: Do a Manual Stock Adjustment to correct the balance.
*   **Tax Not Printing**: If taxes are missing on receipts, ensure **Tax Exclusive** is selected in Receipt Settings.

### Backup Recommendations
Your database is hosted securely on Supabase.
*   **Automated Backups**: Your data is backed up daily automatically.
*   **Disaster Recovery**: If you accidentally delete menu items, contact your system administrator to perform a Point-in-Time Recovery (PITR).
