-- =============================================================================
-- Vehicle Delivery Notes (Your Dream Cars / car businesses)
-- =============================================================================

ALTER TABLE public.invoice_settings
  ADD COLUMN IF NOT EXISTS delivery_note_prefix TEXT NOT NULL DEFAULT 'DN',
  ADD COLUMN IF NOT EXISTS next_delivery_note_number INTEGER NOT NULL DEFAULT 1;

UPDATE public.invoice_settings s
SET delivery_note_prefix = 'YDC-DN'
FROM public.businesses b
WHERE s.business_id = b.id
  AND b.slug = 'your-dream-cars';

CREATE TABLE IF NOT EXISTS public.delivery_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  invoice_id UUID REFERENCES public.invoices(id) ON DELETE SET NULL,
  delivery_note_number TEXT NOT NULL,
  delivery_date DATE NOT NULL DEFAULT CURRENT_DATE,
  delivery_time TEXT,
  customer_name TEXT NOT NULL DEFAULT '',
  customer_address TEXT,
  customer_mobile TEXT,
  id_proof TEXT,
  id_no TEXT,
  car_make TEXT,
  car_model_variant TEXT,
  car_registration_number TEXT,
  car_manufacturing_year TEXT,
  car_color TEXT,
  car_fuel_type TEXT,
  car_chassis_number TEXT,
  car_engine_number TEXT,
  odometer_km TEXT,
  total_vehicle_price NUMERIC(12,2),
  amount_received NUMERIC(12,2),
  balance_amount NUMERIC(12,2),
  payment_modes JSONB NOT NULL DEFAULT '{}'::jsonb,
  payment_other TEXT,
  docs JSONB NOT NULL DEFAULT '{}'::jsonb,
  docs_other TEXT,
  declaration_name TEXT,
  customer_sign_name TEXT,
  customer_sign_datetime TEXT,
  auth_sign_name TEXT,
  handed_over_by TEXT,
  created_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (business_id, delivery_note_number)
);

CREATE INDEX IF NOT EXISTS idx_delivery_notes_business
  ON public.delivery_notes(business_id);
CREATE INDEX IF NOT EXISTS idx_delivery_notes_date
  ON public.delivery_notes(business_id, delivery_date DESC);
CREATE INDEX IF NOT EXISTS idx_delivery_notes_invoice
  ON public.delivery_notes(invoice_id);

DROP TRIGGER IF EXISTS trg_delivery_notes_updated_at ON public.delivery_notes;
CREATE TRIGGER trg_delivery_notes_updated_at
  BEFORE UPDATE ON public.delivery_notes
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.delivery_notes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS delivery_notes_select ON public.delivery_notes;
CREATE POLICY delivery_notes_select ON public.delivery_notes
  FOR SELECT TO authenticated
  USING (public.user_has_business_access(business_id));

DROP POLICY IF EXISTS delivery_notes_insert ON public.delivery_notes;
CREATE POLICY delivery_notes_insert ON public.delivery_notes
  FOR INSERT TO authenticated
  WITH CHECK (public.user_has_business_access(business_id));

DROP POLICY IF EXISTS delivery_notes_update ON public.delivery_notes;
CREATE POLICY delivery_notes_update ON public.delivery_notes
  FOR UPDATE TO authenticated
  USING (public.user_has_business_access(business_id))
  WITH CHECK (public.user_has_business_access(business_id));

DROP POLICY IF EXISTS delivery_notes_delete ON public.delivery_notes;
CREATE POLICY delivery_notes_delete ON public.delivery_notes
  FOR DELETE TO authenticated
  USING (public.user_has_business_access(business_id));

CREATE OR REPLACE FUNCTION public.next_delivery_note_number(p_business_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prefix TEXT;
  v_next INTEGER;
BEGIN
  IF NOT public.user_has_business_access(p_business_id) THEN
    RAISE EXCEPTION 'Access denied to business %', p_business_id;
  END IF;

  UPDATE public.invoice_settings
  SET next_delivery_note_number = COALESCE(next_delivery_note_number, 1) + 1
  WHERE business_id = p_business_id
  RETURNING
    COALESCE(NULLIF(delivery_note_prefix, ''), 'DN'),
    next_delivery_note_number - 1
  INTO v_prefix, v_next;

  IF v_prefix IS NULL THEN
    RAISE EXCEPTION 'Invoice settings not found for business %', p_business_id;
  END IF;

  RETURN v_prefix || '-' || lpad(v_next::TEXT, 5, '0');
END;
$$;

-- Also bake cancel-term defaults into base table for fresh installs
ALTER TABLE public.delivery_notes
  ADD COLUMN IF NOT EXISTS cancel_terms_enabled BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS cancel_gst_percent NUMERIC(5,2) NOT NULL DEFAULT 18,
  ADD COLUMN IF NOT EXISTS paper_processing_fee NUMERIC(12,2),
  ADD COLUMN IF NOT EXISTS cancellation_terms TEXT;

GRANT EXECUTE ON FUNCTION public.next_delivery_note_number(UUID) TO authenticated;
