"use client";

import { useEffect, useMemo, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { DEMO_MODE, getDemoCustomers } from "@/lib/demo/data";
import {
  DataTableShell,
  Field,
  PageHeader,
  SidePanel,
  fieldClass,
  searchClass,
  thClass,
  tdClass,
} from "@/components/ui/side-panel";
import { cn, formatMoney } from "@/lib/utils";
import type { Business, Customer } from "@/types";

export function CustomersManager({ business }: { business: Business }) {
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [query, setQuery] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [panelOpen, setPanelOpen] = useState(false);
  const [editing, setEditing] = useState<Customer | null>(null);
  const [form, setForm] = useState({
    name: "",
    mobile: "",
    email: "",
    address: "",
  });
  const [saving, setSaving] = useState(false);

  async function load() {
    setLoading(true);
    setError(null);

    if (DEMO_MODE) {
      setCustomers(getDemoCustomers(business.id));
      setLoading(false);
      return;
    }

    const supabase = createClient();
    const { data, error: qError } = await supabase
      .from("customer_balances")
      .select("*")
      .eq("business_id", business.id)
      .order("name");

    if (qError) {
      const { data: raw, error: rawErr } = await supabase
        .from("customers")
        .select("*")
        .eq("business_id", business.id)
        .eq("is_active", true)
        .order("name");
      if (rawErr) setError(rawErr.message);
      else
        setCustomers(
          (raw || []).map((c) => ({
            ...c,
            total_billed: 0,
            total_paid: 0,
            outstanding_amount: 0,
          })),
        );
    } else {
      setCustomers(
        (data || []).map((row) => ({
          id: row.customer_id,
          business_id: row.business_id,
          name: row.name,
          mobile: row.mobile,
          email: row.email,
          address: row.address,
          notes: null,
          is_active: row.is_active,
          total_billed: Number(row.total_billed),
          total_paid: Number(row.total_paid),
          outstanding_amount: Number(row.outstanding_amount),
          invoice_count: Number(row.invoice_count),
        })),
      );
    }
    setLoading(false);
  }

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [business.id]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return customers;
    return customers.filter(
      (c) =>
        c.name.toLowerCase().includes(q) ||
        (c.mobile || "").includes(q) ||
        (c.email || "").toLowerCase().includes(q),
    );
  }, [customers, query]);

  function openEdit(c: Customer) {
    setEditing(c);
    setForm({
      name: c.name,
      mobile: c.mobile || "",
      email: c.email || "",
      address: c.address || "",
    });
    setPanelOpen(true);
  }

  async function save() {
    if (!editing || !form.name.trim()) return;
    setSaving(true);
    setError(null);

    if (DEMO_MODE) {
      const next: Customer = {
        ...editing,
        name: form.name.trim(),
        mobile: form.mobile.trim() || null,
        email: form.email.trim() || null,
        address: form.address.trim() || null,
      };
      setCustomers((prev) =>
        prev.map((c) => (c.id === editing.id ? next : c)),
      );
      setSaving(false);
      setPanelOpen(false);
      return;
    }

    const supabase = createClient();
    const { error: saveError } = await supabase
      .from("customers")
      .update({
        name: form.name.trim(),
        mobile: form.mobile.trim() || null,
        email: form.email.trim() || null,
        address: form.address.trim() || null,
      })
      .eq("id", editing.id);

    setSaving(false);
    if (saveError) {
      setError(saveError.message);
      return;
    }
    setPanelOpen(false);
    await load();
  }

  async function deactivate(c: Customer) {
    if (
      !confirm(
        `Permanently delete customer ${c.name} from database? This cannot be undone.`,
      )
    )
      return;
    if (DEMO_MODE) {
      setCustomers((prev) => prev.filter((x) => x.id !== c.id));
      return;
    }
    const supabase = createClient();
    const { data: deleted, error: delError } = await supabase
      .from("customers")
      .delete()
      .eq("id", c.id)
      .eq("business_id", business.id)
      .select("id");
    if (delError) {
      setError(delError.message || "Failed to delete customer from database");
      return;
    }
    if (!deleted?.length) {
      setError("Customer was not deleted (no access or already removed)");
      return;
    }
    await load();
  }

  return (
    <div className="space-y-5">
      <PageHeader
        title="Customers"
        description={`${business.name} · from billing (type name on invoice)`}
      />

      {error && (
        <div className="border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
          {error}
        </div>
      )}

      <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
        <input
          type="search"
          placeholder="Search name, mobile, email…"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          className={searchClass}
        />
        <p className="text-xs tabular-nums text-slate-500">
          {filtered.length} rows
        </p>
      </div>

      {loading ? (
        <p className="py-10 text-sm text-slate-500">Loading…</p>
      ) : filtered.length === 0 ? (
        <div className="border border-dashed border-slate-300 py-16 text-center text-sm text-slate-500">
          No customers yet. Type a customer name while creating an invoice.
        </div>
      ) : (
        <DataTableShell>
          <table className="min-w-full border-collapse text-left text-sm">
            <thead>
              <tr className="border-b border-slate-200 bg-slate-50/80">
                <th className={thClass}>#</th>
                <th className={thClass}>Name</th>
                <th className={thClass}>Mobile</th>
                <th className={`${thClass} text-right`}>Billed</th>
                <th className={`${thClass} text-right`}>Paid</th>
                <th className={`${thClass} text-right`}>Outstanding</th>
                <th className={`${thClass} text-right`}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((c, i) => (
                <tr
                  key={c.id}
                  className={cn(
                    "border-b border-slate-100 last:border-0 hover:bg-slate-50/70",
                    editing?.id === c.id && panelOpen && "bg-brand-soft",
                  )}
                >
                  <td className={`${tdClass} tabular-nums text-slate-400`}>
                    {i + 1}
                  </td>
                  <td className={`${tdClass} font-medium text-slate-900`}>
                    {c.name}
                  </td>
                  <td className={tdClass}>{c.mobile || "-"}</td>
                  <td className={`${tdClass} text-right tabular-nums`}>
                    {formatMoney(c.total_billed || 0)}
                  </td>
                  <td className={`${tdClass} text-right tabular-nums`}>
                    {formatMoney(c.total_paid || 0)}
                  </td>
                  <td
                    className={`${tdClass} text-right font-medium tabular-nums text-brand-ink`}
                  >
                    {formatMoney(c.outstanding_amount || 0)}
                  </td>
                  <td className={`${tdClass} space-x-3 text-right`}>
                    <button
                      type="button"
                      onClick={() => openEdit(c)}
                      className="text-xs font-semibold text-brand-ink hover:underline"
                    >
                      Edit
                    </button>
                    <button
                      type="button"
                      onClick={() => deactivate(c)}
                      className="text-xs font-semibold text-red-600 hover:underline"
                    >
                      Delete
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </DataTableShell>
      )}

      <SidePanel
        open={panelOpen}
        onClose={() => setPanelOpen(false)}
        title="Edit customer"
        description="Update contact details"
        footer={
          <>
            <button
              type="button"
              onClick={() => setPanelOpen(false)}
              className="rounded-lg border border-slate-200 px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-50"
            >
              Cancel
            </button>
            <button
              type="button"
              disabled={saving || !form.name.trim()}
              onClick={save}
              className="btn-brand rounded-lg px-4 py-2 text-sm font-semibold disabled:opacity-50"
            >
              {saving ? "Saving…" : "Save"}
            </button>
          </>
        }
      >
        <div className="space-y-3">
          <Field label="Name">
            <input
              className={fieldClass}
              value={form.name}
              onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
            />
          </Field>
          <Field label="Mobile">
            <input
              className={fieldClass}
              value={form.mobile}
              onChange={(e) =>
                setForm((f) => ({ ...f, mobile: e.target.value }))
              }
            />
          </Field>
          <Field label="Email">
            <input
              className={fieldClass}
              value={form.email}
              onChange={(e) =>
                setForm((f) => ({ ...f, email: e.target.value }))
              }
            />
          </Field>
          <Field label="Address">
            <textarea
              className={fieldClass}
              rows={3}
              value={form.address}
              onChange={(e) =>
                setForm((f) => ({ ...f, address: e.target.value }))
              }
            />
          </Field>
        </div>
      </SidePanel>
    </div>
  );
}
