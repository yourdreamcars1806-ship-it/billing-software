-- Cost / purchase price alongside selling price
ALTER TABLE public.product_variants
  ADD COLUMN IF NOT EXISTS cost_price NUMERIC(12, 2) NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.product_variants.cost_price IS
  'Purchase / cost price (₹); selling_price is the sell rate';
