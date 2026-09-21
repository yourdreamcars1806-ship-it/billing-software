// Supabase Edge Function: send-whatsapp-invoice
// Sends invoice via Meta WhatsApp Cloud API.
// Access tokens are read ONLY from Deno.env — never from client payloads.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface SendRequest {
  business_id: string;
  invoice_id: string;
  customer_mobile?: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "Missing authorization" }, 401);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();
    if (userError || !user) {
      return json({ error: "Unauthorized" }, 401);
    }

    const body = (await req.json()) as SendRequest;
    if (!body.business_id || !body.invoice_id) {
      return json({ error: "business_id and invoice_id required" }, 400);
    }

    const { data: membership } = await supabase
      .from("business_users")
      .select("id")
      .eq("business_id", body.business_id)
      .eq("user_id", user.id)
      .eq("is_active", true)
      .maybeSingle();

    if (!membership) {
      return json({ error: "No access to this business" }, 403);
    }

    const { data: waSettings, error: waError } = await supabase
      .from("whatsapp_settings")
      .select("*")
      .eq("business_id", body.business_id)
      .single();

    if (waError || !waSettings?.enabled) {
      return json({ error: "WhatsApp not enabled for this business" }, 400);
    }

    const { data: invoice, error: invError } = await supabase
      .from("invoices")
      .select("*, customers(name, mobile), businesses(name)")
      .eq("id", body.invoice_id)
      .eq("business_id", body.business_id)
      .single();

    if (invError || !invoice) {
      return json({ error: "Invoice not found" }, 404);
    }

    const mobile =
      body.customer_mobile ||
      (invoice.customers as { mobile?: string } | null)?.mobile;

    if (!mobile) {
      return json({ error: "Customer mobile number required" }, 400);
    }

    // Resolve token from Edge Function secrets by configured secret name
    const secretName =
      waSettings.access_token_secret_name || "WHATSAPP_ACCESS_TOKEN";
    const accessToken = Deno.env.get(secretName) || Deno.env.get("WHATSAPP_ACCESS_TOKEN");

    if (!accessToken || !waSettings.phone_number_id) {
      return json(
        {
          error:
            "WhatsApp credentials not configured on server. Set phone_number_id and access token secret.",
        },
        500,
      );
    }

    const to = normalizeWhatsAppNumber(mobile);
    const businessName =
      (invoice.businesses as { name?: string } | null)?.name || "Business";
    const customerName =
      (invoice.customers as { name?: string } | null)?.name || "Customer";

    // Prefer template message when configured; fallback to text
    let waPayload: Record<string, unknown>;
    if (waSettings.message_template_id) {
      waPayload = {
        messaging_product: "whatsapp",
        to,
        type: "template",
        template: {
          name: waSettings.message_template_id,
          language: { code: "en" },
          components: [
            {
              type: "body",
              parameters: [
                { type: "text", text: customerName },
                { type: "text", text: invoice.invoice_number },
                { type: "text", text: String(invoice.grand_total) },
                { type: "text", text: businessName },
              ],
            },
          ],
        },
      };
    } else {
      waPayload = {
        messaging_product: "whatsapp",
        to,
        type: "text",
        text: {
          body:
            `Invoice ${invoice.invoice_number} from ${businessName}\n` +
            `Amount: ₹${invoice.grand_total}\n` +
            `Paid: ₹${invoice.amount_paid}\n` +
            `Outstanding: ₹${invoice.amount_outstanding}\n` +
            `Status: ${invoice.payment_status}`,
        },
      };
    }

    const waRes = await fetch(
      `https://graph.facebook.com/v21.0/${waSettings.phone_number_id}/messages`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(waPayload),
      },
    );

    const waJson = await waRes.json();
    if (!waRes.ok) {
      console.error("WhatsApp API error", waJson);
      return json({ error: "WhatsApp send failed", details: waJson }, 502);
    }

    return json({ success: true, whatsapp: waJson });
  } catch (err) {
    console.error(err);
    return json({ error: "Internal error", message: String(err) }, 500);
  }
});

function normalizeWhatsAppNumber(mobile: string): string {
  const digits = mobile.replace(/\D/g, "");
  if (digits.length === 10) return `91${digits}`;
  return digits;
}

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
