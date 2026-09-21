-- =============================================================================
-- Sample data for pattern testing (real DB rows — not fake UI data)
-- Run AFTER: initial_schema.sql → rls_policies.sql → seed.sql
-- =============================================================================

-- Fixed IDs (match seed.sql businesses)
-- Clothing: a1000000-0000-4000-8000-000000000001
-- Cars:     a1000000-0000-4000-8000-000000000002

-- -----------------------------------------------------------------------------
-- Customers — Drape & Dream (clothing)
-- -----------------------------------------------------------------------------
INSERT INTO public.customers (id, business_id, name, mobile, email, address)
VALUES
  (
    'b2000000-0000-4000-8000-000000000001',
    'a1000000-0000-4000-8000-000000000001',
    'Rahul Sharma',
    '9876543210',
    'rahul.sharma@gmail.com',
    'Andheri West, Mumbai 400058'
  ),
  (
    'b2000000-0000-4000-8000-000000000002',
    'a1000000-0000-4000-8000-000000000001',
    'Priya Patel',
    '9123456780',
    'priya.patel@gmail.com',
    'Bandra East, Mumbai 400051'
  ),
  (
    'b2000000-0000-4000-8000-000000000003',
    'a1000000-0000-4000-8000-000000000001',
    'Amit Verma',
    '9988776655',
    'amit.verma@gmail.com',
    'Powai, Mumbai 400076'
  )
ON CONFLICT (id) DO NOTHING;

-- Customers — Your Dream Cars
INSERT INTO public.customers (id, business_id, name, mobile, email, address)
VALUES
  (
    'b2000000-0000-4000-8000-000000000010',
    'a1000000-0000-4000-8000-000000000002',
    'Sanjay Mehta',
    '9812345678',
    'sanjay.mehta@gmail.com',
    'Koregaon Park, Pune 411001'
  ),
  (
    'b2000000-0000-4000-8000-000000000011',
    'a1000000-0000-4000-8000-000000000002',
    'Neha Kulkarni',
    '9823456789',
    'neha.kulkarni@gmail.com',
    'Hinjewadi, Pune 411057'
  )
ON CONFLICT (id) DO NOTHING;

-- -----------------------------------------------------------------------------
-- Products + variants — clothing only (with barcodes for scan testing)
-- -----------------------------------------------------------------------------
INSERT INTO public.products (id, business_id, name, brand, category, sub_category, base_price, tax_rate)
VALUES
  (
    'c3000000-0000-4000-8000-000000000001',
    'a1000000-0000-4000-8000-000000000001',
    'Oxford Cotton Shirt',
    'Drape',
    'Shirts',
    'Formal',
    1499.00,
    12.00
  ),
  (
    'c3000000-0000-4000-8000-000000000002',
    'a1000000-0000-4000-8000-000000000001',
    'Slim Fit Chinos',
    'Dreamwear',
    'Trousers',
    'Casual',
    2199.00,
    12.00
  ),
  (
    'c3000000-0000-4000-8000-000000000003',
    'a1000000-0000-4000-8000-000000000001',
    'Linen Kurta',
    'Drape',
    'Ethnic',
    'Kurta',
    1899.00,
    5.00
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.product_variants (
  id, business_id, product_id, size, color, fabric,
  selling_price, tax_rate, barcode, barcode_format
)
VALUES
  (
    'd4000000-0000-4000-8000-000000000001',
    'a1000000-0000-4000-8000-000000000001',
    'c3000000-0000-4000-8000-000000000001',
    'M', 'Black', 'Cotton',
    1499.00, 12.00, 'DD2603000001', 'CODE128'
  ),
  (
    'd4000000-0000-4000-8000-000000000002',
    'a1000000-0000-4000-8000-000000000001',
    'c3000000-0000-4000-8000-000000000001',
    'L', 'Black', 'Cotton',
    1499.00, 12.00, 'DD2603000002', 'CODE128'
  ),
  (
    'd4000000-0000-4000-8000-000000000003',
    'a1000000-0000-4000-8000-000000000001',
    'c3000000-0000-4000-8000-000000000001',
    'M', 'White', 'Cotton',
    1499.00, 12.00, 'DD2603000003', 'CODE128'
  ),
  (
    'd4000000-0000-4000-8000-000000000004',
    'a1000000-0000-4000-8000-000000000001',
    'c3000000-0000-4000-8000-000000000002',
    '32', 'Navy', 'Cotton blend',
    2199.00, 12.00, 'DD2603000004', 'CODE128'
  ),
  (
    'd4000000-0000-4000-8000-000000000005',
    'a1000000-0000-4000-8000-000000000001',
    'c3000000-0000-4000-8000-000000000003',
    'XL', 'Beige', 'Linen',
    1899.00, 5.00, 'DD2603000005', 'CODE128'
  )
ON CONFLICT (id) DO NOTHING;

-- -----------------------------------------------------------------------------
-- Invoices — Drape & Dream
-- -----------------------------------------------------------------------------
INSERT INTO public.invoices (
  id, business_id, customer_id, invoice_number, invoice_date,
  status, payment_status,
  subtotal, discount_amount, tax_amount, additional_charges, grand_total,
  amount_paid, amount_outstanding, notes
)
VALUES
  (
    'e5000000-0000-4000-8000-000000000001',
    'a1000000-0000-4000-8000-000000000001',
    'b2000000-0000-4000-8000-000000000001',
    'DD-00001',
    CURRENT_DATE,
    'issued', 'paid',
    1499.00, 0, 179.88, 0, 1678.88,
    1678.88, 0, 'Oxford shirt — Black / M'
  ),
  (
    'e5000000-0000-4000-8000-000000000002',
    'a1000000-0000-4000-8000-000000000001',
    'b2000000-0000-4000-8000-000000000002',
    'DD-00002',
    CURRENT_DATE,
    'issued', 'partial',
    3698.00, 0, 443.76, 0, 4141.76,
    2000.00, 2141.76, 'Shirt + Chinos combo'
  ),
  (
    'e5000000-0000-4000-8000-000000000003',
    'a1000000-0000-4000-8000-000000000001',
    'b2000000-0000-4000-8000-000000000003',
    'DD-00003',
    CURRENT_DATE - 5,
    'issued', 'pending',
    1899.00, 0, 94.95, 0, 1993.95,
    0, 1993.95, 'Linen kurta — pending payment'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.invoice_items (
  id, business_id, invoice_id, product_variant_id,
  description, quantity, unit_price, discount_amount, tax_rate, tax_amount, line_total,
  size, color, barcode, sort_order
)
VALUES
  (
    'f6000000-0000-4000-8000-000000000001',
    'a1000000-0000-4000-8000-000000000001',
    'e5000000-0000-4000-8000-000000000001',
    'd4000000-0000-4000-8000-000000000001',
    'Drape / Oxford Cotton Shirt / Black / M',
    1, 1499.00, 0, 12.00, 179.88, 1678.88,
    'M', 'Black', 'DD2603000001', 1
  ),
  (
    'f6000000-0000-4000-8000-000000000002',
    'a1000000-0000-4000-8000-000000000001',
    'e5000000-0000-4000-8000-000000000002',
    'd4000000-0000-4000-8000-000000000003',
    'Drape / Oxford Cotton Shirt / White / M',
    1, 1499.00, 0, 12.00, 179.88, 1678.88,
    'M', 'White', 'DD2603000003', 1
  ),
  (
    'f6000000-0000-4000-8000-000000000003',
    'a1000000-0000-4000-8000-000000000001',
    'e5000000-0000-4000-8000-000000000002',
    'd4000000-0000-4000-8000-000000000004',
    'Dreamwear / Slim Fit Chinos / Navy / 32',
    1, 2199.00, 0, 12.00, 263.88, 2462.88,
    '32', 'Navy', 'DD2603000004', 2
  ),
  (
    'f6000000-0000-4000-8000-000000000004',
    'a1000000-0000-4000-8000-000000000001',
    'e5000000-0000-4000-8000-000000000003',
    'd4000000-0000-4000-8000-000000000005',
    'Drape / Linen Kurta / Beige / XL',
    1, 1899.00, 0, 5.00, 94.95, 1993.95,
    'XL', 'Beige', 'DD2603000005', 1
  )
ON CONFLICT (id) DO NOTHING;

-- Payments — clothing (trigger recalculates invoice totals)
INSERT INTO public.payments (id, business_id, invoice_id, amount, payment_date, payment_method, reference_number)
VALUES
  (
    'a7000000-0000-4000-8000-000000000001',
    'a1000000-0000-4000-8000-000000000001',
    'e5000000-0000-4000-8000-000000000001',
    1678.88, CURRENT_DATE, 'upi', 'UPI789012345'
  ),
  (
    'a7000000-0000-4000-8000-000000000002',
    'a1000000-0000-4000-8000-000000000001',
    'e5000000-0000-4000-8000-000000000002',
    2000.00, CURRENT_DATE, 'cash', NULL
  )
ON CONFLICT (id) DO NOTHING;

-- -----------------------------------------------------------------------------
-- Invoices — Your Dream Cars
-- -----------------------------------------------------------------------------
INSERT INTO public.invoices (
  id, business_id, customer_id, invoice_number, invoice_date,
  status, payment_status,
  subtotal, discount_amount, tax_amount, additional_charges, grand_total,
  amount_paid, amount_outstanding, notes,
  car_make, car_model, car_variant, car_registration_number,
  car_chassis_number, car_engine_number, car_manufacturing_year, car_color, car_fuel_type
)
VALUES
  (
    'e5000000-0000-4000-8000-000000000010',
    'a1000000-0000-4000-8000-000000000002',
    'b2000000-0000-4000-8000-000000000010',
    'YDC-00001',
    CURRENT_DATE,
    'issued', 'paid',
    850000.00, 0, 153000.00, 5000.00, 1008000.00,
    1008000.00, 0, 'Honda City delivery',
    'Honda', 'City', 'VX CVT', 'MH12AB1234',
    'CHS1234567890', 'ENG9876543210', 2024, 'White', 'Petrol'
  ),
  (
    'e5000000-0000-4000-8000-000000000011',
    'a1000000-0000-4000-8000-000000000002',
    'b2000000-0000-4000-8000-000000000011',
    'YDC-00002',
    CURRENT_DATE - 3,
    'issued', 'partial',
    1200000.00, 0, 216000.00, 0, 1416000.00,
    500000.00, 916000.00, 'Hyundai Creta booking',
    'Hyundai', 'Creta', 'SX(O) Diesel', 'MH14CD5678',
    'CHS5678901234', 'ENG1234567890', 2025, 'Black', 'Diesel'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.invoice_items (
  id, business_id, invoice_id, description,
  quantity, unit_price, discount_amount, tax_rate, tax_amount, line_total, sort_order
)
VALUES
  (
    'f6000000-0000-4000-8000-000000000010',
    'a1000000-0000-4000-8000-000000000002',
    'e5000000-0000-4000-8000-000000000010',
    'Honda City VX CVT — On-road price',
    1, 850000.00, 0, 18.00, 153000.00, 1003000.00, 1
  ),
  (
    'f6000000-0000-4000-8000-000000000011',
    'a1000000-0000-4000-8000-000000000002',
    'e5000000-0000-4000-8000-000000000011',
    'Hyundai Creta SX(O) Diesel — On-road price',
    1, 1200000.00, 0, 18.00, 216000.00, 1416000.00, 1
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.payments (id, business_id, invoice_id, amount, payment_date, payment_method, reference_number)
VALUES
  (
    'a7000000-0000-4000-8000-000000000010',
    'a1000000-0000-4000-8000-000000000002',
    'e5000000-0000-4000-8000-000000000010',
    500000.00, CURRENT_DATE - 7, 'bank_transfer', 'NEFT001122'
  ),
  (
    'a7000000-0000-4000-8000-000000000011',
    'a1000000-0000-4000-8000-000000000002',
    'e5000000-0000-4000-8000-000000000010',
    508000.00, CURRENT_DATE, 'upi', 'UPI998877665'
  ),
  (
    'a7000000-0000-4000-8000-000000000012',
    'a1000000-0000-4000-8000-000000000002',
    'e5000000-0000-4000-8000-000000000011',
    500000.00, CURRENT_DATE - 2, 'cash', NULL
  )
ON CONFLICT (id) DO NOTHING;

-- Next invoice numbers
UPDATE public.invoice_settings
SET next_invoice_number = 4
WHERE business_id = 'a1000000-0000-4000-8000-000000000001';

UPDATE public.invoice_settings
SET next_invoice_number = 3
WHERE business_id = 'a1000000-0000-4000-8000-000000000002';
