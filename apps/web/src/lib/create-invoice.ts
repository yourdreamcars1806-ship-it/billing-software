"use client";

import { createClient } from "@/lib/supabase/client";
import type { PaymentMethod } from "@/types";

export type CreateInvoiceLine = {
  description: string;
  quantity: number;
  unit_price: number;
  discount_amount?: number;
  tax_rate?: number;
  product_id?: string;
  product_variant_id?: string;
  size?: string;
  color?: string;
  barcode?: string;
};

export type CreateInvoiceInput = {
  business_id: string;
  customer_id?: string;
  /** Typed name on bill — finds existing or creates a simple customer row */
  customer_name?: string;
  /** WhatsApp / mobile — optional; bill still creates if missing */
  customer_mobile?: string;
  invoice_date?: string;
  items: CreateInvoiceLine[];
  discount_amount?: number;
  additional_charges?: number;
  notes?: string;
  car_make?: string;
  car_model?: string;
  car_variant?: string;
  car_registration_number?: string;
  car_chassis_number?: string;
  car_engine_number?: string;
  car_manufacturing_year?: number;
  car_color?: string;
  car_fuel_type?: string;
  initial_payment?: {
    amount: number;
    payment_method: PaymentMethod | string;
    reference_number?: string;
  };
  auto_whatsapp?: boolean;
};

function round2(n: number) {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}

/**
 * Create invoice via Supabase client (works even if edge functions aren't deployed).
 * Uses next_invoice_number RPC + RLS inserts — same logic as generate-invoice function.
 */
export async function createInvoice(input: CreateInvoiceInput): Promise<{
  success: boolean;
  invoice?: Record<string, unknown>;
  whatsapp?: { sent?: boolean; skipped?: string; error?: string };
  error?: string;
}> {
  if (!input.business_id || !input.items?.length) {
    return { success: false, error: "business_id and items required" };
  }

  const supabase = createClient();
  const {
    data: { session },
  } = await supabase.auth.getSession();
  if (!session?.user) {
    return { success: false, error: "Session expired. Please login again." };
  }

  const { data: membership } = await supabase
    .from("business_users")
    .select("id")
    .eq("business_id", input.business_id)
    .eq("user_id", session.user.id)
    .eq("is_active", true)
    .maybeSingle();

  if (!membership) {
    return { success: false, error: "No access to this business" };
  }

  const { data: invoiceNumber, error: numError } = await supabase.rpc(
    "next_invoice_number",
    { p_business_id: input.business_id },
  );

  if (numError || !invoiceNumber) {
    return {
      success: false,
      error:
        numError?.message ||
        "Failed to allocate invoice number. Check invoice settings.",
    };
  }

  let subtotal = 0;
  let taxAmount = 0;

  // Resolve barcodes from variants when missing on line
  const variantIds = input.items
    .map((i) => i.product_variant_id)
    .filter((id): id is string => Boolean(id));
  const variantBarcode = new Map<string, string>();
  if (variantIds.length) {
    const { data: variants } = await supabase
      .from("product_variants")
      .select("id, barcode")
      .eq("business_id", input.business_id)
      .in("id", variantIds);
    for (const v of variants || []) {
      if (v.barcode) variantBarcode.set(v.id as string, v.barcode as string);
    }
  }

  const computedItems = input.items.map((item, index) => {
    const qty = Number(item.quantity) || 0;
    const price = Number(item.unit_price) || 0;
    const discount = Number(item.discount_amount) || 0;
    const taxRate = Number(item.tax_rate) || 0;
    const taxable = Math.max(qty * price - discount, 0);
    const tax = (taxable * taxRate) / 100;
    const lineTotal = taxable + tax;
    subtotal += qty * price;
    taxAmount += tax;
    const barcode =
      item.barcode ||
      (item.product_variant_id
        ? variantBarcode.get(item.product_variant_id)
        : undefined) ||
      null;
    return {
      business_id: input.business_id,
      description: item.description,
      quantity: qty,
      unit_price: price,
      discount_amount: discount,
      tax_rate: taxRate,
      tax_amount: round2(tax),
      line_total: round2(lineTotal),
      product_id: item.product_id || null,
      product_variant_id: item.product_variant_id || null,
      size: item.size || null,
      color: item.color || null,
      barcode,
      sort_order: index,
    };
  });

  const discountAmount = Number(input.discount_amount) || 0;
  const additionalCharges = Number(input.additional_charges) || 0;
  const itemsNet = computedItems.reduce((s, i) => s + i.line_total, 0);
  const grandTotal = round2(itemsNet - discountAmount + additionalCharges);

  let customerId = input.customer_id || null;
  const typedName = (input.customer_name || "").trim();
  const typedMobile = (input.customer_mobile || "").trim().replace(/\s+/g, "");

  if (!customerId && (typedName || typedMobile)) {
    let existingId: string | null = null;

    if (typedMobile) {
      const digits = typedMobile.replace(/\D/g, "");
      const last10 = digits.length >= 10 ? digits.slice(-10) : digits;
      const { data: mobileMatches } = await supabase
        .from("customers")
        .select("id, mobile")
        .eq("business_id", input.business_id)
        .eq("is_active", true)
        .not("mobile", "is", null)
        .limit(50);
      const hit = (mobileMatches || []).find((c) => {
        const m = String(c.mobile || "").replace(/\D/g, "");
        return (
          m === digits ||
          (last10.length === 10 && m.endsWith(last10)) ||
          String(c.mobile || "").trim() === typedMobile
        );
      });
      if (hit?.id) existingId = hit.id;
    }

    if (!existingId && typedName) {
      const { data: byName } = await supabase
        .from("customers")
        .select("id")
        .eq("business_id", input.business_id)
        .eq("is_active", true)
        .ilike("name", typedName)
        .limit(1)
        .maybeSingle();
      if (byName?.id) existingId = byName.id;
    }

    if (existingId) {
      customerId = existingId;
      if (typedMobile || typedName) {
        await supabase
          .from("customers")
          .update({
            ...(typedMobile ? { mobile: typedMobile } : {}),
            ...(typedName ? { name: typedName } : {}),
          })
          .eq("id", existingId)
          .eq("business_id", input.business_id);
      }
    } else {
      const { data: created } = await supabase
        .from("customers")
        .insert({
          business_id: input.business_id,
          name: typedName || (typedMobile ? `Customer ${typedMobile.slice(-4)}` : "Walk-in"),
          mobile: typedMobile || null,
          is_active: true,
        })
        .select("id")
        .single();
      customerId = created?.id || null;
    }
  }

  const { data: invoice, error: invError } = await supabase
    .from("invoices")
    .insert({
      business_id: input.business_id,
      customer_id: customerId,
      invoice_number: invoiceNumber,
      invoice_date:
        input.invoice_date || new Date().toISOString().slice(0, 10),
      status: "issued",
      payment_status: "pending",
      subtotal: round2(subtotal),
      discount_amount: discountAmount,
      tax_amount: round2(taxAmount),
      additional_charges: additionalCharges,
      grand_total: grandTotal,
      amount_paid: 0,
      amount_outstanding: grandTotal,
      notes: input.notes || null,
      car_make: input.car_make || null,
      car_model: input.car_model || null,
      car_variant: input.car_variant || null,
      car_registration_number: input.car_registration_number || null,
      car_chassis_number: input.car_chassis_number || null,
      car_engine_number: input.car_engine_number || null,
      car_manufacturing_year: input.car_manufacturing_year || null,
      car_color: input.car_color || null,
      car_fuel_type: input.car_fuel_type || null,
      created_by: session.user.id,
    })
    .select("*")
    .single();

  if (invError || !invoice) {
    return {
      success: false,
      error: invError?.message || "Failed to create invoice",
    };
  }

  const { error: itemsError } = await supabase.from("invoice_items").insert(
    computedItems.map((i) => ({
      ...i,
      invoice_id: invoice.id,
    })),
  );

  if (itemsError) {
    return {
      success: false,
      error: itemsError.message || "Failed to create line items",
    };
  }

  if (input.initial_payment?.amount && input.initial_payment.amount > 0) {
    const { error: payError } = await supabase.from("payments").insert({
      business_id: input.business_id,
      invoice_id: invoice.id,
      amount: input.initial_payment.amount,
      payment_method: input.initial_payment.payment_method || "cash",
      reference_number: input.initial_payment.reference_number || null,
      created_by: session.user.id,
    });
    if (payError) {
      return {
        success: false,
        error: `Invoice created but payment failed: ${payError.message}`,
      };
    }
  }

  const { data: refreshed } = await supabase
    .from("invoices")
    .select("*, invoice_items(*), payments(*), customers(*)")
    .eq("id", invoice.id)
    .single();

  let whatsapp: { sent?: boolean; skipped?: string; error?: string } = {};

  if (input.auto_whatsapp) {
    const mobileForWa =
      typedMobile ||
      ((refreshed as { customers?: { mobile?: string } | null } | null)
        ?.customers?.mobile ||
        "");

    if (!mobileForWa.trim()) {
      whatsapp = { skipped: "no customer mobile" };
    } else {
      const base = process.env.NEXT_PUBLIC_SUPABASE_URL;
      const anon = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
      if (base && anon) {
        try {
          const waRes = await fetch(
            `${base}/functions/v1/send-whatsapp-invoice`,
            {
              method: "POST",
              headers: {
                Authorization: `Bearer ${session.access_token}`,
                apikey: anon,
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                business_id: input.business_id,
                invoice_id: invoice.id,
                customer_mobile: mobileForWa.trim(),
              }),
            },
          );
          if (waRes.ok) whatsapp = { sent: true };
          else {
            const waJson = await waRes.json().catch(() => ({}));
            whatsapp = {
              error:
                (waJson as { error?: string }).error ||
                "WhatsApp function not available",
            };
          }
        } catch {
          whatsapp = { skipped: "WhatsApp edge function not reachable" };
        }
      } else {
        whatsapp = { skipped: "WhatsApp not configured" };
      }
    }
  }

  return {
    success: true,
    invoice: (refreshed || invoice) as Record<string, unknown>,
    whatsapp,
  };
}
