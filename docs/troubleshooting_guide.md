---
title: "NexusPOS AI: Troubleshooting Guide"
subtitle: "Pilot Launch Edition"
author: "NexusPOS Team"
date: "June 2026"
---

# Troubleshooting Guide

This guide covers the most common issues you might encounter during daily operations and how to resolve them immediately.

---

## 1. Hardware & Connectivity Issues

### 1.1 The receipt printer is not printing.
**Symptom**: You click "Print" on the POS, but nothing happens.
**Solution**:
1. Check if the printer has paper and the green power light is on.
2. Check the USB/Bluetooth connection to the computer/tablet.
3. If using Windows, open the "Printers & Scanners" menu and ensure the thermal printer is set as the "Default Printer".
4. Refresh the NexusPOS browser tab.

### 1.2 The KDS (Kitchen Tablet) is not receiving new orders.
**Symptom**: Cashiers are ringing up food, but the kitchen screen is empty.
**Solution**:
1. Check the Wi-Fi connection on the tablet. NexusPOS Realtime requires an active internet connection.
2. If the Wi-Fi dropped momentarily, refresh the browser page. The system will automatically fetch all missed `PENDING` orders from the server.
3. Ensure the tablet is not on the "Lock Screen" or "Sleep Mode".

---

## 2. Point of Sale (POS) Issues

### 2.1 The barcode scanner isn't adding items to the cart.
**Symptom**: You scan a Coke, but it doesn't appear in the cart.
**Solution**:
1. Click your mouse cursor inside the **"Search Menu Items"** text box at the top of the POS screen.
2. The barcode scanner acts like a keyboard; it must have a text field focused to input the barcode digits.

### 2.2 I made a mistake on a payment, but the order is closed.
**Symptom**: You hit "CASH" but the customer actually paid with "CARD", and the receipt already printed.
**Solution**:
1. Currently, closed orders cannot be modified by cashiers for security reasons.
2. Call a Manager. The Manager must log in, void the original order from the `Orders` screen, and ring it up again correctly.

---

## 3. Inventory & Reporting Issues

### 3.1 Inventory shows negative numbers.
**Symptom**: Coffee Beans show `-5 kg` in stock.
**Solution**:
1. This happens when you sell menu items, but you forgot to tell the system you received a new delivery from your supplier.
2. To fix it, go to **Inventory > Items**, click the item, and perform a **Manual Adjustment** to add the correct current physical stock.

### 3.2 "Today's Sales" doesn't match the cash in the drawer.
**Symptom**: The Analytics dashboard says $500, but the drawer only has $300.
**Solution**:
1. "Today's Sales" shows *Total Revenue* (Cash + Card + UPI).
2. Look at the **Payment Breakdown** pie chart on the dashboard to see exactly how much of that $500 was supposed to be physical Cash. 
3. If the Cash breakdown says $300, your drawer is perfectly balanced!
