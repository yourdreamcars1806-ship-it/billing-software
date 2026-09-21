// Supabase Edge Function: generate-invoice
// Allocates invoice number and returns invoice payload for PDF clients.
// PDF rendering happens on clients; this keeps numbering atomic.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface LineItem {
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
}

interface CreateInvoiceRequest {
  business_id: string;
  customer_id?: string;
  invoice_date?: string;
  items: LineItem[];
  discount_amount?: number;
  additional_charges?: number;
  notes?: string;
  // Car-specific
  car_make?: string;
  car_model?: string;
  car_variant?: string;
  car_registration_number?: string;
  car_chassis_number?: string;
  car_engine_number?: string;
  car_manufacturing_year?: number;
  car_color?: string;
  car_fuel_type?: string;
  // Optional initial payment
  initial_payment?: {
    amount: number;
    payment_method: string;
    reference_number?: string;
  };
  auto_whatsapp?: boolean;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Missing authorization" }, 401);

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();
    if (userError || !user) return json({ error: "Unauthorized" }, 401);

    const body = (await req.json()) as CreateInvoiceRequest;
    if (!body.business_id || !body.items?.length) {
      return json({ error: "business_id and items required" }, 400);
    }

    const { data: membership } = await supabase
      .from("business_users")
      .select("id")
      .eq("business_id", body.business_id)
      .eq("user_id", user.id)
      .eq("is_active", true)
      .maybeSingle();

    if (!membership) return json({ error: "No access to this business" }, 403);

    const { data: invoiceNumber, error: numError } = await supabase.rpc(
      "next_invoice_number",
      { p_business_id: body.business_id },
    );

    if (numError || !invoiceNumber) {
      return json({ error: "Failed to allocate invoice number", details: numError }, 500);
    }

    let subtotal = 0;
    let taxAmount = 0;
    const computedItems = body.items.map((item, index) => {
      const qty = Number(item.quantity) || 0;
      const price = Number(item.unit_price) || 0;
      const discount = Number(item.discount_amount) || 0;
      const taxRate = Number(item.tax_rate) || 0;
      const taxable = Math.max(qty * price - discount, 0);
      const tax = (taxable * taxRate) / 100;
      const lineTotal = taxable + tax;
      subtotal += qty * price;
      taxAmount += tax;
      return {
        business_id: body.business_id,
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
        barcode: item.barcode || null,
        sort_order: index,
      };
    });

    const discountAmount = Number(body.discount_amount) || 0;
    const additionalCharges = Number(body.additional_charges) || 0;
    const itemsNet = computedItems.reduce((s, i) => s + i.line_total, 0);
    const grandTotal = round2(itemsNet - discountAmount + additionalCharges);

    const { data: invoice, error: invError } = await supabase
      .from("invoices")
      .insert({
        business_id: body.business_id,
        customer_id: body.customer_id || null,
        invoice_number: invoiceNumber,
        invoice_date: body.invoice_date || new Date().toISOString().slice(0, 10),
        status: "issued",
        payment_status: "pending",
        subtotal: round2(subtotal),
        discount_amount: discountAmount,
        tax_amount: round2(taxAmount),
        additional_charges: additionalCharges,
        grand_total: grandTotal,
        amount_paid: 0,
        amount_outstanding: grandTotal,
        notes: body.notes || null,
        car_make: body.car_make || null,
        car_model: body.car_model || null,
        car_variant: body.car_variant || null,
        car_registration_number: body.car_registration_number || null,
        car_chassis_number: body.car_chassis_number || null,
        car_engine_number: body.car_engine_number || null,
        car_manufacturing_year: body.car_manufacturing_year || null,
        car_color: body.car_color || null,
        car_fuel_type: body.car_fuel_type || null,
        created_by: user.id,
      })
      .select("*")
      .single();

    if (invError || !invoice) {
      return json({ error: "Failed to create invoice", details: invError }, 500);
    }

    const itemsWithInvoice = computedItems.map((i) => ({
      ...i,
      invoice_id: invoice.id,
    }));

    const { error: itemsError } = await supabase
      .from("invoice_items")
      .insert(itemsWithInvoice);

    if (itemsError) {
      return json({ error: "Failed to create line items", details: itemsError }, 500);
    }

    if (body.initial_payment?.amount && body.initial_payment.amount > 0) {
      const { error: payError } = await supabase.from("payments").insert({
        business_id: body.business_id,
        invoice_id: invoice.id,
        amount: body.initial_payment.amount,
        payment_method: body.initial_payment.payment_method || "cash",
        reference_number: body.initial_payment.reference_number || null,
        created_by: user.id,
      });
      if (payError) {
        return json({ error: "Invoice created but payment failed", details: payError }, 500);
      }
    }

    const { data: refreshed } = await supabase
      .from("invoices")
      .select("*, invoice_items(*), payments(*), customers(*)")
      .eq("id", invoice.id)
      .single();

    // Auto WhatsApp when settings.auto_send_invoice is ON (or client asked)
    let whatsapp: { sent?: boolean; skipped?: string; error?: string } = {};
    const { data: waSettings } = await supabase
      .from("whatsapp_settings")
      .select("enabled, auto_send_invoice")
      .eq("business_id", body.business_id)
      .maybeSingle();

    const shouldAutoWa =
      !!waSettings?.enabled &&
      (body.auto_whatsapp === true || !!waSettings?.auto_send_invoice);

    if (shouldAutoWa) {
      const fnUrl = `${Deno.env.get("SUPABASE_URL")}/functions/v1/send-whatsapp-invoice`;
      try {
        const waRes = await fetch(fnUrl, {
          method: "POST",
          headers: {
            Authorization: authHeader,
            apikey: Deno.env.get("SUPABASE_ANON_KEY") || "",
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            business_id: body.business_id,
            invoice_id: invoice.id,
          }),
        });
        const waJson = await waRes.json();
        if (waRes.ok) whatsapp = { sent: true };
        else whatsapp = { error: waJson.error || "WhatsApp send failed" };
      } catch (e) {
        console.error("Auto WhatsApp failed", e);
        whatsapp = { error: String(e) };
      }
    } else if (body.auto_whatsapp && !waSettings?.enabled) {
      whatsapp = {
        skipped: "Enable WhatsApp in Settings to auto-send invoices",
      };
    }

    return json({
      success: true,
      invoice: refreshed || invoice,
      whatsapp,
    });
  } catch (err) {
    console.error(err);
    return json({ error: "Internal error", message: String(err) }, 500);
  }
});

function round2(n: number) {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
