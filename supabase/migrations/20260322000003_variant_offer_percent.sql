-- Offer % on clothing variants (auto discount on billing scan)
ALTER TABLE public.product_variants
  ADD COLUMN IF NOT EXISTS offer_percent NUMERIC(5, 2) NOT NULL DEFAULT 0
  CHECK (offer_percent >= 0 AND offer_percent <= 100);

COMMENT ON COLUMN public.product_variants.offer_percent IS
  'Promotional discount percent applied automatically when barcode is scanned on billing';
