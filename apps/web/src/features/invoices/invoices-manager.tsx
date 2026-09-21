"use client";

import { useEffect, useMemo, useState } from "react";
import { Download, Eye, MessageCircle, Printer, Trash2 } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { DEMO_MODE, getDemoInvoices } from "@/lib/demo/data";
import { Button } from "@/components/ui/button";
import {
  DataTableShell,
  Field,
  PageHeader,
  SidePanel,
  fieldClass,
  searchClass,
  selectClass,
  thClass,
  tdClass,
} from "@/components/ui/side-panel";
import {
  downloadInvoicePdf,
  openInvoiceWindow,
  prefetchInvoicePdfLibs,
  type InvoiceWithItems,
} from "@/lib/invoice-document";
import { Spinner, LoadingOverlay } from "@/components/ui/spinner";
import { cn, formatDate, formatMoney } from "@/lib/utils";
import { paymentStatusLabel, paymentStatusFilterLabel } from "@/lib/payment-status";
import { recordPayment } from "@/lib/record-payment";
import type { Business, Invoice, PaymentMethod } from "@/types";
import { PAYMENT_METHODS } from "@/types";

type PanelMode =
  | { type: "closed" }
  | { type: "view"; invoice: InvoiceWithItems }
  | { type: "pay"; invoice: Invoice };

export function InvoicesManager({ business }: { business: Business }) {
  const isCar = business.business_type === "car";
  const [invoices, setInvoices] = useState<Invoice[]>([]);
  const [query, setQuery] = useState("");
  const [status, setStatus] = useState("all");
  const [loading, setLoading] = useState(true);
  const [panel, setPanel] = useState<PanelMode>({ type: "closed" });
  const [payAmount, setPayAmount] = useState(0);
  const [payMethod, setPayMethod] = useState<PaymentMethod>("cash");
  const [payRef, setPayRef] = useState("");
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [busyLabel, setBusyLabel] = useState("Please wait…");
  const [paySaving, setPaySaving] = useState(false);

  useEffect(() => {
    prefetchInvoicePdfLibs();
  }, []);

  async function load() {
    setLoading(true);

    if (DEMO_MODE) {
      let rows = getDemoInvoices(business.id);
      if (status !== "all") {
        rows = rows.filter((i) => i.payment_status === status);
      }
      setInvoices(rows);
      setLoading(false);
      return;
    }

    const supabase = createClient();
    let q = supabase
      .from("invoices")
      .select("*, customers(name, mobile, email, address)")
      .eq("business_id", business.id)
      .eq("status", "issued")
      .order("invoice_date", { ascending: false });

    if (status !== "all") q = q.eq("payment_status", status);

    const { data } = await q;
    setInvoices((data as Invoice[]) || []);
    setLoading(false);
  }

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [business.id, status]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return invoices;
    return invoices.filter(
      (inv) =>
        inv.invoice_number.toLowerCase().includes(q) ||
        ((inv.customers as { name?: string } | null)?.name || "")
          .toLowerCase()
          .includes(q),
    );
  }, [invoices, query]);

  async function fetchFullInvoice(id: string): Promise<InvoiceWithItems | null> {
    if (DEMO_MODE) {
      const inv = invoices.find((i) => i.id === id);
      return inv
        ? {
            ...inv,
            invoice_items: [
              {
                description:
                  business.business_type === "clothing"
                    ? "Demo product · Kurti set"
                    : "Demo line item",
                quantity: 1,
                unit_price: inv.grand_total,
                tax_rate: 0,
                line_total: inv.grand_total,
                ...(business.business_type === "clothing"
                  ? { size: "M", color: "Black", barcode: "DD2603000001" }
                  : {}),
              },
            ],
          }
        : null;
    }

    const supabase = createClient();
    const { data, error: qError } = await supabase
      .from("invoices")
      .select(
        "*, customers(name, mobile, email, address), invoice_items(*), payments(*)",
      )
      .eq("id", id)
      .eq("business_id", business.id)
      .maybeSingle();

    if (qError || !data) {
      setError(qError?.message || "Invoice not found");
      return null;
    }

    let full = data as InvoiceWithItems;
    if (business.business_type === "clothing") {
      const { enrichInvoiceItemBarcodes } = await import(
        "@/lib/invoice-document"
      );
      full = await enrichInvoiceItemBarcodes(full, business.id);
    }
    return full;
  }

  async function openView(inv: Invoice) {
    setError(null);
    setBusyLabel("Opening invoice…");
    setBusyId(inv.id);
    const full = await fetchFullInvoice(inv.id);
    setBusyId(null);
    if (full) setPanel({ type: "view", invoice: full });
  }

  function openPay(inv: Invoice) {
    setPanel({ type: "pay", invoice: inv });
    setPayAmount(Number(inv.amount_outstanding));
    setPayMethod("cash");
    setPayRef("");
  }

  async function downloadInvoice(inv: Invoice) {
    setBusyLabel("Preparing receipt…");
    setBusyId(inv.id);
    setError(null);
    try {
      const full = await fetchFullInvoice(inv.id);
      if (!full) return;
      await downloadInvoicePdf(business, full);
      setMessage(`80mm receipt downloaded · ${full.invoice_number}`);
    } catch {
      setError("Receipt download failed. Try Print on thermal printer.");
    } finally {
      setBusyId(null);
    }
  }

  async function printInvoice(inv: Invoice) {
    setBusyLabel("Opening receipt…");
    setBusyId(inv.id);
    const full = await fetchFullInvoice(inv.id);
    setBusyId(null);
    if (!full) return;
    await openInvoiceWindow(business, full, true);
  }

  async function addPayment() {
    if (panel.type !== "pay" || payAmount <= 0) return;
    const selected = panel.invoice;
    setError(null);
    setPaySaving(true);
    setBusyLabel("Recording payment…");

    try {
    if (DEMO_MODE) {
      setMessage(`Demo payment ₹${payAmount} recorded (not saved to DB)`);
      setInvoices((prev) =>
        prev.map((inv) =>
          inv.id === selected.id
            ? {
                ...inv,
                amount_paid: inv.amount_paid + payAmount,
                amount_outstanding: Math.max(
                  inv.amount_outstanding - payAmount,
                  0,
                ),
                payment_status:
                  inv.amount_outstanding - payAmount <= 0
                    ? "paid"
                    : "partial",
              }
            : inv,
        ),
      );
      setPanel({ type: "closed" });
      return;
    }

    const result = await recordPayment({
      business_id: business.id,
      invoice_id: selected.id,
      amount: payAmount,
      payment_method: payMethod,
      reference_number: payRef || undefined,
    });
    if (!result.success) {
      setError(result.error || "Payment failed");
      return;
    }
    setMessage("Payment recorded");
    setPanel({ type: "closed" });
    await load();
    } finally {
      setPaySaving(false);
    }
  }

  async function sendWhatsApp(invoice: Invoice) {
    setError(null);
    setMessage(null);
    setBusyLabel("Sending WhatsApp…");
    setBusyId(invoice.id);

    if (DEMO_MODE) {
      setBusyId(null);
      setMessage(`Demo: WhatsApp queued for ${invoice.invoice_number}`);
      return;
    }

    const supabase = createClient();
    const {
      data: { session },
    } = await supabase.auth.getSession();
    if (!session) {
      setBusyId(null);
      return;
    }

    const res = await fetch(
      `${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/send-whatsapp-invoice`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${session.access_token}`,
          apikey: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          business_id: business.id,
          invoice_id: invoice.id,
        }),
      },
    );
    const json = await res.json();
    setBusyId(null);
    if (!res.ok) setError(json.error || "WhatsApp send failed");
    else setMessage(`WhatsApp sent for ${invoice.invoice_number}`);
  }

  async function deleteInvoice(inv: Invoice) {
    if (
      !confirm(
        `Delete invoice ${inv.invoice_number}? This cannot be undone from the list.`,
      )
    ) {
      return;
    }

    setError(null);
    setMessage(null);
    setBusyLabel("Deleting invoice…");
    setBusyId(inv.id);

    if (DEMO_MODE) {
      setInvoices((prev) => prev.filter((x) => x.id !== inv.id));
      if (
        (panel.type === "view" && panel.invoice.id === inv.id) ||
        (panel.type === "pay" && panel.invoice.id === inv.id)
      ) {
        setPanel({ type: "closed" });
      }
      setBusyId(null);
      setMessage(`Invoice deleted · ${inv.invoice_number}`);
      return;
    }

    const supabase = createClient();
    const { error: delError } = await supabase
      .from("invoices")
      .update({ status: "cancelled" })
      .eq("id", inv.id)
      .eq("business_id", business.id);

    setBusyId(null);

    if (delError) {
      setError(delError.message || "Failed to delete invoice");
      return;
    }

    if (
      (panel.type === "view" && panel.invoice.id === inv.id) ||
      (panel.type === "pay" && panel.invoice.id === inv.id)
    ) {
      setPanel({ type: "closed" });
    }
    setMessage(`Invoice deleted · ${inv.invoice_number}`);
    await load();
  }

  const viewInvoice = panel.type === "view" ? panel.invoice : null;
  const payInvoice = panel.type === "pay" ? panel.invoice : null;

  return (
    <div className="space-y-5">
      <LoadingOverlay
        show={!!busyId || paySaving || loading}
        label={
          loading
            ? "Loading invoices…"
            : paySaving
              ? "Recording payment…"
              : busyLabel
        }
      />
      <PageHeader
        title="Invoices"
        description={`${business.name} · view, download, WhatsApp`}
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

      <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex flex-1 flex-col gap-2 sm:flex-row">
          <input
            type="search"
            placeholder="Search invoice # or customer…"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            className={searchClass}
          />
          <select
            className={`${selectClass} sm:w-44`}
            value={status}
            onChange={(e) => setStatus(e.target.value)}
          >
            <option value="all">All statuses</option>
            <option value="paid">Paid</option>
            <option value="partial">
              {paymentStatusFilterLabel(business.business_type)}
            </option>
            <option value="pending">Pending</option>
          </select>
        </div>
        <p className="text-xs tabular-nums text-slate-500">
          {filtered.length} rows
        </p>
      </div>

      {loading ? (
        <p className="py-10 text-sm text-slate-500">Loading…</p>
      ) : filtered.length === 0 ? (
        <div className="border border-dashed border-slate-300 py-16 text-center text-sm text-slate-500">
          No invoices yet.
        </div>
      ) : (
        <DataTableShell>
          <table className="min-w-full border-collapse text-left text-sm">
            <thead>
              <tr className="border-b border-slate-200 bg-slate-50/80">
                <th className={thClass}>Invoice</th>
                <th className={thClass}>Customer</th>
                <th className={thClass}>Date</th>
                <th className={`${thClass} text-right`}>Sales</th>
                <th className={`${thClass} text-right`}>Paid</th>
                <th className={thClass}>Status</th>
                <th className={`${thClass} text-right`}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((inv) => (
                <tr
                  key={inv.id}
                  className={cn(
                    "border-b border-slate-100 last:border-0 hover:bg-slate-50/70",
                    (viewInvoice?.id === inv.id || payInvoice?.id === inv.id) &&
                      "bg-brand-soft",
                  )}
                >
                  <td className={`${tdClass} font-medium text-slate-900`}>
                    <button
                      type="button"
                      className="font-semibold text-brand-ink hover:underline"
                      onClick={() => openView(inv)}
                    >
                      {inv.invoice_number}
                    </button>
                  </td>
                  <td className={tdClass}>
                    {(inv.customers as { name?: string } | null)?.name || "-"}
                  </td>
                  <td className={tdClass}>{formatDate(inv.invoice_date)}</td>
                  <td className={`${tdClass} text-right tabular-nums`}>
                    {formatMoney(inv.grand_total)}
                  </td>
                  <td className={`${tdClass} text-right tabular-nums`}>
                    {formatMoney(inv.amount_paid)}
                  </td>
                  <td className={tdClass}>
                    {paymentStatusLabel(
                      inv.payment_status,
                      business.business_type,
                    )}
                  </td>
                  <td className={`${tdClass} whitespace-nowrap text-right`}>
                    <div className="inline-flex flex-wrap items-center justify-end gap-x-2 gap-y-1">
                      <button
                        type="button"
                        className="inline-flex items-center gap-1 text-xs font-semibold text-slate-700 hover:underline disabled:opacity-50"
                        onClick={() => openView(inv)}
                        disabled={busyId === inv.id}
                      >
                        {busyId === inv.id ? (
                          <Spinner className="h-3 w-3" />
                        ) : (
                          <Eye className="h-3 w-3" />
                        )}
                        View
                      </button>
                      <button
                        type="button"
                        className="inline-flex items-center gap-1 text-xs font-semibold text-slate-700 hover:underline disabled:opacity-50"
                        onClick={() => downloadInvoice(inv)}
                        disabled={busyId === inv.id}
                      >
                        {busyId === inv.id ? (
                          <Spinner className="h-3 w-3" />
                        ) : (
                          <Download className="h-3 w-3" />
                        )}
                        Receipt
                      </button>
                      <button
                        type="button"
                        className="inline-flex items-center gap-1 text-xs font-semibold text-slate-700 hover:underline disabled:opacity-50"
                        onClick={() => printInvoice(inv)}
                        disabled={busyId === inv.id}
                      >
                        <Printer className="h-3 w-3" />
                        Print slip
                      </button>
                      {inv.amount_outstanding > 0 && (
                        <button
                          type="button"
                          className="text-xs font-semibold text-brand-ink hover:underline"
                          onClick={() => openPay(inv)}
                        >
                          {isCar ? "Token" : "Pay"}
                        </button>
                      )}
                      <button
                        type="button"
                        className="inline-flex items-center gap-1 text-xs font-semibold text-emerald-700 hover:underline disabled:opacity-50"
                        onClick={() => sendWhatsApp(inv)}
                        disabled={busyId === inv.id}
                      >
                        {busyId === inv.id ? (
                          <Spinner className="h-3 w-3" />
                        ) : (
                          <MessageCircle className="h-3 w-3" />
                        )}
                        WhatsApp
                      </button>
                      <button
                        type="button"
                        className="inline-flex items-center gap-1 text-xs font-semibold text-red-600 hover:underline disabled:opacity-50"
                        onClick={() => void deleteInvoice(inv)}
                        disabled={busyId === inv.id}
                      >
                        <Trash2 className="h-3 w-3" />
                        Delete
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </DataTableShell>
      )}

      <SidePanel
        open={panel.type === "view"}
        onClose={() => setPanel({ type: "closed" })}
        eyebrow="Invoice"
        title={viewInvoice?.invoice_number || "Invoice"}
        description={
          viewInvoice
            ? `${formatDate(viewInvoice.invoice_date)} · ${paymentStatusLabel(viewInvoice.payment_status, business.business_type)} · 80mm thermal slip`
            : undefined
        }
        widthClass="max-w-[480px]"
        footer={
          viewInvoice ? (
            <div className="flex flex-wrap gap-2">
              <Button
                type="button"
                variant="outline"
                className="flex-1"
                onClick={() => void openInvoiceWindow(business, viewInvoice, false)}
              >
                <Eye className="h-4 w-4" />
                Preview slip
              </Button>
              <Button
                type="button"
                variant="outline"
                className="flex-1"
                onClick={() => void openInvoiceWindow(business, viewInvoice, true)}
              >
                <Printer className="h-4 w-4" />
                Print slip
              </Button>
              <Button
                type="button"
                className="flex-1"
                loading={busyId === viewInvoice.id}
                onClick={async () => {
                  setBusyLabel("Preparing receipt…");
                  setBusyId(viewInvoice.id);
                  setError(null);
                  try {
                    await downloadInvoicePdf(business, viewInvoice);
                    setMessage(
                      `80mm receipt downloaded · ${viewInvoice.invoice_number}`,
                    );
                  } catch {
                    setError("Receipt download failed. Try Print slip.");
                  } finally {
                    setBusyId(null);
                  }
                }}
              >
                <Download className="h-4 w-4" />
                Download slip
              </Button>
              <Button
                type="button"
                variant="outline"
                className="flex-1 border-red-200 text-red-700 hover:bg-red-50"
                loading={busyId === viewInvoice.id}
                onClick={() => void deleteInvoice(viewInvoice)}
              >
                <Trash2 className="h-4 w-4" />
                Delete
              </Button>
            </div>
          ) : null
        }
      >
        {viewInvoice && (
          <div className="space-y-5 text-sm">
            <dl className="grid grid-cols-2 gap-3">
              <div>
                <dt className="text-xs text-slate-500">Customer</dt>
                <dd className="font-medium text-slate-900">
                  {(viewInvoice.customers as { name?: string } | null)?.name ||
                    "Walk-in"}
                </dd>
                <dd className="text-xs text-slate-500">
                  {(viewInvoice.customers as { mobile?: string } | null)
                    ?.mobile || ""}
                </dd>
              </div>
              <div>
                <dt className="text-xs text-slate-500">Status</dt>
                <dd className="font-medium text-slate-900">
                  {paymentStatusLabel(
                    viewInvoice.payment_status,
                    business.business_type,
                  )}
                </dd>
              </div>
              <div>
                <dt className="text-xs text-slate-500">Sales</dt>
                <dd className="font-semibold tabular-nums">
                  {formatMoney(viewInvoice.grand_total)}
                </dd>
              </div>
              <div>
                <dt className="text-xs text-slate-500">Outstanding</dt>
                <dd className="font-semibold tabular-nums text-brand-ink">
                  {formatMoney(viewInvoice.amount_outstanding)}
                </dd>
              </div>
            </dl>

            {business.business_type === "car" && (
              <div className="border border-blue-100 bg-blue-50/50 p-3 text-xs text-slate-700">
                <p className="font-semibold text-blue-900">Vehicle</p>
                <p>
                  {[
                    viewInvoice.car_make,
                    viewInvoice.car_model,
                    viewInvoice.car_variant,
                  ]
                    .filter(Boolean)
                    .join(" · ") || "-"}
                </p>
                <p>
                  Reg: {viewInvoice.car_registration_number || "-"} ·{" "}
                  {viewInvoice.car_color || "-"} ·{" "}
                  {viewInvoice.car_fuel_type || "-"}
                </p>
              </div>
            )}

            <p className="text-[11px] font-medium text-slate-500">
              Print / PDF opens a narrow 80mm thermal receipt (D-Mart style)
              {!isCar ? " with Size · Color · Price" : ""}.
            </p>

            <div>
              <p className="mb-2 text-xs font-semibold uppercase tracking-wider text-slate-400">
                Line items
              </p>
              <div className="overflow-hidden border border-slate-200">
                <table className="min-w-full text-left text-xs">
                  <thead className="bg-slate-50 text-slate-500">
                    <tr>
                      <th className="px-2 py-2">Item</th>
                      {!isCar ? (
                        <>
                          <th className="px-2 py-2">Size</th>
                          <th className="px-2 py-2">Color</th>
                          <th className="px-2 py-2 text-right">Price</th>
                        </>
                      ) : null}
                      <th className="px-2 py-2 text-right">Qty</th>
                      <th className="px-2 py-2 text-right">Amount</th>
                    </tr>
                  </thead>
                  <tbody>
                    {(viewInvoice.invoice_items || []).map((item, idx) => (
                      <tr key={idx} className="border-t border-slate-100">
                        <td className="px-2 py-2 text-slate-800">
                          <div className="font-medium">{item.description}</div>
                          {item.barcode ? (
                            <div className="font-mono text-[10px] text-slate-400">
                              {item.barcode}
                            </div>
                          ) : null}
                        </td>
                        {!isCar ? (
                          <>
                            <td className="px-2 py-2 font-semibold text-slate-800">
                              {item.size || "-"}
                            </td>
                            <td className="px-2 py-2 font-semibold text-slate-800">
                              {item.color || "-"}
                            </td>
                            <td className="px-2 py-2 text-right tabular-nums font-semibold text-brand-ink">
                              {formatMoney(item.unit_price)}
                            </td>
                          </>
                        ) : null}
                        <td className="px-2 py-2 text-right tabular-nums">
                          {item.quantity}
                        </td>
                        <td className="px-2 py-2 text-right tabular-nums">
                          {formatMoney(
                            item.line_total ??
                              item.quantity * item.unit_price,
                          )}
                        </td>
                      </tr>
                    ))}
                    {!viewInvoice.invoice_items?.length && (
                      <tr>
                        <td
                          colSpan={isCar ? 3 : 6}
                          className="px-2 py-4 text-center text-slate-400"
                        >
                          No items loaded
                        </td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>
            </div>

            <div className="flex gap-2">
              {viewInvoice.amount_outstanding > 0 && (
                <Button
                  type="button"
                  variant="outline"
                  className="flex-1"
                  onClick={() => openPay(viewInvoice)}
                >
                  {isCar ? "Add token / payment" : "Record payment"}
                </Button>
              )}
              <Button
                type="button"
                variant="outline"
                className="flex-1"
                onClick={() => sendWhatsApp(viewInvoice)}
              >
                <MessageCircle className="h-4 w-4" />
                WhatsApp
              </Button>
            </div>
          </div>
        )}
      </SidePanel>

      <SidePanel
        open={panel.type === "pay"}
        onClose={() => setPanel({ type: "closed" })}
        eyebrow={isCar ? "Token" : "Payment"}
        title={
          payInvoice
            ? isCar
              ? `Token · ${payInvoice.invoice_number}`
              : `Pay ${payInvoice.invoice_number}`
            : isCar
              ? "Token amount"
              : "Payment"
        }
        description={
          payInvoice
            ? `Outstanding ${formatMoney(payInvoice.amount_outstanding)}`
            : undefined
        }
        footer={
          <div className="flex gap-2">
            <Button
              type="button"
              variant="outline"
              className="flex-1"
              onClick={() => setPanel({ type: "closed" })}
            >
              Cancel
            </Button>
            <Button
              type="button"
              className="flex-1"
              loading={paySaving}
              onClick={addPayment}
            >
              {isCar ? "Save token" : "Record payment"}
            </Button>
          </div>
        }
      >
        {payInvoice && (
          <div className="space-y-4">
            <Field label={isCar ? "Token / amount" : "Amount"}>
              <input
                className={fieldClass}
                type="number"
                min={0}
                value={payAmount}
                onChange={(e) => setPayAmount(Number(e.target.value))}
              />
            </Field>
            <Field label="Method">
              <select
                className={`${fieldClass} mt-1.5`}
                value={payMethod}
                onChange={(e) =>
                  setPayMethod(e.target.value as PaymentMethod)
                }
              >
                {PAYMENT_METHODS.map((m) => (
                  <option key={m.value} value={m.value}>
                    {m.label}
                  </option>
                ))}
              </select>
            </Field>
            <Field label="Reference / UTR">
              <input
                className={fieldClass}
                value={payRef}
                onChange={(e) => setPayRef(e.target.value)}
                placeholder="Optional"
              />
            </Field>
          </div>
        )}
      </SidePanel>
    </div>
  );
}
