-- Stock management for clothing variants
ALTER TABLE public.product_variants
  ADD COLUMN IF NOT EXISTS stock_qty NUMERIC(12, 3) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS stock_in_total NUMERIC(12, 3) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS stock_out_total NUMERIC(12, 3) NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS public.stock_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses (id) ON DELETE CASCADE,
  product_variant_id UUID NOT NULL REFERENCES public.product_variants (id) ON DELETE CASCADE,
  movement_type TEXT NOT NULL CHECK (movement_type IN ('in', 'out', 'adjust')),
  quantity NUMERIC(12, 3) NOT NULL CHECK (quantity > 0),
  note TEXT,
  invoice_id UUID REFERENCES public.invoices (id) ON DELETE SET NULL,
  created_by UUID REFERENCES auth.users (id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_stock_movements_variant
  ON public.stock_movements (product_variant_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_stock_movements_business
  ON public.stock_movements (business_id, created_at DESC);

ALTER TABLE public.stock_movements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS stock_movements_select ON public.stock_movements;
CREATE POLICY stock_movements_select ON public.stock_movements
  FOR SELECT USING (
    business_id IN (
      SELECT business_id FROM public.business_users
      WHERE user_id = auth.uid() AND is_active = true
    )
  );

DROP POLICY IF EXISTS stock_movements_insert ON public.stock_movements;
CREATE POLICY stock_movements_insert ON public.stock_movements
  FOR INSERT WITH CHECK (
    business_id IN (
      SELECT business_id FROM public.business_users
      WHERE user_id = auth.uid() AND is_active = true
    )
  );
