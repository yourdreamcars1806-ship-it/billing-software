-- =============================================================================
-- Login setup: one shared email for both businesses
--
-- STEP A — Supabase Dashboard → Authentication → Users → Add user (if missing)
--   yourdreamcars1806@gmail.com   password: (set your own)
--
-- STEP B — Run this SQL in SQL Editor (after seed.sql)
-- Links that auth user to BOTH businesses.
-- =============================================================================

INSERT INTO public.business_users (business_id, user_id, role)
SELECT b.id, u.id, 'owner'
FROM public.businesses b
CROSS JOIN auth.users u
WHERE b.slug IN ('drape-and-dream', 'your-dream-cars')
  AND lower(u.email) = lower('yourdreamcars1806@gmail.com')
ON CONFLICT (business_id, user_id) DO NOTHING;

-- Verify
SELECT u.email, b.slug AS business, bu.role
FROM public.business_users bu
JOIN auth.users u ON u.id = bu.user_id
JOIN public.businesses b ON b.id = bu.business_id
WHERE lower(u.email) = lower('yourdreamcars1806@gmail.com')
ORDER BY b.slug;
