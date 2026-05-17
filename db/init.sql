-- AgentResolve: existing orders schema for agentic workflows
-- Query order status, search orders, cancel eligible orders (no new orders / no stock)
-- Runs once on first container start via /docker-entrypoint-initdb.d/

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

CREATE SCHEMA IF NOT EXISTS orders;
SET search_path TO orders, public;

-- ---------------------------------------------------------------------------
-- Types
-- ---------------------------------------------------------------------------

CREATE TYPE order_status AS ENUM (
    'pending',
    'confirmed',
    'processing',
    'shipped',
    'delivered',
    'cancelled',
    'returned'
);

CREATE TYPE fulfillment_status AS ENUM (
    'pending',
    'allocated',
    'picked',
    'packed',
    'shipped',
    'delivered',
    'cancelled'
);

CREATE TYPE shipment_status AS ENUM (
    'label_created',
    'in_transit',
    'out_for_delivery',
    'delivered',
    'exception',
    'returned'
);

-- ---------------------------------------------------------------------------
-- Core tables
-- ---------------------------------------------------------------------------

CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email           VARCHAR(255) NOT NULL UNIQUE,
    full_name       VARCHAR(255) NOT NULL,
    phone           VARCHAR(32),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE product_categories (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(128) NOT NULL UNIQUE,
    description     TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Product catalog for line items on existing orders (lookup by name/SKU only)
CREATE TABLE products (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sku             VARCHAR(64) NOT NULL UNIQUE,
    name            VARCHAR(255) NOT NULL,
    description     TEXT,
    category_id     UUID REFERENCES product_categories (id) ON DELETE SET NULL,
    unit_price      NUMERIC(12, 2) NOT NULL CHECK (unit_price >= 0),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE orders (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id            VARCHAR(32) NOT NULL UNIQUE,
    user_id             UUID NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
    status              order_status NOT NULL DEFAULT 'pending',
    order_date          DATE NOT NULL DEFAULT CURRENT_DATE,
    placed_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    currency            CHAR(3) NOT NULL DEFAULT 'USD',
    subtotal            NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (subtotal >= 0),
    tax_amount          NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (tax_amount >= 0),
    shipping_amount     NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (shipping_amount >= 0),
    total_amount        NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
    shipping_address    TEXT,
    customer_notes      TEXT,
    cancelled_at        TIMESTAMPTZ,
    cancellation_reason TEXT,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT orders_cancelled_fields_check CHECK (
        (status = 'cancelled' AND cancelled_at IS NOT NULL)
        OR (status <> 'cancelled' AND cancelled_at IS NULL AND cancellation_reason IS NULL)
    )
);

CREATE TABLE order_items (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id            UUID NOT NULL REFERENCES orders (id) ON DELETE CASCADE,
    product_id          UUID NOT NULL REFERENCES products (id) ON DELETE RESTRICT,
    quantity            INTEGER NOT NULL CHECK (quantity > 0),
    unit_price          NUMERIC(12, 2) NOT NULL CHECK (unit_price >= 0),
    line_total          NUMERIC(12, 2) NOT NULL CHECK (line_total >= 0),
    fulfillment_status  fulfillment_status NOT NULL DEFAULT 'pending',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (order_id, product_id)
);

CREATE TABLE order_status_history (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id        UUID NOT NULL REFERENCES orders (id) ON DELETE CASCADE,
    from_status     order_status,
    to_status       order_status NOT NULL,
    note            TEXT,
    changed_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE shipments (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id            UUID NOT NULL REFERENCES orders (id) ON DELETE CASCADE,
    carrier             VARCHAR(64),
    tracking_number     VARCHAR(128),
    status              shipment_status NOT NULL DEFAULT 'label_created',
    shipped_at          TIMESTAMPTZ,
    estimated_delivery  DATE,
    delivered_at        TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- Indexes (order lookup & search)
-- ---------------------------------------------------------------------------

CREATE INDEX idx_users_email ON users (email);
CREATE INDEX idx_users_email_trgm ON users USING gin (email gin_trgm_ops);
CREATE INDEX idx_users_full_name_trgm ON users USING gin (full_name gin_trgm_ops);

CREATE INDEX idx_products_sku ON products (sku);
CREATE INDEX idx_products_category ON products (category_id);
CREATE INDEX idx_products_name_trgm ON products USING gin (name gin_trgm_ops);

CREATE INDEX idx_orders_user_id ON orders (user_id);
CREATE INDEX idx_orders_order_id ON orders (order_id);
CREATE INDEX idx_orders_status ON orders (status);
CREATE INDEX idx_orders_order_date ON orders (order_date DESC);
CREATE INDEX idx_orders_placed_at ON orders (placed_at DESC);
CREATE INDEX idx_orders_user_date ON orders (user_id, order_date DESC);
CREATE INDEX idx_orders_user_status ON orders (user_id, status);
CREATE INDEX idx_orders_cancellable ON orders (user_id, order_date DESC)
    WHERE status IN ('pending', 'confirmed', 'processing');

CREATE INDEX idx_order_items_order_id ON order_items (order_id);
CREATE INDEX idx_order_items_product_id ON order_items (product_id);

CREATE INDEX idx_order_status_history_order ON order_status_history (order_id, changed_at DESC);

CREATE INDEX idx_shipments_order_id ON shipments (order_id);
CREATE INDEX idx_shipments_tracking ON shipments (tracking_number)
    WHERE tracking_number IS NOT NULL;

-- ---------------------------------------------------------------------------
-- Views (common agent query shapes)
-- ---------------------------------------------------------------------------

CREATE VIEW order_details AS
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
FROM orders o
JOIN users u ON u.id = o.user_id;

CREATE VIEW order_line_items AS
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
FROM order_items oi
JOIN orders o ON o.id = oi.order_id
JOIN users u ON u.id = o.user_id
JOIN products p ON p.id = oi.product_id;

-- Orders that can still be cancelled or have address updated (not yet shipped)
CREATE VIEW modifiable_orders AS
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
FROM orders o
JOIN users u ON u.id = o.user_id
WHERE o.status IN ('pending', 'confirmed', 'processing');

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_products_updated_at
    BEFORE UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_orders_updated_at
    BEFORE UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE OR REPLACE FUNCTION log_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO orders.order_status_history (order_id, from_status, to_status, note)
        VALUES (
            NEW.id,
            CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE OLD.status END,
            NEW.status,
            CASE
                WHEN NEW.status = 'cancelled' THEN COALESCE(NEW.cancellation_reason, 'Order cancelled')
                ELSE 'Status updated'
            END
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_orders_status_history
    AFTER INSERT OR UPDATE OF status ON orders
    FOR EACH ROW EXECUTE FUNCTION log_order_status_change();
