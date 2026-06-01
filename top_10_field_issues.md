# Top 10 Anticipated Field Issues & Mitigation Plans

As we roll out NexusPOS to real-world pilot locations (Darjeeling Tea Shop, Cafe, Restaurant), we anticipate friction points primarily around hardware, training, and real-world edge cases.

### 1. Thermal Printer Connectivity Loss
*   **Issue**: USB/Bluetooth thermal printer disconnects during peak hours, preventing receipt generation.
*   **Mitigation**: The POS handles print requests locally via browser print dialogues. If the physical printer fails, the system does not block the checkout flow. Cashiers can continue processing orders and print historic receipts from the `Orders` screen once connectivity is restored.

### 2. KDS Tablet Wi-Fi Disconnection
*   **Issue**: The kitchen tablet loses Wi-Fi, causing KDS to stop receiving Supabase Realtime updates.
*   **Mitigation**: Implement a visual "Offline" indicator on the KDS. When reconnected, the Next.js/Supabase client automatically re-establishes the socket connection and fetches the latest `PENDING` orders via a fallback REST query to ensure no tickets are dropped.

### 3. Accidental KDS Ticket Bumping
*   **Issue**: Kitchen staff accidentally bumps a ticket to `SERVED`, removing it from the active screen before it is actually finished.
*   **Mitigation**: Introduce a "Recently Completed" tab on the KDS allowing staff to recall and revert tickets bumped within the last 15 minutes.

### 4. Splitting Bills Beyond 2 Methods
*   **Issue**: A large party wants to split a bill across 4 different credit cards and cash.
*   **Mitigation**: The current `payments` architecture supports N-number of partial payments per `order_id`. Cashiers are trained to keep entering amounts and selecting payment methods until the `Balance Due` hits $0.

### 5. Negative Stock Due to Un-received Deliveries
*   **Issue**: Inventory items go into negative stock because staff sold items during a rush before entering the Goods Received Note (GRN).
*   **Mitigation**: The system is designed to allow negative inventory counts (soft limits) rather than hard-blocking sales. A dashboard alert flags negative inventory for Manager review at the end of the shift.

### 6. Forgotten PINs / Passwords
*   **Issue**: Cashier forgets their login credential right before opening time.
*   **Mitigation**: The Owner/Admin account has privileges to send a password reset link or update the PIN directly from the Business Settings module.

### 7. Incorrect Tax Configuration on Setup
*   **Issue**: The restaurant owner configures Tax as "Exclusive" when local laws require "Inclusive" display pricing, leading to customer complaints.
*   **Mitigation**: The First-Time Setup wizard explicitly previews how a receipt will look based on the tax toggle to ensure the owner catches this immediately.

### 8. End of Day Cash Drawer Discrepancy
*   **Issue**: The physical cash drawer does not match the expected "CASH" total in the Analytics dashboard.
*   **Mitigation**: Phase 2 introduces Shift Management (Opening/Closing floats). Currently, owners are instructed to run the "Today's Sales" analytics report specifically filtering for the "CASH" payment method to audit the till.

### 9. Hardware Glare / Touch Sensitivity in Kitchens
*   **Issue**: Grease or water on the kitchen tablet screen causes phantom touches or prevents staff from bumping tickets.
*   **Mitigation**: Recommended hardware includes industrial-grade tablet enclosures. The UI uses extremely large touch targets for the KDS (entire ticket cards are clickable) to minimize precision requirements.

### 10. Training Resistance from Legacy Staff
*   **Issue**: Older staff members resist transitioning from paper tickets to the KDS.
*   **Mitigation**: The Pilot Launch includes a mandatory 2-day dual-run where paper tickets are printed *alongside* the KDS to build trust in the digital system before removing the paper completely.
