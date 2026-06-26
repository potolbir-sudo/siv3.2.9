/*
# Multi-Unit Product System

## Overview
This migration adds support for:
1. Product colors - different color variants for products
2. Product sizes - different size options for products  
3. Product units - multiple units of measure with conversion and pricing
4. Stock tracking in base units with display in sale units

## New Tables

### product_colors
- `id` (uuid, primary key)
- `product_id` (uuid, FK to products)
- `name` (text) - Color name e.g., "White", "Black"
- `hex_code` (text) - Hex color code for display
- `image_url` (text) - Optional image for this color variant
- `is_default` (boolean) - Default color selection
- `sort_order` (integer) - Display order

### product_sizes
- `id` (uuid, primary key)
- `product_id` (uuid, FK to products)
- `name` (text) - Size name e.g., "Small", "Large", "60x60cm"
- `dimensions` (text) - Optional dimensions description
- `is_default` (boolean) - Default size selection
- `sort_order` (integer) - Display order

### product_units
- `id` (uuid, primary key)
- `product_id` (uuid, FK to products)
- `unit_name` (text) - Unit name e.g., "Box", "Piece", "Coil", "Meter"
- `unit_short` (text) - Short form e.g., "bx", "pc", "coil", "m"
- `conversion_factor` (decimal) - How many base units = 1 of this unit
- `is_base_unit` (boolean) - Whether this is the base/smallest unit
- `is_sale_unit` (boolean) - Preferred unit for sales display
- `price` (decimal) - Price per unit
- `cost_price` (decimal) - Cost price per unit
- `barcode` (text) - Optional barcode for this unit
- `sort_order` (integer) - Display order

## Modified Tables

### products
- Added `base_unit` (text) - The base unit name (smallest unit)
- Added `enable_multi_unit` (boolean) - Flag to enable multi-unit system
- Added `enable_colors` (boolean) - Flag to enable color variants
- Added `enable_sizes` (boolean) - Flag to enable size variants

### invoice_items
- Added `unit_name` (text) - Unit selected during sale
- Added `unit_conversion_factor` (decimal) - Conversion factor used
- Added `base_quantity` (decimal) - Quantity converted to base unit

### purchase_order_items
- Added `unit_name` (text) - Unit selected during purchase
- Added `unit_conversion_factor` (decimal) - Conversion factor used
- Added `base_quantity` (decimal) - Quantity converted to base unit

### stock_movements
- Added `unit_name` (text) - Unit of the movement
- Added `unit_conversion_factor` (decimal) - Conversion factor used
- Added `base_quantity` (decimal) - Quantity in base units

## Security
- RLS enabled on all new tables
- Authenticated users have full access (internal ERP system)

## Important Notes
1. Stock is always tracked in base units internally
2. Prices are stored per unit in product_units
3. Conversion factor defines: 1 this_unit = X base_units
4. Example: Box with conversion_factor=100 means 1 Box = 100 base units (pieces)
*/

-- ============================================================
-- Add columns to products table
-- ============================================================
ALTER TABLE products ADD COLUMN IF NOT EXISTS base_unit text DEFAULT 'pcs';
ALTER TABLE products ADD COLUMN IF NOT EXISTS enable_multi_unit boolean DEFAULT false;
ALTER TABLE products ADD COLUMN IF NOT EXISTS enable_colors boolean DEFAULT false;
ALTER TABLE products ADD COLUMN IF NOT EXISTS enable_sizes boolean DEFAULT false;

-- ============================================================
-- PRODUCT COLORS
-- ============================================================
CREATE TABLE IF NOT EXISTS product_colors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT '00000000-0000-0000-0000-000000000001',
  product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  name text NOT NULL,
  hex_code text,
  image_url text,
  is_default boolean NOT NULL DEFAULT false,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS product_colors_product ON product_colors(product_id);
ALTER TABLE product_colors ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "pc_select" ON product_colors;
CREATE POLICY "pc_select" ON product_colors FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "pc_insert" ON product_colors;
CREATE POLICY "pc_insert" ON product_colors FOR INSERT TO authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "pc_update" ON product_colors;
CREATE POLICY "pc_update" ON product_colors FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "pc_delete" ON product_colors;
CREATE POLICY "pc_delete" ON product_colors FOR DELETE TO authenticated USING (true);

-- ============================================================
-- PRODUCT SIZES
-- ============================================================
CREATE TABLE IF NOT EXISTS product_sizes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT '00000000-0000-0000-0000-000000000001',
  product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  name text NOT NULL,
  dimensions text,
  is_default boolean NOT NULL DEFAULT false,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS product_sizes_product ON product_sizes(product_id);
ALTER TABLE product_sizes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ps_select" ON product_sizes;
CREATE POLICY "ps_select" ON product_sizes FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "ps_insert" ON product_sizes;
CREATE POLICY "ps_insert" ON product_sizes FOR INSERT TO authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "ps_update" ON product_sizes;
CREATE POLICY "ps_update" ON product_sizes FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "ps_delete" ON product_sizes;
CREATE POLICY "ps_delete" ON product_sizes FOR DELETE TO authenticated USING (true);

-- ============================================================
-- PRODUCT UNITS
-- ============================================================
CREATE TABLE IF NOT EXISTS product_units (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT '00000000-0000-0000-0000-000000000001',
  product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  unit_name text NOT NULL,
  unit_short text,
  conversion_factor decimal(15,4) NOT NULL DEFAULT 1,
  is_base_unit boolean NOT NULL DEFAULT false,
  is_sale_unit boolean NOT NULL DEFAULT false,
  price decimal(15,2) NOT NULL DEFAULT 0,
  cost_price decimal(15,2) NOT NULL DEFAULT 0,
  barcode text,
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS product_units_product ON product_units(product_id);
ALTER TABLE product_units ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "pu_select" ON product_units;
CREATE POLICY "pu_select" ON product_units FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "pu_insert" ON product_units;
CREATE POLICY "pu_insert" ON product_units FOR INSERT TO authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "pu_update" ON product_units;
CREATE POLICY "pu_update" ON product_units FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "pu_delete" ON product_units;
CREATE POLICY "pu_delete" ON product_units FOR DELETE TO authenticated USING (true);

-- ============================================================
-- Add columns to invoice_items
-- ============================================================
ALTER TABLE invoice_items ADD COLUMN IF NOT EXISTS unit_name text;
ALTER TABLE invoice_items ADD COLUMN IF NOT EXISTS unit_conversion_factor decimal(15,4) DEFAULT 1;
ALTER TABLE invoice_items ADD COLUMN IF NOT EXISTS base_quantity decimal(15,3);

-- ============================================================
-- Add columns to quotation_items
-- ============================================================
ALTER TABLE quotation_items ADD COLUMN IF NOT EXISTS unit_name text;
ALTER TABLE quotation_items ADD COLUMN IF NOT EXISTS unit_conversion_factor decimal(15,4) DEFAULT 1;
ALTER TABLE quotation_items ADD COLUMN IF NOT EXISTS base_quantity decimal(15,3);

-- ============================================================
-- Add columns to purchase_order_items
-- ============================================================
ALTER TABLE purchase_order_items ADD COLUMN IF NOT EXISTS unit_name text;
ALTER TABLE purchase_order_items ADD COLUMN IF NOT EXISTS unit_conversion_factor decimal(15,4) DEFAULT 1;
ALTER TABLE purchase_order_items ADD COLUMN IF NOT EXISTS base_quantity decimal(15,3);

-- ============================================================
-- Add columns to stock_movements
-- ============================================================
ALTER TABLE stock_movements ADD COLUMN IF NOT EXISTS unit_name text;
ALTER TABLE stock_movements ADD COLUMN IF NOT EXISTS unit_conversion_factor decimal(15,4) DEFAULT 1;
ALTER TABLE stock_movements ADD COLUMN IF NOT EXISTS base_quantity decimal(15,3);

-- ============================================================
-- Add columns to delivery_items
-- ============================================================
ALTER TABLE delivery_items ADD COLUMN IF NOT EXISTS unit_name text;
ALTER TABLE delivery_items ADD COLUMN IF NOT EXISTS base_quantity decimal(15,3);

-- ============================================================
-- Add columns to online_order_items
-- ============================================================
ALTER TABLE online_order_items ADD COLUMN IF NOT EXISTS unit_name text;
ALTER TABLE online_order_items ADD COLUMN IF NOT EXISTS unit_conversion_factor decimal(15,4) DEFAULT 1;
ALTER TABLE online_order_items ADD COLUMN IF NOT EXISTS base_quantity decimal(15,3);