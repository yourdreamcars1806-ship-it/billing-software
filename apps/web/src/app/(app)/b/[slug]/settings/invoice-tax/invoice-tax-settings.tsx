"use client";

import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { DEMO_MODE } from "@/lib/demo/data";
import { Button } from "@/components/ui/button";
import { LoadingOverlay } from "@/components/ui/spinner";
import { Field, PageHeader, fieldClass } from "@/components/ui/side-panel";
import type { Business } from "@/types";

export function InvoiceTaxSettings({ business }: { business: Business }) {
  const [invoicePrefix, setInvoicePrefix] = useState(
    business.business_type === "clothing" ? "DD" : "YDC",
  );
  const [footerTerms, setFooterTerms] = useState(
    business.business_type === "clothing"
      ? "Thank you for shopping at Drape & Dream."
      : "Thank you for choosing Your Dream Cars.",
  );
  const [taxRate, setTaxRate] = useState(
    business.business_type === "clothing" ? 12 : 18,
  );
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (DEMO_MODE) return;

    async function load() {
      const supabase = createClient();
      const [{ data: inv }, { data: bs }] = await Promise.all([
        supabase
          .from("invoice_settings")
          .select("*")
          .eq("business_id", business.id)
          .maybeSingle(),
        supabase
          .from("business_settings")
          .select("*")
          .eq("business_id", business.id)
          .maybeSingle(),
      ]);
      if (inv) {
        setInvoicePrefix(inv.invoice_prefix);
        setFooterTerms(inv.footer_terms || "");
      }
      if (bs) setTaxRate(Number(bs.default_tax_rate));
    }
    load();
  }, [business.id]);

  async function save() {
    setSaving(true);
    setError(null);
    setMessage(null);

    if (DEMO_MODE) {
      setSaving(false);
      setMessage("Demo: invoice & tax saved locally");
      return;
    }

    const supabase = createClient();
    const results = await Promise.all([
      supabase
        .from("invoice_settings")
        .update({
          invoice_prefix: invoicePrefix,
          footer_terms: footerTerms || null,
        })
        .eq("business_id", business.id),
      supabase
        .from("business_settings")
        .update({
          default_tax_rate: taxRate,
          enable_barcode: business.business_type === "clothing",
        })
        .eq("business_id", business.id),
    ]);

    setSaving(false);
    const firstError = results.find((r) => r.error)?.error;
    if (firstError) {
      setError(firstError.message);
      return;
    }
    setMessage("Invoice & tax settings saved");
  }

  return (
    <div className="space-y-5 border border-slate-200 bg-white p-5">
      <LoadingOverlay show={saving} label="Saving invoice settings…" />
      <PageHeader
        title="Invoice & tax"
        description="Bill number prefix, tax rate, footer terms"
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
        <Field label="Invoice prefix">
          <input
            className={fieldClass}
            value={invoicePrefix}
            onChange={(e) => setInvoicePrefix(e.target.value)}
          />
        </Field>
        <Field label="Default tax rate %">
          <input
            className={fieldClass}
            type="number"
            value={taxRate}
            onChange={(e) => setTaxRate(Number(e.target.value))}
          />
        </Field>
        <div className="sm:col-span-2">
          <Field label="Footer / terms">
            <input
              className={fieldClass}
              value={footerTerms}
              onChange={(e) => setFooterTerms(e.target.value)}
            />
          </Field>
        </div>
      </div>

      {business.business_type === "clothing" && (
        <p className="text-xs text-slate-500">
          Barcode generation enabled for clothing variants (Code 128).
        </p>
      )}
    </div>
  );
}
