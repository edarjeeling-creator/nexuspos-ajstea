# User Acceptance Testing (UAT) Checklist

**Project**: NexusPOS
**Stage**: Pilot Launch

## 1. Authentication & Authorization
- [ ] Login as Owner (success expected).
- [ ] Login as Cashier (success expected).
- [ ] Verify Cashier cannot access `Settings` or `Analytics` (authorization block).
- [ ] Login as Kitchen Staff. Verify access is restricted to KDS only.

## 2. Inventory Management
- [ ] Create a new raw ingredient.
- [ ] Add stock to the raw ingredient via manual adjustment.
- [ ] Verify `inventory_transactions` logs the manual adjustment.
- [ ] Create a Menu Item linked to a Recipe.
- [ ] Verify recipe accurately deducts raw ingredients during theoretical consumption.

## 3. POS Checkout Workflow
- [ ] Add items to the cart.
- [ ] Increase and decrease quantities.
- [ ] Remove an item from the cart.
- [ ] Apply a global order discount.
- [ ] Check out using CASH.
- [ ] Verify order status is `COMPLETED`.

## 4. Complex Payments
- [ ] Process an order with Split Payments (e.g., 50% CASH, 50% CARD).
- [ ] Verify total sums correctly and order moves to `COMPLETED`.
- [ ] Verify `payments` table accurately records two distinct payment entries for the single order.

## 5. Receipt Printing
- [ ] Complete an order and trigger receipt preview.
- [ ] Verify business logo, custom header, and custom footer are present.
- [ ] Verify tax is displayed accurately (Inclusive vs Exclusive format).
- [ ] Verify thermal 80mm format styling is applied.

## 6. KDS Workflow
- [ ] Cashier creates a Dine-In order.
- [ ] Order instantly appears on the KDS board (Supabase Realtime).
- [ ] Kitchen staff bumps order from `PENDING` -> `PREPARING`.
- [ ] Kitchen staff bumps order from `PREPARING` -> `READY`.
- [ ] Order disappears from active KDS board when bumped to `SERVED`.

## 7. Analytics & Settings
- [ ] View `Today's Sales` on the Analytics Dashboard.
- [ ] Verify the sales amount strictly matches the orders placed during this session.
- [ ] Change Global Tax Rate in `Tax Settings`.
- [ ] Place a new order and verify the new tax rate is applied to the subtotal.
