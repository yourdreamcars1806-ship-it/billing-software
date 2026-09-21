-- =============================================================================
-- Login setup: one user per business
--
-- STEP A — Supabase Dashboard → Authentication → Users → Add user
--   1) drapedream@gmail.com          password: Gafru@786  (Drape & Dream / clothing)
--   2) yourdreamcars1806@gmail.com   password: Gafru@786  (Your Dream Cars)
--
-- STEP B — Run this SQL in SQL Editor (after seed.sql)
-- Links each auth user to ONLY their business.
-- =============================================================================

-- Clothing → Drape & Dream only
INSERT INTO public.business_users (business_id, user_id, role)
SELECT b.id, u.id, 'owner'
FROM public.businesses b
CROSS JOIN auth.users u
WHERE b.slug = 'drape-and-dream'
  AND lower(u.email) = lower('drapedream@gmail.com')
ON CONFLICT (business_id, user_id) DO NOTHING;

-- Cars → Your Dream Cars only
INSERT INTO public.business_users (business_id, user_id, role)
SELECT b.id, u.id, 'owner'
FROM public.businesses b
CROSS JOIN auth.users u
WHERE b.slug = 'your-dream-cars'
  AND lower(u.email) = lower('yourdreamcars1806@gmail.com')
ON CONFLICT (business_id, user_id) DO NOTHING;

-- Verify
SELECT u.email, b.slug AS business, bu.role
FROM public.business_users bu
JOIN auth.users u ON u.id = bu.user_id
JOIN public.businesses b ON b.id = bu.business_id
ORDER BY b.slug;
