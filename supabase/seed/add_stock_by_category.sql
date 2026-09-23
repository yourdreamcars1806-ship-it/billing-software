-- Run in Supabase → SQL Editor
CREATE OR REPLACE FUNCTION public.clothing_stock_by_category(p_business_id uuid)
RETURNS json
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  WITH rows AS (
    SELECT
      COALESCE(NULLIF(TRIM(p.category), ''), 'Other') AS category,
      COALESCE(v.stock_qty, 0) AS stock_qty,
      COALESCE(v.cost_price, 0) AS cost_price,
      COALESCE(v.selling_price, 0) AS selling_price,
      COALESCE(v.stock_out_total, 0) AS stock_out_total
    FROM public.product_variants v
    JOIN public.products p ON p.id = v.product_id
    WHERE v.business_id = p_business_id
      AND v.is_active = true
  ),
  by_cat AS (
    SELECT
      category,
      COALESCE(SUM(CASE WHEN stock_qty > 0 THEN stock_qty ELSE 0 END), 0) AS in_stock_pcs,
      COUNT(*) FILTER (WHERE stock_qty > 0) AS in_stock_items,
      COUNT(*) FILTER (WHERE stock_qty <= 0) AS out_of_stock_items,
      COALESCE(SUM(CASE WHEN stock_qty > 0 THEN stock_qty * cost_price ELSE 0 END), 0) AS buy_value,
      COALESCE(SUM(CASE WHEN stock_qty > 0 THEN stock_qty * selling_price ELSE 0 END), 0) AS sell_value,
      COALESCE(SUM(stock_out_total), 0) AS sold_pcs,
      COALESCE(SUM(stock_out_total * selling_price), 0) AS sold_value
    FROM rows
    GROUP BY category
  ),
  totals AS (
    SELECT
      COALESCE(SUM(in_stock_pcs), 0) AS in_stock_pcs,
      COALESCE(SUM(in_stock_items), 0) AS in_stock_items,
      COALESCE(SUM(out_of_stock_items), 0) AS out_of_stock_items,
      COALESCE(SUM(buy_value), 0) AS buy_value,
      COALESCE(SUM(sell_value), 0) AS sell_value,
      COALESCE(SUM(sold_pcs), 0) AS sold_pcs,
      COALESCE(SUM(sold_value), 0) AS sold_value
    FROM by_cat
  )
  SELECT json_build_object(
    'totals', (SELECT row_to_json(t) FROM totals t),
    'categories', COALESCE(
      (SELECT json_agg(row_to_json(c) ORDER BY c.category) FROM by_cat c),
      '[]'::json
    )
  );
$$;

GRANT EXECUTE ON FUNCTION public.clothing_stock_by_category(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.clothing_stock_by_category(uuid) TO anon;
