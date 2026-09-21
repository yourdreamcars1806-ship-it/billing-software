"use client";

import { createClient } from "@/lib/supabase/client";
import type { PaymentMethod } from "@/types";

export async function recordPayment(input: {
  business_id: string;
  invoice_id: string;
  amount: number;
  payment_method: PaymentMethod | string;
  payment_date?: string;
  reference_number?: string;
  notes?: string;
}): Promise<{ success: boolean; error?: string }> {
  if (!input.business_id || !input.invoice_id || !(input.amount > 0)) {
    return { success: false, error: "business, invoice, and amount required" };
  }

  const supabase = createClient();
  const {
    data: { session },
  } = await supabase.auth.getSession();
  if (!session?.user) {
    return { success: false, error: "Session expired" };
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

  const { data: invoice, error: invError } = await supabase
    .from("invoices")
    .select("id, amount_outstanding")
    .eq("id", input.invoice_id)
    .eq("business_id", input.business_id)
    .single();

  if (invError || !invoice) {
    return { success: false, error: "Invoice not found" };
  }

  if (input.amount > Number(invoice.amount_outstanding) + 0.01) {
    return { success: false, error: "Payment exceeds outstanding amount" };
  }

  const { error: payError } = await supabase.from("payments").insert({
    business_id: input.business_id,
    invoice_id: input.invoice_id,
    amount: input.amount,
    payment_method: input.payment_method || "cash",
    payment_date:
      input.payment_date || new Date().toISOString().slice(0, 10),
    reference_number: input.reference_number || null,
    notes: input.notes || null,
    created_by: session.user.id,
  });

  if (payError) {
    return { success: false, error: payError.message || "Payment failed" };
  }

  return { success: true };
}
