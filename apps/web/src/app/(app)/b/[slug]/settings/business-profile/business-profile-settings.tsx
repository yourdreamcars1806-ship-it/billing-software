"use client";

import { useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { DEMO_MODE } from "@/lib/demo/data";
import { Button } from "@/components/ui/button";
import { LoadingOverlay } from "@/components/ui/spinner";
import { Field, PageHeader, fieldClass } from "@/components/ui/side-panel";
import type { Business } from "@/types";

export function BusinessProfileSettings({ business }: { business: Business }) {
  const [form, setForm] = useState({
    name: business.name,
    address: business.address || "",
    phone: business.phone || "",
    email: business.email || "",
    gstin: business.gstin || "",
    pan: business.pan || "",
    logo_url: business.logo_url || "",
  });
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function save() {
    setSaving(true);
    setError(null);
    setMessage(null);

    if (DEMO_MODE) {
      setSaving(false);
      setMessage("Demo: business profile saved locally");
      return;
    }

    const supabase = createClient();
    const { error: updateError } = await supabase
      .from("businesses")
      .update({
        name: form.name,
        address: form.address || null,
        phone: form.phone || null,
        email: form.email || null,
        gstin: form.gstin || null,
        pan: form.pan || null,
        logo_url: form.logo_url.trim() || null,
      })
      .eq("id", business.id);

    setSaving(false);
    if (updateError) {
      setError(updateError.message);
      return;
    }
    setMessage("Business profile saved");
  }

  return (
    <div className="space-y-5 border border-slate-200 bg-white p-5">
      <LoadingOverlay show={saving} label="Saving profile…" />
      <PageHeader
        title="Business profile"
        description="Name, address, GST - bill pe dikhega"
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

      <div className="grid gap-4 sm:grid-cols-2">
        <Field label="Business name">
          <input
            className={fieldClass}
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
          />
        </Field>
        <Field label="Phone">
          <input
            className={fieldClass}
            value={form.phone}
            onChange={(e) => setForm({ ...form, phone: e.target.value })}
          />
        </Field>
        <Field label="Business contact email">
          <input
            className={fieldClass}
            value={form.email}
            onChange={(e) => setForm({ ...form, email: e.target.value })}
          />
        </Field>
        <Field label="GSTIN">
          <input
            className={fieldClass}
            value={form.gstin}
            onChange={(e) => setForm({ ...form, gstin: e.target.value })}
          />
        </Field>
        <Field label="PAN">
          <input
            className={fieldClass}
            value={form.pan}
            onChange={(e) => setForm({ ...form, pan: e.target.value })}
          />
        </Field>
        <div className="sm:col-span-2">
          <Field
            label="Billing address"
            hint="Ye address invoice / bill pe dikhega"
          >
            <textarea
              className={`${fieldClass} h-20 resize-none py-2`}
              value={form.address}
              onChange={(e) => setForm({ ...form, address: e.target.value })}
              placeholder="NIBM Clover Hills Plaza, Office No. …"
            />
          </Field>
        </div>
        <div className="sm:col-span-2">
          <Field
            label="Logo URL (invoice)"
            hint={
              business.business_type === "car"
                ? "Default: /images/your-dream-cars-logo.png"
                : "Default: /images/drape-and-dream-logo.png"
            }
          >
            <input
              className={fieldClass}
              value={form.logo_url}
              onChange={(e) => setForm({ ...form, logo_url: e.target.value })}
              placeholder={
                business.business_type === "car"
                  ? "/images/your-dream-cars-logo.png"
                  : "/images/drape-and-dream-logo.png"
              }
            />
          </Field>
          {form.logo_url ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={form.logo_url}
              alt="Logo preview"
                className="mt-3 h-16 w-16 rounded-lg border border-slate-200 bg-white object-contain p-1"
            />
          ) : null}
        </div>
      </div>
    </div>
  );
}
