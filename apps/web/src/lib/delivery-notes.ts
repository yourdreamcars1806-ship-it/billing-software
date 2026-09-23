"use client";

import { createClient } from "@/lib/supabase/client";
import {
  defaultCancellationTerms,
  type DeliveryNoteData,
} from "@/lib/delivery-note-document";
import type { DeliveryNote, DeliveryNoteStatus } from "@/types";

const DEFAULT_MODES = {
  cash: false,
  upi: false,
  bank_transfer: false,
  finance: false,
  other: false,
};

const DEFAULT_DOCS = {
  rc: true,
  insurance: true,
  puc: false,
  service_records: false,
  keys: true,
  spare_key: false,
  other: false,
};

function numOrNull(raw: string) {
  const n = Number(String(raw).replace(/,/g, ""));
  if (!raw.trim() || Number.isNaN(n)) return null;
  return Math.round((n + Number.EPSILON) * 100) / 100;
}

export function rowToForm(row: DeliveryNote): DeliveryNoteData {
  const modes = { ...DEFAULT_MODES, ...(row.payment_modes || {}) };
  const docs = { ...DEFAULT_DOCS, ...(row.docs || {}) };
  const gst =
    row.cancel_gst_percent != null ? String(row.cancel_gst_percent) : "18";
  const fee =
    row.paper_processing_fee != null ? String(row.paper_processing_fee) : "";
  return {
    delivery_note_no: row.delivery_note_number || "",
    delivery_date: row.delivery_date || new Date().toISOString().slice(0, 10),
    delivery_time: row.delivery_time || "",
    customer_name: row.customer_name || "",
    customer_address: row.customer_address || "",
    customer_mobile: row.customer_mobile || "",
    id_proof: row.id_proof || "",
    id_no: row.id_no || "",
    car_make: row.car_make || "",
    car_model_variant: row.car_model_variant || "",
    car_registration_number: row.car_registration_number || "",
    car_manufacturing_year: row.car_manufacturing_year || "",
    car_color: row.car_color || "",
    car_fuel_type: row.car_fuel_type || "",
    car_chassis_number: row.car_chassis_number || "",
    car_engine_number: row.car_engine_number || "",
    odometer_km: row.odometer_km || "",
    total_vehicle_price:
      row.total_vehicle_price != null ? String(row.total_vehicle_price) : "",
    amount_received:
      row.amount_received != null ? String(row.amount_received) : "",
    balance_amount:
      row.balance_amount != null ? String(row.balance_amount) : "",
    payment_modes: modes,
    payment_other: row.payment_other || "",
    docs,
    docs_other: row.docs_other || "",
    declaration_name: row.declaration_name || "",
    customer_sign_name: row.customer_sign_name || "",
    customer_sign_datetime: row.customer_sign_datetime || "",
    auth_sign_name: row.auth_sign_name || "",
    handed_over_by: row.handed_over_by || "",
    cancel_terms_enabled: row.cancel_terms_enabled !== false,
    cancel_gst_percent: gst,
    paper_processing_fee: fee,
    cancellation_terms:
      row.cancellation_terms ||
      defaultCancellationTerms(gst, fee, "Your Dream Cars"),
    delivery_status: row.delivery_status || "draft",
    cancel_reason: row.cancel_reason || "",
  };
}

function formToRow(
  businessId: string,
  form: DeliveryNoteData,
  extras: {
    id?: string;
    invoice_id?: string | null;
    created_by?: string;
  },
) {
  return {
    ...(extras.id ? { id: extras.id } : {}),
    business_id: businessId,
    invoice_id: extras.invoice_id ?? null,
    delivery_note_number: form.delivery_note_no.trim(),
    delivery_date: form.delivery_date || new Date().toISOString().slice(0, 10),
    delivery_time: form.delivery_time.trim() || null,
    customer_name: form.customer_name.trim(),
    customer_address: form.customer_address.trim() || null,
    customer_mobile: form.customer_mobile.trim() || null,
    id_proof: form.id_proof.trim() || null,
    id_no: form.id_no.trim() || null,
    car_make: form.car_make.trim() || null,
    car_model_variant: form.car_model_variant.trim() || null,
    car_registration_number: form.car_registration_number.trim() || null,
    car_manufacturing_year: form.car_manufacturing_year.trim() || null,
    car_color: form.car_color.trim() || null,
    car_fuel_type: form.car_fuel_type.trim() || null,
    car_chassis_number: form.car_chassis_number.trim() || null,
    car_engine_number: form.car_engine_number.trim() || null,
    odometer_km: form.odometer_km.trim() || null,
    total_vehicle_price: numOrNull(form.total_vehicle_price),
    amount_received: numOrNull(form.amount_received),
    balance_amount: numOrNull(form.balance_amount),
    payment_modes: form.payment_modes,
    payment_other: form.payment_other.trim() || null,
    docs: form.docs,
    docs_other: form.docs_other.trim() || null,
    declaration_name: form.declaration_name.trim() || null,
    customer_sign_name: form.customer_sign_name.trim() || null,
    customer_sign_datetime: form.customer_sign_datetime.trim() || null,
    auth_sign_name: form.auth_sign_name.trim() || null,
    handed_over_by: form.handed_over_by.trim() || null,
    cancel_terms_enabled: form.cancel_terms_enabled,
    cancel_gst_percent: numOrNull(form.cancel_gst_percent) ?? 18,
    paper_processing_fee: numOrNull(form.paper_processing_fee),
    cancellation_terms: form.cancellation_terms.trim() || null,
    delivery_status: form.delivery_status || "draft",
    cancel_reason: form.cancel_reason.trim() || null,
    ...(extras.created_by ? { created_by: extras.created_by } : {}),
  };
}

export function summarizeDeliveryNotes(rows: DeliveryNote[]) {
  const total = rows.length;
  let confirmed = 0;
  let cancelled = 0;
  let draft = 0;
  for (const r of rows) {
    const s = r.delivery_status || "draft";
    if (s === "confirmed") confirmed += 1;
    else if (s === "cancelled") cancelled += 1;
    else draft += 1;
  }
  return { total, confirmed, cancelled, draft };
}

export async function listDeliveryNotes(
  businessId: string,
): Promise<DeliveryNote[]> {
  const supabase = createClient();
  const { data, error } = await supabase
    .from("delivery_notes")
    .select("*")
    .eq("business_id", businessId)
    .order("delivery_date", { ascending: false })
    .order("created_at", { ascending: false })
    .limit(200);
  if (error) throw new Error(error.message);
  return (data as DeliveryNote[]) || [];
}

export async function allocateDeliveryNoteNumber(
  businessId: string,
): Promise<string> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc("next_delivery_note_number", {
    p_business_id: businessId,
  });
  if (error || !data) {
    throw new Error(error?.message || "Could not allocate delivery note number");
  }
  return String(data);
}

export async function saveDeliveryNote(input: {
  business_id: string;
  form: DeliveryNoteData;
  id?: string | null;
  invoice_id?: string | null;
}): Promise<{ success: boolean; row?: DeliveryNote; error?: string }> {
  if (!input.form.customer_name.trim()) {
    return { success: false, error: "Customer name is required" };
  }
  if (!input.form.delivery_note_no.trim()) {
    return { success: false, error: "Delivery note number is required" };
  }

  const supabase = createClient();
  const {
    data: { session },
  } = await supabase.auth.getSession();
  if (!session?.user) {
    return { success: false, error: "Session expired" };
  }

  const payload = formToRow(input.business_id, input.form, {
    id: input.id || undefined,
    invoice_id: input.invoice_id ?? null,
    created_by: input.id ? undefined : session.user.id,
  });

  if (input.id) {
    const { data, error } = await supabase
      .from("delivery_notes")
      .update(payload)
      .eq("id", input.id)
      .eq("business_id", input.business_id)
      .select("*")
      .single();
    if (error) return { success: false, error: error.message };
    return { success: true, row: data as DeliveryNote };
  }

  const { data, error } = await supabase
    .from("delivery_notes")
    .insert(payload)
    .select("*")
    .single();
  if (error) return { success: false, error: error.message };
  return { success: true, row: data as DeliveryNote };
}

export async function updateDeliveryNoteStatus(input: {
  business_id: string;
  id: string;
  status: DeliveryNoteStatus;
  cancel_reason?: string;
}): Promise<{ success: boolean; row?: DeliveryNote; error?: string }> {
  const supabase = createClient();
  const patch: Record<string, unknown> = {
    delivery_status: input.status,
    status_changed_at: new Date().toISOString(),
  };
  if (input.status === "cancelled") {
    patch.cancel_reason = input.cancel_reason?.trim() || null;
  }
  const { data, error } = await supabase
    .from("delivery_notes")
    .update(patch)
    .eq("id", input.id)
    .eq("business_id", input.business_id)
    .select("*")
    .single();
  if (error) return { success: false, error: error.message };
  return { success: true, row: data as DeliveryNote };
}

export async function deleteDeliveryNote(
  businessId: string,
  id: string,
): Promise<{ success: boolean; error?: string }> {
  const supabase = createClient();
  const { data: deleted, error } = await supabase
    .from("delivery_notes")
    .delete()
    .eq("id", id)
    .eq("business_id", businessId)
    .select("id");
  if (error) return { success: false, error: error.message };
  if (!deleted?.length) {
    return {
      success: false,
      error: "Delivery note was not deleted from database (no access or already removed)",
    };
  }
  return { success: true };
}
