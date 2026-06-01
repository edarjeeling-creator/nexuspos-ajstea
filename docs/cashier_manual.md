---
title: "NexusPOS AI: Cashier Manual"
subtitle: "Pilot Launch Edition"
author: "NexusPOS Team"
date: "June 2026"
---

# Cashier Manual

Welcome to **NexusPOS AI**. This guide will teach you how to manage the front counter, take orders, and process payments quickly and efficiently.

---

## 1. Getting Started

### 1.1 Login
1. Open the NexusPOS application on your tablet or desktop.
2. Enter your assigned email (e.g., `cashier@teashop.com`) and password.
3. You will immediately be routed to the POS terminal. (Note: You do not have access to Analytics or Settings).

### 1.2 Opening the POS Terminal
*   The left side of the screen displays **Categories** (e.g., Beverages, Food) and a **Search Bar**.
*   The center displays **Menu Items**.
*   The right side displays the **Active Cart**.

![POS Main Screen](./screenshots/pos_main.png)

---

## 2. Order Management

### 2.1 Creating Orders
1. Select an **Order Type** at the top of the cart: `DINE-IN`, `TAKEAWAY`, or `DELIVERY`.
2. Enter the **Table Number** or **Token Number**.
3. Tap on a menu item in the center screen to add it to the cart.
4. Tap it again to increase the quantity.

### 2.2 Handling Mistakes and Voids
*   **Decrease Quantity**: Click the `-` button next to the item in the cart.
*   **Remove Item completely**: Click the red trash can icon next to the item.
*   **Clear Entire Cart**: Click the **Clear** button at the top of the cart to start over.

### 2.3 Order Notes (Special Instructions)
If a customer has a special request:
1. Look at the bottom of the cart for the **Order Notes** input box.
2. Type the request (e.g., "No sugar", "Extra spicy").
3. This note will be sent directly to the kitchen.

![POS Cart Management](./screenshots/pos_cart.png)

---

## 3. Checkout & Payments

### 3.1 Applying Discounts
1. Before checking out, locate the **Discount %** field in the cart summary.
2. Enter a discount percentage (e.g., `10` for 10% off).
3. The subtotal and tax will automatically recalculate.

### 3.2 Processing Standard Payments (Cash, UPI, Card)
1. Ensure the customer is ready to pay the **Grand Total**.
2. Select the payment method they are using: **CASH**, **CARD**, or **UPI**.
3. Click **Add Payment**.
4. The Balance Due will drop to $0.00.
5. Click **Complete Order**.

### 3.3 Split Payments
If a customer wants to pay half in cash and half on a card:
1. In the **Amount** field, type the amount they are paying in cash (e.g., `50`).
2. Select **CASH** and click **Add Payment**.
3. The **Balance Due** will update to reflect the remaining amount.
4. Leave the remaining amount in the box, select **CARD**, and click **Add Payment**.
5. Once Balance Due is $0.00, click **Complete Order**.

![Split Payments Interface](./screenshots/split_payments.png)

---

## 4. Printing Receipts
1. When you click **Complete Order**, the order is sent to the kitchen instantly.
2. A **Receipt Preview** modal will appear on your screen.
3. Click **Print** to send it to your thermal receipt printer.
4. If a customer needs a reprint later, navigate to the **Orders** tab on the left sidebar to find past receipts.

---

## 5. Troubleshooting
*   **Printer Not Responding**: Ensure the USB or Bluetooth connection to the printer is active. Refresh the browser tab.
*   **Item Not Scanning**: If you are using a barcode scanner, ensure your cursor is active in the "Search Menu Items" box before scanning.
