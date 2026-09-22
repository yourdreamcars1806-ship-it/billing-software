-- Run once in Supabase → SQL Editor (required for Offer % on products)
ALTER TABLE public.product_variants
  ADD COLUMN IF NOT EXISTS offer_percent NUMERIC(5, 2) NOT NULL DEFAULT 0
  CHECK (offer_percent >= 0 AND offer_percent <= 100);
