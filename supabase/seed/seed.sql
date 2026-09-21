-- =============================================================================
-- Seed: Drape & Dream + Your Dream Cars
-- Note: Link users via business_users after creating auth users in Supabase.
-- =============================================================================

INSERT INTO public.businesses (id, slug, name, business_type, description, address, phone, email, gstin, pan, logo_url)
VALUES
  (
    'a1000000-0000-4000-8000-000000000001',
    'drape-and-dream',
    'Drape & Dream',
    'clothing',
    'Clothing Billing',
    'NIBM Clover Hills Plaza, Office No. 79, Pune',
    '+91 98765 00001',
    'drapedream@gmail.com',
    '27AAAAA0000A1Z5',
    'AAAAA0000A',
    '/images/drape-and-dream-logo.png'
  ),
  (
    'a1000000-0000-4000-8000-000000000002',
    'your-dream-cars',
    'Your Dream Cars',
    'car',
    'Car Billing',
    'NIBM Clover Hills Plaza, Office No. 80, Pune',
    '+91 98765 00002',
    'yourdreamcars1806@gmail.com',
    '27BBBBB0000B1Z5',
    'BBBBB0000B',
    '/images/your-dream-cars-logo.png'
  )
ON CONFLICT (slug) DO UPDATE SET
  address = EXCLUDED.address,
  email = EXCLUDED.email,
  pan = EXCLUDED.pan,
  logo_url = COALESCE(EXCLUDED.logo_url, public.businesses.logo_url);

INSERT INTO public.business_settings (business_id, default_tax_rate, enable_barcode)
VALUES
  ('a1000000-0000-4000-8000-000000000001', 12.00, true),
  ('a1000000-0000-4000-8000-000000000002', 18.00, false)
ON CONFLICT (business_id) DO NOTHING;

INSERT INTO public.invoice_settings (business_id, invoice_prefix, next_invoice_number, footer_terms)
VALUES
  (
    'a1000000-0000-4000-8000-000000000001',
    'DD',
    1,
    'Thank you for shopping at Drape & Dream. Goods once sold will not be taken back.'
  ),
  (
    'a1000000-0000-4000-8000-000000000002',
    'YDC',
    1,
    'Thank you for choosing Your Dream Cars. All sales are subject to terms & conditions.'
  )
ON CONFLICT (business_id) DO NOTHING;

INSERT INTO public.whatsapp_settings (
  business_id,
  enabled,
  auto_send_invoice,
  access_token_secret_name
)
VALUES
  (
    'a1000000-0000-4000-8000-000000000001',
    false,
    false,
    'WHATSAPP_TOKEN_DRAPE_AND_DREAM'
  ),
  (
    'a1000000-0000-4000-8000-000000000002',
    false,
    false,
    'WHATSAPP_TOKEN_YOUR_DREAM_CARS'
  )
ON CONFLICT (business_id) DO NOTHING;
