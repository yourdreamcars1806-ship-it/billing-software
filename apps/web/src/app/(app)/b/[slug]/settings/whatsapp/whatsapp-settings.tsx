"use client";

import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { DEMO_MODE } from "@/lib/demo/data";
import { Button } from "@/components/ui/button";
import { LoadingOverlay } from "@/components/ui/spinner";
import { Field, PageHeader, fieldClass } from "@/components/ui/side-panel";
import type { Business } from "@/types";

export function WhatsappSettings({ business }: { business: Business }) {
  const [waEnabled, setWaEnabled] = useState(false);
  const [waAuto, setWaAuto] = useState(false);
  const [waPhoneId, setWaPhoneId] = useState("");
  const [waAccountId, setWaAccountId] = useState("");
  const [waTemplate, setWaTemplate] = useState("");
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (DEMO_MODE) return;

    async function load() {
      const supabase = createClient();
      const { data: wa } = await supabase
        .from("whatsapp_settings")
        .select("*")
        .eq("business_id", business.id)
        .maybeSingle();
      if (wa) {
        setWaEnabled(!!wa.enabled);
        setWaAuto(!!wa.auto_send_invoice);
        setWaPhoneId(wa.phone_number_id || "");
        setWaAccountId(wa.business_account_id || "");
        setWaTemplate(wa.message_template_id || "");
      }
    }
    load();
  }, [business.id]);

  async function save() {
    setSaving(true);
    setError(null);
    setMessage(null);

    if (DEMO_MODE) {
      setSaving(false);
      setMessage("Demo: WhatsApp settings saved locally");
      return;
    }

    const supabase = createClient();
    const { error: updateError } = await supabase
      .from("whatsapp_settings")
      .update({
        enabled: waEnabled,
        auto_send_invoice: waAuto,
        phone_number_id: waPhoneId || null,
        business_account_id: waAccountId || null,
        message_template_id: waTemplate || null,
      })
      .eq("business_id", business.id);

    setSaving(false);
    if (updateError) {
      setError(updateError.message);
      return;
    }
    setMessage("WhatsApp settings saved");
  }

  return (
    <div className="space-y-5 border border-slate-200 bg-white p-5">
      <LoadingOverlay show={saving} label="Saving WhatsApp settings…" />
      <PageHeader
        title="WhatsApp invoice"
        description="Bill create hone par auto WhatsApp bhejne ke liye"
        action={
          <Button size="md" onClick={save} loading={saving}>
            Save
          </Button>
        }
      />

      {(message || error) && (
        <div
          className={`border px-3 py-2 text-sm ${
            error
              ? "border-red-200 bg-red-50 text-red-700"
              : "border-emerald-200 bg-emerald-50 text-emerald-800"
          }`}
        >
          {error || message}
        </div>
      )}

      <p className="text-sm text-slate-500">
        Auto send ke liye dono options ON rakho. Access token Supabase Edge
        secrets me rehta hai - yahan nahi.
      </p>

      <div className="flex flex-col gap-3 sm:flex-row sm:gap-8">
        <label className="flex items-center gap-2 text-sm text-slate-700">
          <input
            type="checkbox"
            checked={waEnabled}
            onChange={(e) => setWaEnabled(e.target.checked)}
          />
          WhatsApp enabled
        </label>
        <label className="flex items-center gap-2 text-sm text-slate-700">
          <input
            type="checkbox"
            checked={waAuto}
            onChange={(e) => setWaAuto(e.target.checked)}
          />
          Automatic WhatsApp on new invoice
        </label>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <Field label="Phone number ID (Meta)">
          <input
            className={fieldClass}
            value={waPhoneId}
            onChange={(e) => setWaPhoneId(e.target.value)}
            placeholder="From Meta WhatsApp Cloud API"
          />
        </Field>
        <Field label="Business account ID">
          <input
            className={fieldClass}
            value={waAccountId}
            onChange={(e) => setWaAccountId(e.target.value)}
          />
        </Field>
        <Field label="Message template name">
          <input
            className={fieldClass}
            value={waTemplate}
            onChange={(e) => setWaTemplate(e.target.value)}
            placeholder="Optional - else text message"
          />
        </Field>
      </div>

      <p className="bg-brand-soft px-3 py-2 text-xs text-brand-dark">
        Secrets (CLI):{" "}
        <span className="font-mono">
          supabase secrets set WHATSAPP_TOKEN_
          {business.business_type === "clothing"
            ? "DRAPE_AND_DREAM"
            : "YOUR_DREAM_CARS"}
          =EAA...
        </span>
      </p>
    </div>
  );
}
