-- Drop the redundant address column and rebuild affected views.
-- Run on existing databases:
--   docker exec -i agentresolve-postgres psql -U agentresolve -d agentresolve < db/migrations/002_drop_address.sql

ALTER TABLE orders.orders
    DROP COLUMN IF EXISTS address;

ALTER TABLE orders.users
    DROP COLUMN IF EXISTS user_id;

ALTER TABLE orders.users
    ADD CONSTRAINT users_email_key UNIQUE (email);

CREATE OR REPLACE VIEW orders.order_details AS
SELECT
    o.order_id,
    o.status,
    o.order_date,
    o.placed_at,
    o.currency,
    o.subtotal,
    o.tax_amount,
    o.shipping_amount,
    o.total_amount,
    o.shipping_address,
    o.customer_notes,
    o.cancelled_at,
    o.cancellation_reason,
    u.id AS user_id,
    u.email,
    u.full_name AS customer_name,
    u.phone AS customer_phone
FROM orders.orders o
JOIN orders.users u ON u.id = o.user_id;

CREATE OR REPLACE VIEW orders.order_line_items AS
SELECT
    o.order_id,
    o.status AS order_status,
    o.order_date,
    u.id AS user_id,
    u.email,
    p.sku,
    p.name AS product_name,
    oi.quantity,
    oi.unit_price,
    oi.line_total,
    oi.fulfillment_status
FROM orders.order_items oi
JOIN orders.orders o ON o.id = oi.order_id
JOIN orders.users u ON u.id = o.user_id
JOIN orders.products p ON p.id = oi.product_id;

CREATE OR REPLACE VIEW orders.modifiable_orders AS
SELECT
    o.order_id,
    o.status,
    o.order_date,
    o.placed_at,
    o.total_amount,
    o.shipping_address,
    u.id AS user_id,
    u.email,
    u.full_name AS customer_name
FROM orders.orders o
JOIN orders.users u ON u.id = o.user_id
WHERE o.status IN ('pending', 'confirmed', 'processing');

DROP VIEW IF EXISTS orders.cancellable_orders;
