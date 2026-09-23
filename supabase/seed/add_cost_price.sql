-- Run in Supabase → SQL Editor (if migration not applied)
ALTER TABLE public.product_variants
  ADD COLUMN IF NOT EXISTS cost_price NUMERIC(12, 2) NOT NULL DEFAULT 0;
