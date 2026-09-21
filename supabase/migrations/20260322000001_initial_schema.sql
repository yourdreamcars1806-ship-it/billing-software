-- =============================================================================
-- Multi-Business Billing Software — Initial Schema
-- Businesses: Drape & Dream (clothing), Your Dream Cars (car billing)
-- Tenant isolation via business_id + RLS
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- -----------------------------------------------------------------------------
-- Enums
-- -----------------------------------------------------------------------------
CREATE TYPE public.business_type AS ENUM ('clothing', 'car');
CREATE TYPE public.payment_method AS ENUM ('cash', 'upi', 'card', 'bank_transfer', 'other');
CREATE TYPE public.payment_status AS ENUM ('paid', 'partial', 'pending');
CREATE TYPE public.invoice_status AS ENUM ('draft', 'issued', 'cancelled');

-- -----------------------------------------------------------------------------
-- Profiles (extends auth.users)
-- -----------------------------------------------------------------------------
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  full_name TEXT,
  avatar_url TEXT,
  remember_session BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- Businesses
-- -----------------------------------------------------------------------------
CREATE TABLE public.businesses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  business_type public.business_type NOT NULL,
  description TEXT,
  logo_url TEXT,
  address TEXT,
  phone TEXT,
  email TEXT,
  gstin TEXT,
  pan TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_businesses_slug ON public.businesses(slug);
CREATE INDEX idx_businesses_type ON public.businesses(business_type);

-- -----------------------------------------------------------------------------
-- Business users (many-to-many: user ↔ business)
-- -----------------------------------------------------------------------------
CREATE TABLE public.business_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'staff' CHECK (role IN ('owner', 'admin', 'staff')),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (business_id, user_id)
);

CREATE INDEX idx_business_users_user ON public.business_users(user_id);
CREATE INDEX idx_business_users_business ON public.business_users(business_id);

-- -----------------------------------------------------------------------------
-- Business settings
-- -----------------------------------------------------------------------------
CREATE TABLE public.business_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL UNIQUE REFERENCES public.businesses(id) ON DELETE CASCADE,
  default_tax_rate NUMERIC(5,2) NOT NULL DEFAULT 0,
  currency_code TEXT NOT NULL DEFAULT 'INR',
  currency_symbol TEXT NOT NULL DEFAULT '₹',
  enable_barcode BOOLEAN NOT NULL DEFAULT false,
  payment_methods JSONB NOT NULL DEFAULT '["cash","upi","card","bank_transfer","other"]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- Invoice settings (numbering, template, footer)
-- -----------------------------------------------------------------------------
CREATE TABLE public.invoice_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL UNIQUE REFERENCES public.businesses(id) ON DELETE CASCADE,
  invoice_prefix TEXT NOT NULL DEFAULT 'INV',
  next_invoice_number INTEGER NOT NULL DEFAULT 1,
  invoice_number_padding INTEGER NOT NULL DEFAULT 5,
  footer_terms TEXT,
  template_id TEXT NOT NULL DEFAULT 'default',
  show_gst BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- WhatsApp settings (tokens NEVER stored here — only IDs; tokens in Edge secrets)
-- -----------------------------------------------------------------------------
CREATE TABLE public.whatsapp_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL UNIQUE REFERENCES public.businesses(id) ON DELETE CASCADE,
  enabled BOOLEAN NOT NULL DEFAULT false,
  auto_send_invoice BOOLEAN NOT NULL DEFAULT false,
  phone_number_id TEXT,
  business_account_id TEXT,
  message_template_id TEXT,
  -- Secret name reference in Edge Function env (e.g. WHATSAPP_TOKEN_DRAPE)
  access_token_secret_name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- Customers (tenant-scoped)
-- -----------------------------------------------------------------------------
CREATE TABLE public.customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  mobile TEXT,
  email TEXT,
  address TEXT,
  notes TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_customers_business ON public.customers(business_id);
CREATE INDEX idx_customers_name ON public.customers(business_id, name);
CREATE INDEX idx_customers_mobile ON public.customers(business_id, mobile);

-- -----------------------------------------------------------------------------
-- Products (primarily Drape & Dream; optional for cars as fee items)
-- -----------------------------------------------------------------------------
CREATE TABLE public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  brand TEXT,
  category TEXT,
  sub_category TEXT,
  description TEXT,
  image_url TEXT,
  base_price NUMERIC(12,2) NOT NULL DEFAULT 0,
  tax_rate NUMERIC(5,2) NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_products_business ON public.products(business_id);
CREATE INDEX idx_products_name ON public.products(business_id, name);

-- -----------------------------------------------------------------------------
-- Product variants (clothing: size/color/fabric + unique barcode)
-- -----------------------------------------------------------------------------
CREATE TABLE public.product_variants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  sku TEXT,
  size TEXT,
  color TEXT,
  fabric TEXT,
  selling_price NUMERIC(12,2) NOT NULL DEFAULT 0,
  tax_rate NUMERIC(5,2),
  barcode TEXT,
  barcode_format TEXT NOT NULL DEFAULT 'CODE128',
  image_url TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_variant_barcode UNIQUE (business_id, barcode)
);

CREATE INDEX idx_variants_business ON public.product_variants(business_id);
CREATE INDEX idx_variants_product ON public.product_variants(product_id);
CREATE INDEX idx_variants_barcode ON public.product_variants(business_id, barcode)
  WHERE barcode IS NOT NULL;

-- -----------------------------------------------------------------------------
-- Invoices
-- -----------------------------------------------------------------------------
CREATE TABLE public.invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  customer_id UUID REFERENCES public.customers(id) ON DELETE SET NULL,
  invoice_number TEXT NOT NULL,
  invoice_date DATE NOT NULL DEFAULT CURRENT_DATE,
  status public.invoice_status NOT NULL DEFAULT 'issued',
  payment_status public.payment_status NOT NULL DEFAULT 'pending',
  subtotal NUMERIC(12,2) NOT NULL DEFAULT 0,
  discount_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  tax_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  additional_charges NUMERIC(12,2) NOT NULL DEFAULT 0,
  grand_total NUMERIC(12,2) NOT NULL DEFAULT 0,
  amount_paid NUMERIC(12,2) NOT NULL DEFAULT 0,
  amount_outstanding NUMERIC(12,2) NOT NULL DEFAULT 0,
  notes TEXT,
  -- Car-specific fields (NULL for clothing invoices)
  car_make TEXT,
  car_model TEXT,
  car_variant TEXT,
  car_registration_number TEXT,
  car_chassis_number TEXT,
  car_engine_number TEXT,
  car_manufacturing_year INTEGER,
  car_color TEXT,
  car_fuel_type TEXT,
  created_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (business_id, invoice_number)
);

CREATE INDEX idx_invoices_business ON public.invoices(business_id);
CREATE INDEX idx_invoices_customer ON public.invoices(customer_id);
CREATE INDEX idx_invoices_date ON public.invoices(business_id, invoice_date DESC);
CREATE INDEX idx_invoices_payment_status ON public.invoices(business_id, payment_status);
CREATE INDEX idx_invoices_number ON public.invoices(business_id, invoice_number);

-- -----------------------------------------------------------------------------
-- Invoice line items
-- -----------------------------------------------------------------------------
CREATE TABLE public.invoice_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  invoice_id UUID NOT NULL REFERENCES public.invoices(id) ON DELETE CASCADE,
  product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
  product_variant_id UUID REFERENCES public.product_variants(id) ON DELETE SET NULL,
  description TEXT NOT NULL,
  quantity NUMERIC(12,3) NOT NULL DEFAULT 1,
  unit_price NUMERIC(12,2) NOT NULL DEFAULT 0,
  discount_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  tax_rate NUMERIC(5,2) NOT NULL DEFAULT 0,
  tax_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  line_total NUMERIC(12,2) NOT NULL DEFAULT 0,
  -- Snapshot of variant attrs for historical invoices
  size TEXT,
  color TEXT,
  barcode TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_invoice_items_invoice ON public.invoice_items(invoice_id);
CREATE INDEX idx_invoice_items_business ON public.invoice_items(business_id);

-- -----------------------------------------------------------------------------
-- Payments (separate records; never overwrite invoice grand_total)
-- -----------------------------------------------------------------------------
CREATE TABLE public.payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  invoice_id UUID NOT NULL REFERENCES public.invoices(id) ON DELETE CASCADE,
  amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
  payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
  payment_method public.payment_method NOT NULL DEFAULT 'cash',
  reference_number TEXT,
  notes TEXT,
  created_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_payments_invoice ON public.payments(invoice_id);
CREATE INDEX idx_payments_business ON public.payments(business_id);
CREATE INDEX idx_payments_date ON public.payments(business_id, payment_date DESC);

-- -----------------------------------------------------------------------------
-- Helper: updated_at trigger
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_profiles_updated BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_businesses_updated BEFORE UPDATE ON public.businesses
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_business_settings_updated BEFORE UPDATE ON public.business_settings
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_invoice_settings_updated BEFORE UPDATE ON public.invoice_settings
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_whatsapp_settings_updated BEFORE UPDATE ON public.whatsapp_settings
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_customers_updated BEFORE UPDATE ON public.customers
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_products_updated BEFORE UPDATE ON public.products
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_variants_updated BEFORE UPDATE ON public.product_variants
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_invoices_updated BEFORE UPDATE ON public.invoices
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_payments_updated BEFORE UPDATE ON public.payments
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- -----------------------------------------------------------------------------
-- Auth: auto-create profile on signup
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1))
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- -----------------------------------------------------------------------------
-- Tenant helpers
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.user_has_business_access(p_business_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.business_users bu
    WHERE bu.business_id = p_business_id
      AND bu.user_id = auth.uid()
      AND bu.is_active = true
  );
$$;

CREATE OR REPLACE FUNCTION public.user_business_ids()
RETURNS SETOF UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT bu.business_id
  FROM public.business_users bu
  WHERE bu.user_id = auth.uid()
    AND bu.is_active = true;
$$;

-- -----------------------------------------------------------------------------
-- Invoice number generation (atomic per business)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.next_invoice_number(p_business_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prefix TEXT;
  v_next INTEGER;
  v_pad INTEGER;
BEGIN
  IF NOT public.user_has_business_access(p_business_id) THEN
    RAISE EXCEPTION 'Access denied to business %', p_business_id;
  END IF;

  UPDATE public.invoice_settings
  SET next_invoice_number = next_invoice_number + 1
  WHERE business_id = p_business_id
  RETURNING invoice_prefix, next_invoice_number - 1, invoice_number_padding
  INTO v_prefix, v_next, v_pad;

  IF v_prefix IS NULL THEN
    RAISE EXCEPTION 'Invoice settings not found for business %', p_business_id;
  END IF;

  RETURN v_prefix || '-' || lpad(v_next::TEXT, v_pad, '0');
END;
$$;

-- -----------------------------------------------------------------------------
-- Recalculate invoice payment totals from payments table
-- Sales (grand_total) NEVER overwritten by payment amounts
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.recalculate_invoice_payments()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_invoice_id UUID;
  v_total_paid NUMERIC(12,2);
  v_grand NUMERIC(12,2);
  v_outstanding NUMERIC(12,2);
  v_status public.payment_status;
BEGIN
  v_invoice_id := COALESCE(NEW.invoice_id, OLD.invoice_id);

  SELECT COALESCE(SUM(amount), 0) INTO v_total_paid
  FROM public.payments
  WHERE invoice_id = v_invoice_id;

  SELECT grand_total INTO v_grand
  FROM public.invoices
  WHERE id = v_invoice_id;

  v_outstanding := GREATEST(v_grand - v_total_paid, 0);

  IF v_total_paid <= 0 THEN
    v_status := 'pending';
  ELSIF v_outstanding <= 0 THEN
    v_status := 'paid';
  ELSE
    v_status := 'partial';
  END IF;

  UPDATE public.invoices
  SET
    amount_paid = v_total_paid,
    amount_outstanding = v_outstanding,
    payment_status = v_status,
    updated_at = now()
  WHERE id = v_invoice_id;

  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER trg_payments_recalc
  AFTER INSERT OR UPDATE OR DELETE ON public.payments
  FOR EACH ROW EXECUTE FUNCTION public.recalculate_invoice_payments();

-- -----------------------------------------------------------------------------
-- Auto barcode for clothing variants (Code 128 compatible alphanumeric)
-- Format: DD{product_short}{variant_seq} — unique per business
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_variant_barcode()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_enable BOOLEAN;
  v_seq BIGINT;
BEGIN
  SELECT enable_barcode INTO v_enable
  FROM public.business_settings
  WHERE business_id = NEW.business_id;

  IF COALESCE(v_enable, false) = false THEN
    RETURN NEW;
  END IF;

  IF NEW.barcode IS NULL OR NEW.barcode = '' THEN
    SELECT COUNT(*) + 1 INTO v_seq
    FROM public.product_variants
    WHERE business_id = NEW.business_id;

    NEW.barcode := 'DD' || to_char(now(), 'YYMM') || lpad(v_seq::TEXT, 6, '0');
    NEW.barcode_format := COALESCE(NEW.barcode_format, 'CODE128');
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_variant_barcode
  BEFORE INSERT ON public.product_variants
  FOR EACH ROW EXECUTE FUNCTION public.generate_variant_barcode();

-- -----------------------------------------------------------------------------
-- Dashboard view (computed from invoices + payments — no stored totals)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.dashboard_stats
WITH (security_invoker = true)
AS
SELECT
  i.business_id,
  COALESCE(SUM(i.grand_total) FILTER (
    WHERE i.invoice_date = CURRENT_DATE AND i.status = 'issued'
  ), 0) AS today_sales,
  COALESCE((
    SELECT SUM(p.amount)
    FROM public.payments p
    WHERE p.business_id = i.business_id
      AND p.payment_date = CURRENT_DATE
  ), 0) AS today_collection,
  COALESCE(SUM(i.amount_outstanding) FILTER (
    WHERE i.status = 'issued'
  ), 0) AS pending_amount,
  COUNT(*) FILTER (WHERE i.status = 'issued') AS total_invoices,
  COUNT(*) FILTER (WHERE i.status = 'issued' AND i.payment_status = 'paid') AS paid_invoices,
  COUNT(*) FILTER (WHERE i.status = 'issued' AND i.payment_status = 'partial') AS partial_invoices,
  COUNT(*) FILTER (WHERE i.status = 'issued' AND i.payment_status = 'pending') AS pending_invoices
FROM public.invoices i
GROUP BY i.business_id;

-- Customer aggregates view
CREATE OR REPLACE VIEW public.customer_balances
WITH (security_invoker = true)
AS
SELECT
  c.id AS customer_id,
  c.business_id,
  c.name,
  c.mobile,
  c.email,
  c.address,
  c.is_active,
  COALESCE(SUM(i.grand_total) FILTER (WHERE i.status = 'issued'), 0) AS total_billed,
  COALESCE(SUM(i.amount_paid) FILTER (WHERE i.status = 'issued'), 0) AS total_paid,
  COALESCE(SUM(i.amount_outstanding) FILTER (WHERE i.status = 'issued'), 0) AS outstanding_amount,
  COUNT(i.id) FILTER (WHERE i.status = 'issued') AS invoice_count
FROM public.customers c
LEFT JOIN public.invoices i ON i.customer_id = c.id
GROUP BY c.id;

COMMENT ON VIEW public.dashboard_stats IS
  'Computed dashboard metrics. Sales = invoice grand_total; Collection = payment amounts.';
COMMENT ON COLUMN public.invoices.grand_total IS
  'Sales amount — never overwritten by payments.';
COMMENT ON COLUMN public.invoices.amount_paid IS
  'Sum of linked payment records — maintained by trigger.';
