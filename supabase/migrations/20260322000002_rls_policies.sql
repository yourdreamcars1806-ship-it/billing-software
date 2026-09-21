-- =============================================================================
-- Row Level Security — strict tenant isolation by business_id
-- =============================================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.businesses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.business_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.business_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoice_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whatsapp_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoice_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

-- Profiles: users see/update only themselves
CREATE POLICY profiles_select_own ON public.profiles
  FOR SELECT TO authenticated
  USING (id = auth.uid());

CREATE POLICY profiles_update_own ON public.profiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- Businesses: only assigned businesses
CREATE POLICY businesses_select ON public.businesses
  FOR SELECT TO authenticated
  USING (id IN (SELECT public.user_business_ids()));

CREATE POLICY businesses_update ON public.businesses
  FOR UPDATE TO authenticated
  USING (
    id IN (
      SELECT bu.business_id FROM public.business_users bu
      WHERE bu.user_id = auth.uid() AND bu.is_active AND bu.role IN ('owner', 'admin')
    )
  );

-- Business users: see memberships for own businesses / own rows
CREATE POLICY business_users_select ON public.business_users
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR business_id IN (SELECT public.user_business_ids())
  );

-- Generic tenant policies helper pattern for business-scoped tables
CREATE POLICY business_settings_select ON public.business_settings
  FOR SELECT TO authenticated
  USING (public.user_has_business_access(business_id));

CREATE POLICY business_settings_update ON public.business_settings
  FOR UPDATE TO authenticated
  USING (public.user_has_business_access(business_id))
  WITH CHECK (public.user_has_business_access(business_id));

CREATE POLICY invoice_settings_select ON public.invoice_settings
  FOR SELECT TO authenticated
  USING (public.user_has_business_access(business_id));

CREATE POLICY invoice_settings_update ON public.invoice_settings
  FOR UPDATE TO authenticated
  USING (public.user_has_business_access(business_id))
  WITH CHECK (public.user_has_business_access(business_id));

CREATE POLICY whatsapp_settings_select ON public.whatsapp_settings
  FOR SELECT TO authenticated
  USING (public.user_has_business_access(business_id));

CREATE POLICY whatsapp_settings_update ON public.whatsapp_settings
  FOR UPDATE TO authenticated
  USING (public.user_has_business_access(business_id))
  WITH CHECK (public.user_has_business_access(business_id));

-- Customers
CREATE POLICY customers_select ON public.customers
  FOR SELECT TO authenticated
  USING (public.user_has_business_access(business_id));

CREATE POLICY customers_insert ON public.customers
  FOR INSERT TO authenticated
  WITH CHECK (public.user_has_business_access(business_id));

CREATE POLICY customers_update ON public.customers
  FOR UPDATE TO authenticated
  USING (public.user_has_business_access(business_id))
  WITH CHECK (public.user_has_business_access(business_id));

CREATE POLICY customers_delete ON public.customers
  FOR DELETE TO authenticated
  USING (public.user_has_business_access(business_id));

-- Products
CREATE POLICY products_select ON public.products
  FOR SELECT TO authenticated
  USING (public.user_has_business_access(business_id));

CREATE POLICY products_insert ON public.products
  FOR INSERT TO authenticated
  WITH CHECK (public.user_has_business_access(business_id));

CREATE POLICY products_update ON public.products
  FOR UPDATE TO authenticated
  USING (public.user_has_business_access(business_id))
  WITH CHECK (public.user_has_business_access(business_id));

CREATE POLICY products_delete ON public.products
  FOR DELETE TO authenticated
  USING (public.user_has_business_access(business_id));

-- Product variants
CREATE POLICY variants_select ON public.product_variants
  FOR SELECT TO authenticated
  USING (public.user_has_business_access(business_id));

CREATE POLICY variants_insert ON public.product_variants
  FOR INSERT TO authenticated
  WITH CHECK (public.user_has_business_access(business_id));

CREATE POLICY variants_update ON public.product_variants
  FOR UPDATE TO authenticated
  USING (public.user_has_business_access(business_id))
  WITH CHECK (public.user_has_business_access(business_id));

CREATE POLICY variants_delete ON public.product_variants
  FOR DELETE TO authenticated
  USING (public.user_has_business_access(business_id));

-- Invoices
CREATE POLICY invoices_select ON public.invoices
  FOR SELECT TO authenticated
  USING (public.user_has_business_access(business_id));

CREATE POLICY invoices_insert ON public.invoices
  FOR INSERT TO authenticated
  WITH CHECK (public.user_has_business_access(business_id));

CREATE POLICY invoices_update ON public.invoices
  FOR UPDATE TO authenticated
  USING (public.user_has_business_access(business_id))
  WITH CHECK (public.user_has_business_access(business_id));

CREATE POLICY invoices_delete ON public.invoices
  FOR DELETE TO authenticated
  USING (public.user_has_business_access(business_id));

-- Invoice items
CREATE POLICY invoice_items_select ON public.invoice_items
  FOR SELECT TO authenticated
  USING (public.user_has_business_access(business_id));

CREATE POLICY invoice_items_insert ON public.invoice_items
  FOR INSERT TO authenticated
  WITH CHECK (public.user_has_business_access(business_id));

CREATE POLICY invoice_items_update ON public.invoice_items
  FOR UPDATE TO authenticated
  USING (public.user_has_business_access(business_id))
  WITH CHECK (public.user_has_business_access(business_id));

CREATE POLICY invoice_items_delete ON public.invoice_items
  FOR DELETE TO authenticated
  USING (public.user_has_business_access(business_id));

-- Payments
CREATE POLICY payments_select ON public.payments
  FOR SELECT TO authenticated
  USING (public.user_has_business_access(business_id));

CREATE POLICY payments_insert ON public.payments
  FOR INSERT TO authenticated
  WITH CHECK (public.user_has_business_access(business_id));

CREATE POLICY payments_update ON public.payments
  FOR UPDATE TO authenticated
  USING (public.user_has_business_access(business_id))
  WITH CHECK (public.user_has_business_access(business_id));

CREATE POLICY payments_delete ON public.payments
  FOR DELETE TO authenticated
  USING (public.user_has_business_access(business_id));

-- Grant execute on helpers
GRANT EXECUTE ON FUNCTION public.user_has_business_access(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.user_business_ids() TO authenticated;
GRANT EXECUTE ON FUNCTION public.next_invoice_number(UUID) TO authenticated;
