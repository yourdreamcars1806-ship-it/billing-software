-- Dummy PAN for both businesses (run in Supabase SQL Editor)
UPDATE public.businesses
SET pan = 'AAAAA0000A'
WHERE slug = 'drape-and-dream';

UPDATE public.businesses
SET pan = 'BBBBB0000B'
WHERE slug = 'your-dream-cars';
