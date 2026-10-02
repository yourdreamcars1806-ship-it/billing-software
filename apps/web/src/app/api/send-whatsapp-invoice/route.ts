import { NextResponse } from "next/server";
import { sendWhatsappInvoice } from "@/lib/send-whatsapp-invoice";

export async function POST(request: Request) {
  const body = (await request.json().catch(() => ({}))) as {
    business_id?: string;
    invoice_id?: string;
    customer_mobile?: string;
  };

  const result = await sendWhatsappInvoice({
    business_id: body.business_id || "",
    invoice_id: body.invoice_id || "",
    customer_mobile: body.customer_mobile,
  });

  return NextResponse.json(result.body, { status: result.status });
}
