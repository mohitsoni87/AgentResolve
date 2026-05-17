-- AgentResolve demo data (re-runnable)
-- Run: ./db/seed.sh   (or psql -f db/seed.sql)

SET search_path TO orders, public;

-- Disable triggers so we control order_status_history timelines
SET session_replication_role = replica;

TRUNCATE TABLE
    shipments,
    order_status_history,
    order_items,
    orders,
    products,
    product_categories,
    users
CASCADE;

-- ---------------------------------------------------------------------------
-- Product categories
-- ---------------------------------------------------------------------------

INSERT INTO product_categories (id, name, description) VALUES
    ('a0000000-0000-4000-8000-000000000001', 'Electronics', 'Devices, audio, and smart accessories'),
    ('a0000000-0000-4000-8000-000000000002', 'Apparel', 'Clothing and wearables'),
    ('a0000000-0000-4000-8000-000000000003', 'Home & Kitchen', 'Cookware and home essentials'),
    ('a0000000-0000-4000-8000-000000000004', 'Sports', 'Fitness and outdoor gear');

-- ---------------------------------------------------------------------------
-- Users
-- ---------------------------------------------------------------------------

INSERT INTO users (id, email, full_name, phone, created_at) VALUES
    ('b0000000-0000-4000-8000-000000000001', 'alice.johnson@example.com', 'Alice Johnson', '+1-555-0101', '2025-11-02 10:00:00+00'),
    ('b0000000-0000-4000-8000-000000000002', 'bob.smith@example.com', 'Bob Smith', '+1-555-0102', '2025-11-10 14:20:00+00'),
    ('b0000000-0000-4000-8000-000000000003', 'carol.martinez@example.com', 'Carol Martinez', '+1-555-0103', '2025-12-01 09:45:00+00'),
    ('b0000000-0000-4000-8000-000000000004', 'david.chen@example.com', 'David Chen', '+1-555-0104', '2026-01-15 16:30:00+00'),
    ('b0000000-0000-4000-8000-000000000005', 'eva.okonkwo@example.com', 'Eva Okonkwo', '+1-555-0105', '2026-02-20 11:00:00+00'),
    ('b0000000-0000-4000-8000-000000000006', 'frank.miller@example.com', 'Frank Miller', '+1-555-0106', '2026-03-05 08:15:00+00');

-- ---------------------------------------------------------------------------
-- Products (catalog for line-item lookup)
-- ---------------------------------------------------------------------------

INSERT INTO products (id, sku, name, description, category_id, unit_price) VALUES
    ('c0000000-0000-4000-8000-000000000001', 'SKU-WIDGET-01', 'Smart Widget', 'Wi-Fi enabled smart widget with app control', 'a0000000-0000-4000-8000-000000000001', 49.99),
    ('c0000000-0000-4000-8000-000000000002', 'SKU-GADGET-02', 'Portable Gadget', 'Compact rechargeable gadget, 20h battery', 'a0000000-0000-4000-8000-000000000001', 79.99),
    ('c0000000-0000-4000-8000-000000000003', 'SKU-HOODIE-03', 'Agent Hoodie', 'Unisex comfort-fit hoodie, navy', 'a0000000-0000-4000-8000-000000000002', 39.99),
    ('c0000000-0000-4000-8000-000000000004', 'SKU-BUDS-04', 'NoiseCancel Buds', 'Wireless earbuds with active noise cancellation', 'a0000000-0000-4000-8000-000000000001', 129.99),
    ('c0000000-0000-4000-8000-000000000005', 'SKU-KETTLE-05', 'Glass Kettle Pro', '1.7L electric kettle with temperature presets', 'a0000000-0000-4000-8000-000000000003', 59.99),
    ('c0000000-0000-4000-8000-000000000006', 'SKU-MAT-06', 'Yoga Mat Elite', 'Non-slip 6mm mat with carry strap', 'a0000000-0000-4000-8000-000000000004', 34.99),
    ('c0000000-0000-4000-8000-000000000007', 'SKU-TEE-07', 'Dev Conference Tee', 'Limited edition cotton tee, size M', 'a0000000-0000-4000-8000-000000000002', 24.99),
    ('c0000000-0000-4000-8000-000000000008', 'SKU-HUB-08', 'USB-C Hub 7-in-1', 'HDMI, USB 3.0, SD card reader', 'a0000000-0000-4000-8000-000000000001', 44.99),
    ('c0000000-0000-4000-8000-000000000009', 'SKU-BOTTLE-09', 'Insulated Bottle 32oz', 'Stainless steel, keeps cold 24h', 'a0000000-0000-4000-8000-000000000004', 29.99),
    ('c0000000-0000-4000-8000-000000000010', 'SKU-APRON-10', 'Chef Apron', 'Water-resistant kitchen apron', 'a0000000-0000-4000-8000-000000000003', 19.99);

-- ---------------------------------------------------------------------------
-- Orders (all statuses represented)
-- ---------------------------------------------------------------------------

INSERT INTO orders (
    id, order_id, user_id, status, order_date, placed_at,
    subtotal, tax_amount, shipping_amount, total_amount,
    shipping_address, customer_notes,
    cancelled_at, cancellation_reason
) VALUES
    -- Alice: delivered bundle
    (
        'd0000000-0000-4000-8000-000000000001', 'ORD-2026-0001',
        'b0000000-0000-4000-8000-000000000001', 'delivered', '2026-04-28', '2026-04-28 09:12:00+00',
        179.98, 14.40, 5.00, 199.38,
        '123 Main St, Springfield, IL 62701', 'Leave at front desk',
        NULL, NULL
    ),
    -- Alice: in transit
    (
        'd0000000-0000-4000-8000-000000000002', 'ORD-2026-0002',
        'b0000000-0000-4000-8000-000000000001', 'shipped', '2026-05-08', '2026-05-08 14:05:00+00',
        129.99, 10.40, 0.00, 140.39,
        '123 Main St, Springfield, IL 62701', NULL,
        NULL, NULL
    ),
    -- Alice: processing (cancellable)
    (
        'd0000000-0000-4000-8000-000000000003', 'ORD-2026-0003',
        'b0000000-0000-4000-8000-000000000001', 'processing', '2026-05-14', '2026-05-14 11:22:00+00',
        39.99, 3.20, 5.00, 48.19,
        '123 Main St, Springfield, IL 62701', 'Gift wrap requested',
        NULL, NULL
    ),
    -- Alice: confirmed (cancellable)
    (
        'd0000000-0000-4000-8000-000000000004', 'ORD-2026-0004',
        'b0000000-0000-4000-8000-000000000001', 'confirmed', '2026-05-17', '2026-05-17 10:00:00+00',
        49.99, 4.00, 5.00, 58.99,
        '123 Main St, Springfield, IL 62701', NULL,
        NULL, NULL
    ),
    -- Alice: pending (cancellable)
    (
        'd0000000-0000-4000-8000-000000000005', 'ORD-2026-0005',
        'b0000000-0000-4000-8000-000000000001', 'pending', '2026-05-17', '2026-05-17 18:45:00+00',
        74.98, 6.00, 5.00, 85.98,
        '123 Main St, Springfield, IL 62701', 'Call before delivery',
        NULL, NULL
    ),
    -- Bob: delivered
    (
        'd0000000-0000-4000-8000-000000000006', 'ORD-2026-0006',
        'b0000000-0000-4000-8000-000000000002', 'delivered', '2026-05-02', '2026-05-02 16:30:00+00',
        79.99, 6.40, 5.00, 91.39,
        '456 Oak Ave, Portland, OR 97201', NULL,
        NULL, NULL
    ),
    -- Bob: cancelled
    (
        'd0000000-0000-4000-8000-000000000007', 'ORD-2026-0007',
        'b0000000-0000-4000-8000-000000000002', 'cancelled', '2026-04-18', '2026-04-18 12:00:00+00',
        129.99, 10.40, 0.00, 140.39,
        '456 Oak Ave, Portland, OR 97201', NULL,
        '2026-04-18 15:30:00+00', 'Customer changed mind before shipment'
    ),
    -- Carol: returned
    (
        'd0000000-0000-4000-8000-000000000008', 'ORD-2026-0008',
        'b0000000-0000-4000-8000-000000000003', 'returned', '2026-03-22', '2026-03-22 08:50:00+00',
        34.99, 2.80, 5.00, 42.79,
        '88 Lakeview Dr, Austin, TX 78701', 'Wrong size — return initiated',
        NULL, NULL
    ),
    -- David: shipped / out for delivery
    (
        'd0000000-0000-4000-8000-000000000009', 'ORD-2026-0009',
        'b0000000-0000-4000-8000-000000000004', 'shipped', '2026-05-11', '2026-05-11 07:40:00+00',
        104.97, 8.40, 5.00, 118.37,
        '2100 Market St, San Francisco, CA 94114', NULL,
        NULL, NULL
    ),
    -- Eva: processing
    (
        'd0000000-0000-4000-8000-000000000010', 'ORD-2026-0010',
        'b0000000-0000-4000-8000-000000000005', 'processing', '2026-05-16', '2026-05-16 13:10:00+00',
        59.99, 4.80, 0.00, 64.79,
        '15 Riverside Ct, Boston, MA 02108', 'Apartment 4B',
        NULL, NULL
    ),
    -- Frank: confirmed
    (
        'd0000000-0000-4000-8000-000000000011', 'ORD-2026-0011',
        'b0000000-0000-4000-8000-000000000006', 'confirmed', '2026-05-17', '2026-05-17 09:30:00+00',
        44.99, 3.60, 5.00, 53.59,
        '902 Cedar Ln, Denver, CO 80202', NULL,
        NULL, NULL
    ),
    -- Carol: pending multi-line
    (
        'd0000000-0000-4000-8000-000000000012', 'ORD-2026-0012',
        'b0000000-0000-4000-8000-000000000003', 'pending', '2026-05-17', '2026-05-17 20:05:00+00',
        154.96, 12.40, 0.00, 167.36,
        '88 Lakeview Dr, Austin, TX 78701', NULL,
        NULL, NULL
    );

-- ---------------------------------------------------------------------------
-- Order items
-- ---------------------------------------------------------------------------

INSERT INTO order_items (order_id, product_id, quantity, unit_price, line_total, fulfillment_status) VALUES
    ('d0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', 1, 49.99, 49.99, 'delivered'),
    ('d0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000004', 1, 129.99, 129.99, 'delivered'),
    ('d0000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000004', 1, 129.99, 129.99, 'shipped'),
    ('d0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000003', 1, 39.99, 39.99, 'allocated'),
    ('d0000000-0000-4000-8000-000000000004', 'c0000000-0000-4000-8000-000000000001', 1, 49.99, 49.99, 'pending'),
    ('d0000000-0000-4000-8000-000000000005', 'c0000000-0000-4000-8000-000000000007', 2, 24.99, 49.98, 'pending'),
    ('d0000000-0000-4000-8000-000000000005', 'c0000000-0000-4000-8000-000000000009', 1, 29.99, 29.99, 'pending'),
    ('d0000000-0000-4000-8000-000000000006', 'c0000000-0000-4000-8000-000000000002', 1, 79.99, 79.99, 'delivered'),
    ('d0000000-0000-4000-8000-000000000007', 'c0000000-0000-4000-8000-000000000004', 1, 129.99, 129.99, 'cancelled'),
    ('d0000000-0000-4000-8000-000000000008', 'c0000000-0000-4000-8000-000000000006', 1, 34.99, 34.99, 'delivered'),
    ('d0000000-0000-4000-8000-000000000009', 'c0000000-0000-4000-8000-000000000008', 1, 44.99, 44.99, 'shipped'),
    ('d0000000-0000-4000-8000-000000000009', 'c0000000-0000-4000-8000-000000000010', 3, 19.99, 59.97, 'shipped'),
    ('d0000000-0000-4000-8000-000000000010', 'c0000000-0000-4000-8000-000000000005', 1, 59.99, 59.99, 'picked'),
    ('d0000000-0000-4000-8000-000000000011', 'c0000000-0000-4000-8000-000000000008', 1, 44.99, 44.99, 'pending'),
    ('d0000000-0000-4000-8000-000000000012', 'c0000000-0000-4000-8000-000000000002', 1, 79.99, 79.99, 'pending'),
    ('d0000000-0000-4000-8000-000000000012', 'c0000000-0000-4000-8000-000000000005', 1, 59.99, 59.99, 'pending'),
    ('d0000000-0000-4000-8000-000000000012', 'c0000000-0000-4000-8000-000000000009', 1, 29.99, 29.99, 'pending');

-- ---------------------------------------------------------------------------
-- Shipments
-- ---------------------------------------------------------------------------

INSERT INTO shipments (id, order_id, carrier, tracking_number, status, shipped_at, estimated_delivery, delivered_at) VALUES
    (
        'e0000000-0000-4000-8000-000000000001',
        'd0000000-0000-4000-8000-000000000001',
        'UPS', '1Z999AA10123456784', 'delivered',
        '2026-04-29 08:00:00+00', '2026-05-02', '2026-05-01 14:22:00+00'
    ),
    (
        'e0000000-0000-4000-8000-000000000002',
        'd0000000-0000-4000-8000-000000000002',
        'FedEx', '794612345678', 'in_transit',
        '2026-05-09 10:30:00+00', '2026-05-13', NULL
    ),
    (
        'e0000000-0000-4000-8000-000000000003',
        'd0000000-0000-4000-8000-000000000006',
        'USPS', '9400111899223344556677', 'delivered',
        '2026-05-03 07:15:00+00', '2026-05-07', '2026-05-06 11:05:00+00'
    ),
    (
        'e0000000-0000-4000-8000-000000000004',
        'd0000000-0000-4000-8000-000000000008',
        'UPS', '1Z888BB20234567890', 'returned',
        '2026-03-24 09:00:00+00', '2026-03-27', '2026-03-26 17:40:00+00'
    ),
    (
        'e0000000-0000-4000-8000-000000000005',
        'd0000000-0000-4000-8000-000000000009',
        'DHL', 'JD014600003000123456', 'out_for_delivery',
        '2026-05-12 06:45:00+00', '2026-05-17', NULL
    );

-- ---------------------------------------------------------------------------
-- Order status history (realistic timelines)
-- ---------------------------------------------------------------------------

INSERT INTO order_status_history (order_id, from_status, to_status, note, changed_at) VALUES
    -- ORD-2026-0001 delivered path
    ('d0000000-0000-4000-8000-000000000001', NULL, 'pending', 'Order placed', '2026-04-28 09:12:00+00'),
    ('d0000000-0000-4000-8000-000000000001', 'pending', 'confirmed', 'Payment authorized', '2026-04-28 09:14:00+00'),
    ('d0000000-0000-4000-8000-000000000001', 'confirmed', 'processing', 'Sent to warehouse', '2026-04-28 12:00:00+00'),
    ('d0000000-0000-4000-8000-000000000001', 'processing', 'shipped', 'Carrier pickup', '2026-04-29 08:00:00+00'),
    ('d0000000-0000-4000-8000-000000000001', 'shipped', 'delivered', 'Proof of delivery captured', '2026-05-01 14:22:00+00'),
    -- ORD-2026-0002 shipped
    ('d0000000-0000-4000-8000-000000000002', NULL, 'pending', 'Order placed', '2026-05-08 14:05:00+00'),
    ('d0000000-0000-4000-8000-000000000002', 'pending', 'confirmed', 'Payment authorized', '2026-05-08 14:07:00+00'),
    ('d0000000-0000-4000-8000-000000000002', 'confirmed', 'processing', 'Picking started', '2026-05-08 18:00:00+00'),
    ('d0000000-0000-4000-8000-000000000002', 'processing', 'shipped', 'Label created — FedEx', '2026-05-09 10:30:00+00'),
    -- ORD-2026-0003 processing
    ('d0000000-0000-4000-8000-000000000003', NULL, 'pending', 'Order placed', '2026-05-14 11:22:00+00'),
    ('d0000000-0000-4000-8000-000000000003', 'pending', 'confirmed', 'Payment authorized', '2026-05-14 11:25:00+00'),
    ('d0000000-0000-4000-8000-000000000003', 'confirmed', 'processing', 'Gift wrap in progress', '2026-05-15 09:00:00+00'),
    -- ORD-2026-0004 confirmed
    ('d0000000-0000-4000-8000-000000000004', NULL, 'pending', 'Order placed', '2026-05-17 10:00:00+00'),
    ('d0000000-0000-4000-8000-000000000004', 'pending', 'confirmed', 'Payment authorized', '2026-05-17 10:02:00+00'),
    -- ORD-2026-0005 pending
    ('d0000000-0000-4000-8000-000000000005', NULL, 'pending', 'Order placed — awaiting payment confirmation', '2026-05-17 18:45:00+00'),
    -- ORD-2026-0006 delivered
    ('d0000000-0000-4000-8000-000000000006', NULL, 'pending', 'Order placed', '2026-05-02 16:30:00+00'),
    ('d0000000-0000-4000-8000-000000000006', 'pending', 'confirmed', 'Payment authorized', '2026-05-02 16:32:00+00'),
    ('d0000000-0000-4000-8000-000000000006', 'confirmed', 'processing', 'Sent to warehouse', '2026-05-02 20:00:00+00'),
    ('d0000000-0000-4000-8000-000000000006', 'processing', 'shipped', 'USPS pickup', '2026-05-03 07:15:00+00'),
    ('d0000000-0000-4000-8000-000000000006', 'shipped', 'delivered', 'Delivered to mailbox', '2026-05-06 11:05:00+00'),
    -- ORD-2026-0007 cancelled
    ('d0000000-0000-4000-8000-000000000007', NULL, 'pending', 'Order placed', '2026-04-18 12:00:00+00'),
    ('d0000000-0000-4000-8000-000000000007', 'pending', 'confirmed', 'Payment authorized', '2026-04-18 12:03:00+00'),
    ('d0000000-0000-4000-8000-000000000007', 'confirmed', 'cancelled', 'Customer changed mind before shipment', '2026-04-18 15:30:00+00'),
    -- ORD-2026-0008 returned
    ('d0000000-0000-4000-8000-000000000008', NULL, 'pending', 'Order placed', '2026-03-22 08:50:00+00'),
    ('d0000000-0000-4000-8000-000000000008', 'pending', 'confirmed', 'Payment authorized', '2026-03-22 08:52:00+00'),
    ('d0000000-0000-4000-8000-000000000008', 'confirmed', 'processing', 'Sent to warehouse', '2026-03-22 14:00:00+00'),
    ('d0000000-0000-4000-8000-000000000008', 'processing', 'shipped', 'UPS pickup', '2026-03-24 09:00:00+00'),
    ('d0000000-0000-4000-8000-000000000008', 'shipped', 'delivered', 'Delivered', '2026-03-26 17:40:00+00'),
    ('d0000000-0000-4000-8000-000000000008', 'delivered', 'returned', 'Return received at warehouse', '2026-04-02 10:15:00+00'),
    -- ORD-2026-0009 shipped
    ('d0000000-0000-4000-8000-000000000009', NULL, 'pending', 'Order placed', '2026-05-11 07:40:00+00'),
    ('d0000000-0000-4000-8000-000000000009', 'pending', 'confirmed', 'Payment authorized', '2026-05-11 07:42:00+00'),
    ('d0000000-0000-4000-8000-000000000009', 'confirmed', 'processing', 'Fulfillment started', '2026-05-11 15:00:00+00'),
    ('d0000000-0000-4000-8000-000000000009', 'processing', 'shipped', 'DHL — out for delivery', '2026-05-12 06:45:00+00'),
    -- ORD-2026-0010 processing
    ('d0000000-0000-4000-8000-000000000010', NULL, 'pending', 'Order placed', '2026-05-16 13:10:00+00'),
    ('d0000000-0000-4000-8000-000000000010', 'pending', 'confirmed', 'Payment authorized', '2026-05-16 13:12:00+00'),
    ('d0000000-0000-4000-8000-000000000010', 'confirmed', 'processing', 'Warehouse picking', '2026-05-17 08:30:00+00'),
    -- ORD-2026-0011 confirmed
    ('d0000000-0000-4000-8000-000000000011', NULL, 'pending', 'Order placed', '2026-05-17 09:30:00+00'),
    ('d0000000-0000-4000-8000-000000000011', 'pending', 'confirmed', 'Payment authorized', '2026-05-17 09:32:00+00'),
    -- ORD-2026-0012 pending
    ('d0000000-0000-4000-8000-000000000012', NULL, 'pending', 'Order placed', '2026-05-17 20:05:00+00');

SET session_replication_role = DEFAULT;

-- Quick sanity check
SELECT 'users' AS entity, COUNT(*)::INT AS rows FROM users
UNION ALL SELECT 'product_categories', COUNT(*)::INT FROM product_categories
UNION ALL SELECT 'products', COUNT(*)::INT FROM products
UNION ALL SELECT 'orders', COUNT(*)::INT FROM orders
UNION ALL SELECT 'order_items', COUNT(*)::INT FROM order_items
UNION ALL SELECT 'shipments', COUNT(*)::INT FROM shipments
UNION ALL SELECT 'order_status_history', COUNT(*)::INT FROM order_status_history
ORDER BY entity;
