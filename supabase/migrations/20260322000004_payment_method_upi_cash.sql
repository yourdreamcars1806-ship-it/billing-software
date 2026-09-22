-- Add UPI + Cash payment method
ALTER TYPE public.payment_method ADD VALUE IF NOT EXISTS 'upi_cash';
