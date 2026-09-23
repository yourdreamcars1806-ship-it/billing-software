-- Delivery note workflow status: draft → confirmed | cancelled

DO $$ BEGIN
  CREATE TYPE public.delivery_note_status AS ENUM ('draft', 'confirmed', 'cancelled');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE public.delivery_notes
  ADD COLUMN IF NOT EXISTS delivery_status public.delivery_note_status NOT NULL DEFAULT 'draft',
  ADD COLUMN IF NOT EXISTS status_changed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS cancel_reason TEXT;

CREATE INDEX IF NOT EXISTS idx_delivery_notes_status
  ON public.delivery_notes(business_id, delivery_status);

COMMENT ON COLUMN public.delivery_notes.delivery_status IS
  'draft = saved, confirmed = vehicle delivered, cancelled = deal cancelled';
