-- Fast stock summary + covering index for clothing variants
CREATE INDEX IF NOT EXISTS idx_variants_business_active
  ON public.product_variants (business_id)
  WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_variants_business_created
  ON public.product_variants (business_id, created_at DESC)
  WHERE is_active = true;

CREATE OR REPLACE FUNCTION public.clothing_stock_summary(p_business_id uuid)
RETURNS json
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT json_build_object(
    'in_stock_pcs', COALESCE(SUM(CASE WHEN stock_qty > 0 THEN stock_qty ELSE 0 END), 0),
    'in_stock_items', COUNT(*) FILTER (WHERE stock_qty > 0),
    'out_of_stock_items', COUNT(*) FILTER (WHERE COALESCE(stock_qty, 0) <= 0)
  )
  FROM public.product_variants
  WHERE business_id = p_business_id
    AND is_active = true;
$$;

GRANT EXECUTE ON FUNCTION public.clothing_stock_summary(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.clothing_stock_summary(uuid) TO anon;
