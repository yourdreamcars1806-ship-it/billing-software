// Supabase Edge Function: process-payment
// Records a payment against an invoice. Totals recalculated by DB trigger.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface ProcessPaymentRequest {
  business_id: string;
  invoice_id: string;
  amount: number;
  payment_method: "cash" | "upi" | "card" | "bank_transfer" | "other";
  payment_date?: string;
  reference_number?: string;
  notes?: string;
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

    const body = (await req.json()) as ProcessPaymentRequest;
    if (!body.business_id || !body.invoice_id || !body.amount) {
      return json({ error: "business_id, invoice_id, and amount required" }, 400);
    }
    if (body.amount <= 0) {
      return json({ error: "amount must be positive" }, 400);
    }

    const { data: membership } = await supabase
      .from("business_users")
      .select("id")
      .eq("business_id", body.business_id)
      .eq("user_id", user.id)
      .eq("is_active", true)
      .maybeSingle();

    if (!membership) return json({ error: "No access to this business" }, 403);

    const { data: invoice, error: invError } = await supabase
      .from("invoices")
      .select("*")
      .eq("id", body.invoice_id)
      .eq("business_id", body.business_id)
      .single();

    if (invError || !invoice) return json({ error: "Invoice not found" }, 404);

    if (body.amount > Number(invoice.amount_outstanding) + 0.01) {
      return json(
        {
          error: "Payment exceeds outstanding amount",
          outstanding: invoice.amount_outstanding,
        },
        400,
      );
    }

    const { data: payment, error: payError } = await supabase
      .from("payments")
      .insert({
        business_id: body.business_id,
        invoice_id: body.invoice_id,
        amount: body.amount,
        payment_method: body.payment_method || "cash",
        payment_date: body.payment_date || new Date().toISOString().slice(0, 10),
        reference_number: body.reference_number || null,
        notes: body.notes || null,
        created_by: user.id,
      })
      .select("*")
      .single();

    if (payError || !payment) {
      return json({ error: "Failed to record payment", details: payError }, 500);
    }

    const { data: refreshed } = await supabase
      .from("invoices")
      .select("*, payments(*)")
      .eq("id", body.invoice_id)
      .single();

    if (body.auto_whatsapp) {
      const fnUrl = `${Deno.env.get("SUPABASE_URL")}/functions/v1/send-whatsapp-invoice`;
      await fetch(fnUrl, {
        method: "POST",
        headers: {
          Authorization: authHeader,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          business_id: body.business_id,
          invoice_id: body.invoice_id,
        }),
      }).catch((e) => console.error("Auto WhatsApp failed", e));
    }

    return json({ success: true, payment, invoice: refreshed });
  } catch (err) {
    console.error(err);
    return json({ error: "Internal error", message: String(err) }, 500);
  }
});

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
