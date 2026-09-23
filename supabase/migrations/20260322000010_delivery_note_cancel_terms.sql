-- Deal cancellation terms on delivery notes (editable GST % + paper fees)

ALTER TABLE public.delivery_notes
  ADD COLUMN IF NOT EXISTS cancel_terms_enabled BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS cancel_gst_percent NUMERIC(5,2) NOT NULL DEFAULT 18,
  ADD COLUMN IF NOT EXISTS paper_processing_fee NUMERIC(12,2),
  ADD COLUMN IF NOT EXISTS cancellation_terms TEXT;

COMMENT ON COLUMN public.delivery_notes.cancel_gst_percent IS
  'GST % charged if deal is cancelled (default 18)';
COMMENT ON COLUMN public.delivery_notes.paper_processing_fee IS
  'Flat paper / documentation processing fee on deal cancellation';
COMMENT ON COLUMN public.delivery_notes.cancellation_terms IS
  'Editable cancellation clause printed on delivery note';
