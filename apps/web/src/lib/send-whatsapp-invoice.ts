import { createClient } from "@/lib/supabase/server";

type SendInput = {
  business_id: string;
  invoice_id: string;
  customer_mobile?: string;
};

function normalizeWhatsAppNumber(mobile: string): string {
  const digits = mobile.replace(/\D/g, "");
  if (digits.length === 10) return `91${digits}`;
  return digits;
}

/**
 * Sends the invoice on WhatsApp from the Next.js server.
 * Same Meta payload as the edge function, so the browser never calls
 * Supabase Functions (that call was failing CORS when the function 404s).
 */
export async function sendWhatsappInvoice(input: SendInput): Promise<{
  ok: boolean;
  status: number;
  body: Record<string, unknown>;
}> {
  if (!input.business_id || !input.invoice_id) {
    return {
      ok: false,
      status: 400,
      body: { error: "business_id and invoice_id required" },
    };
  }

  const supabase = await createClient();
  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();
  if (userError || !user) {
    return { ok: false, status: 401, body: { error: "Unauthorized" } };
  }

  const { data: membership } = await supabase
    .from("business_users")
    .select("id")
    .eq("business_id", input.business_id)
    .eq("user_id", user.id)
    .eq("is_active", true)
    .maybeSingle();

  if (!membership) {
    return { ok: false, status: 403, body: { error: "No access to this business" } };
  }

  const { data: waSettings, error: waError } = await supabase
    .from("whatsapp_settings")
    .select("*")
    .eq("business_id", input.business_id)
    .single();

  if (waError || !waSettings?.enabled) {
    return {
      ok: false,
      status: 400,
      body: { error: "WhatsApp not enabled for this business" },
    };
  }

  const { data: invoice, error: invError } = await supabase
    .from("invoices")
    .select("*, customers(name, mobile), businesses(name)")
    .eq("id", input.invoice_id)
    .eq("business_id", input.business_id)
    .single();

  if (invError || !invoice) {
    return { ok: false, status: 404, body: { error: "Invoice not found" } };
  }

  const mobile =
    input.customer_mobile ||
    (invoice.customers as { mobile?: string } | null)?.mobile;

  if (!mobile) {
    return {
      ok: false,
      status: 400,
      body: { error: "Customer mobile number required" },
    };
  }

  const secretName =
    (waSettings.access_token_secret_name as string | null) ||
    "WHATSAPP_ACCESS_TOKEN";
  const accessToken =
    process.env[secretName] || process.env.WHATSAPP_ACCESS_TOKEN;

  if (!accessToken || !waSettings.phone_number_id) {
    return {
      ok: false,
      status: 500,
      body: {
        error: `WhatsApp token missing on the server. Add ${secretName} to .env.local (local) and to the host env (live site), then restart.`,
      },
    };
  }

  const to = normalizeWhatsAppNumber(mobile);
  const businessName =
    (invoice.businesses as { name?: string } | null)?.name || "Business";
  const customerName =
    (invoice.customers as { name?: string } | null)?.name || "Customer";

  const waPayload = waSettings.message_template_id
    ? {
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
      }
    : {
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

  const waJson = (await waRes.json().catch(() => ({}))) as Record<
    string,
    unknown
  >;
  if (!waRes.ok) {
    const metaError =
      (waJson.error as { message?: string } | undefined)?.message ||
      "WhatsApp send failed";
    return {
      ok: false,
      status: 502,
      body: { error: metaError, details: waJson },
    };
  }

  return { ok: true, status: 200, body: { success: true, whatsapp: waJson } };
}
