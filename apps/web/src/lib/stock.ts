import { createClient } from "@/lib/supabase/client";

export type StockMovementType = "in" | "out" | "adjust";

/**
 * Stock in / stock out for a clothing variant.
 * - in: increases stock_qty + stock_in_total
 * - out: decreases stock_qty + increases stock_out_total
 */
export async function adjustVariantStock(input: {
  businessId: string;
  variantId: string;
  type: StockMovementType;
  quantity: number;
  note?: string;
  invoiceId?: string;
}): Promise<{ success: boolean; stock_qty?: number; error?: string }> {
  const qty = Number(input.quantity);
  if (!(qty > 0)) {
    return { success: false, error: "Quantity must be greater than 0" };
  }

  const supabase = createClient();
  const { data: variant, error: qErr } = await supabase
    .from("product_variants")
    .select("id, stock_qty, stock_in_total, stock_out_total")
    .eq("id", input.variantId)
    .eq("business_id", input.businessId)
    .maybeSingle();

  if (qErr || !variant) {
    return { success: false, error: qErr?.message || "Product not found" };
  }

  const current = Number(variant.stock_qty || 0);
  const stockIn = Number(variant.stock_in_total || 0);
  const stockOut = Number(variant.stock_out_total || 0);

  let nextQty = current;
  let nextIn = stockIn;
  let nextOut = stockOut;

  if (input.type === "in") {
    nextQty = current + qty;
    nextIn = stockIn + qty;
  } else if (input.type === "out") {
    if (qty > current) {
      return {
        success: false,
        error: `Only ${current} in stock`,
      };
    }
    nextQty = current - qty;
    nextOut = stockOut + qty;
  } else {
    // adjust = set absolute via positive qty as new on-hand, track delta
    const delta = qty - current;
    nextQty = qty;
    if (delta > 0) nextIn = stockIn + delta;
    else if (delta < 0) nextOut = stockOut + Math.abs(delta);
  }

  const { error: uErr } = await supabase
    .from("product_variants")
    .update({
      stock_qty: nextQty,
      stock_in_total: nextIn,
      stock_out_total: nextOut,
    })
    .eq("id", input.variantId)
    .eq("business_id", input.businessId);

  if (uErr) {
    return { success: false, error: uErr.message };
  }

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const moveQty =
    input.type === "adjust" ? Math.abs(qty - current) || qty : qty;

  if (moveQty > 0) {
    await supabase.from("stock_movements").insert({
      business_id: input.businessId,
      product_variant_id: input.variantId,
      movement_type: input.type,
      quantity: moveQty,
      note: input.note || null,
      invoice_id: input.invoiceId || null,
      created_by: user?.id || null,
    });
  }

  return { success: true, stock_qty: nextQty };
}

/** Decrement stock for sold invoice lines (best-effort per variant). */
export async function stockOutForInvoiceLines(input: {
  businessId: string;
  invoiceId: string;
  lines: { product_variant_id?: string | null; quantity: number }[];
}): Promise<void> {
  const byVariant = new Map<string, number>();
  for (const line of input.lines) {
    const id = line.product_variant_id?.trim();
    if (!id || !(line.quantity > 0)) continue;
    byVariant.set(id, (byVariant.get(id) || 0) + Number(line.quantity));
  }

  for (const [variantId, quantity] of byVariant) {
    await adjustVariantStock({
      businessId: input.businessId,
      variantId,
      type: "out",
      quantity,
      note: "Sold on invoice",
      invoiceId: input.invoiceId,
    });
  }
}
