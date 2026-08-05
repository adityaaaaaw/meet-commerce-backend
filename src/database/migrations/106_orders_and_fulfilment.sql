-- Migration 106: Customer Orders, 17-State Machine & Fulfilment Workflow
-- Source of truth: Blueprint §06.7, Phase 8

-- 1. Orders Table
CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_number VARCHAR(100) UNIQUE NOT NULL,
  quote_id UUID REFERENCES checkout_quotes(id) ON DELETE SET NULL,
  customer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  warehouse_id UUID REFERENCES warehouses(id) ON DELETE SET NULL,
  status TEXT NOT NULL CHECK (status IN (
    'CART_CREATED', 'ORDER_PLACED', 'PAYMENT_PENDING', 'PAYMENT_CONFIRMED',
    'CONFIRMED', 'ALLOCATING_STOCK', 'STOCK_RESERVED', 'PICKING', 'PACKING',
    'READY_FOR_DISPATCH', 'DISPATCHED', 'OUT_FOR_DELIVERY', 'DELIVERED',
    'COMPLETED', 'CANCELLED', 'PAYMENT_FAILED', 'RETURN_REQUESTED', 'RETURNED'
  )) DEFAULT 'ORDER_PLACED',
  subtotal NUMERIC(10,2) NOT NULL,
  discount_amount NUMERIC(10,2) NOT NULL DEFAULT 0.00,
  loyalty_redeemed_amount NUMERIC(10,2) NOT NULL DEFAULT 0.00,
  tax_amount NUMERIC(10,2) NOT NULL DEFAULT 0.00,
  total_payable NUMERIC(10,2) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_warehouse ON orders(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);

-- 2. Order Items Table
CREATE TABLE IF NOT EXISTS order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  product_name VARCHAR(255) NOT NULL,
  quantity NUMERIC(10,2) NOT NULL CHECK (quantity > 0),
  unit_price NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0),
  subtotal NUMERIC(10,2) NOT NULL,
  product_snapshot JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id);

-- 3. Order Status History Table (Append-Only)
CREATE TABLE IF NOT EXISTS order_status_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  from_status TEXT,
  to_status TEXT NOT NULL,
  actor_id UUID REFERENCES users(id) ON DELETE SET NULL,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_order_status_hist_order ON order_status_history(order_id);

-- 4. Fulfilment Tasks Table
CREATE TABLE IF NOT EXISTS fulfilment_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  task_type TEXT NOT NULL CHECK (task_type IN ('PICKING', 'PACKING')),
  assigned_to UUID REFERENCES users(id) ON DELETE SET NULL,
  status TEXT NOT NULL CHECK (status IN ('PENDING', 'IN_PROGRESS', 'COMPLETED', 'FAILED')) DEFAULT 'PENDING',
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fulfilment_tasks_order ON fulfilment_tasks(order_id);

-- 5. Order Audit Logs Table (Append-Only)
CREATE TABLE IF NOT EXISTS order_audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  actor_id UUID REFERENCES users(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_order_audits_order ON order_audit_logs(order_id);

-- 6. Automatic Timestamp Triggers
DROP TRIGGER IF EXISTS trg_orders_updated_at ON orders;
CREATE TRIGGER trg_orders_updated_at
  BEFORE UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION update_timestamp();

DROP TRIGGER IF EXISTS trg_order_items_updated_at ON order_items;
CREATE TRIGGER trg_order_items_updated_at
  BEFORE UPDATE ON order_items
  FOR EACH ROW
  EXECUTE FUNCTION update_timestamp();

DROP TRIGGER IF EXISTS trg_fulfilment_tasks_updated_at ON fulfilment_tasks;
CREATE TRIGGER trg_fulfilment_tasks_updated_at
  BEFORE UPDATE ON fulfilment_tasks
  FOR EACH ROW
  EXECUTE FUNCTION update_timestamp();
