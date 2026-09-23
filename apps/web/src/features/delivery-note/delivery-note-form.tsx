"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  AlertTriangle,
  Ban,
  Car,
  CheckCircle2,
  ClipboardSignature,
  Download,
  Eye,
  FilePlus2,
  FileText,
  IdCard,
  IndianRupee,
  Pencil,
  Printer,
  Save,
  Trash2,
  UserRound,
} from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { DEMO_MODE, getDemoInvoices } from "@/lib/demo/data";
import { Button } from "@/components/ui/button";
import { SidePanel } from "@/components/ui/side-panel";
import {
  defaultCancellationTerms,
  downloadDeliveryNotePdf,
  openDeliveryNoteWindow,
  type DeliveryNoteData,
} from "@/lib/delivery-note-document";
import {
  allocateDeliveryNoteNumber,
  deleteDeliveryNote,
  listDeliveryNotes,
  rowToForm,
  saveDeliveryNote,
  summarizeDeliveryNotes,
  updateDeliveryNoteStatus,
} from "@/lib/delivery-notes";
import { cn, formatDate, formatMoney } from "@/lib/utils";
import type {
  Business,
  DeliveryNote,
  DeliveryNoteStatus,
  Invoice,
} from "@/types";

const inputClass =
  "mt-1.5 h-11 w-full rounded-xl border border-slate-200 bg-white px-3.5 text-sm text-slate-900 shadow-sm outline-none transition placeholder:text-slate-400 hover:border-slate-300 focus:border-blue-500 focus:ring-4 focus:ring-blue-500/10";

const areaClass =
  "mt-1.5 w-full rounded-xl border border-slate-200 bg-white px-3.5 py-2.5 text-sm text-slate-900 shadow-sm outline-none transition placeholder:text-slate-400 hover:border-slate-300 focus:border-blue-500 focus:ring-4 focus:ring-blue-500/10";

const selectNice =
  "mt-1.5 h-11 w-full rounded-xl border border-slate-200 bg-white px-3.5 text-sm text-slate-900 shadow-sm outline-none transition hover:border-slate-300 focus:border-blue-500 focus:ring-4 focus:ring-blue-500/10";

function todayIso() {
  return new Date().toISOString().slice(0, 10);
}

function nowTime() {
  return new Date().toLocaleTimeString("en-IN", {
    hour: "2-digit",
    minute: "2-digit",
    hour12: true,
  });
}

function emptyNote(noteNo = "", businessName = "Your Dream Cars"): DeliveryNoteData {
  return {
    delivery_note_no: noteNo,
    delivery_date: todayIso(),
    delivery_time: nowTime(),
    customer_name: "",
    customer_address: "",
    customer_mobile: "",
    id_proof: "",
    id_no: "",
    car_make: "",
    car_model_variant: "",
    car_registration_number: "",
    car_manufacturing_year: "",
    car_color: "",
    car_fuel_type: "",
    car_chassis_number: "",
    car_engine_number: "",
    odometer_km: "",
    total_vehicle_price: "",
    amount_received: "",
    balance_amount: "",
    payment_modes: {
      cash: false,
      upi: false,
      bank_transfer: false,
      finance: false,
      other: false,
    },
    payment_other: "",
    docs: {
      rc: true,
      insurance: true,
      puc: false,
      service_records: false,
      keys: true,
      spare_key: false,
      other: false,
    },
    docs_other: "",
    declaration_name: "",
    customer_sign_name: "",
    customer_sign_datetime: "",
    auth_sign_name: "",
    handed_over_by: "",
    cancel_terms_enabled: true,
    cancel_gst_percent: "18",
    paper_processing_fee: "",
    cancellation_terms: defaultCancellationTerms("18", "", businessName),
    delivery_status: "draft",
    cancel_reason: "",
  };
}

function statusMeta(status: DeliveryNoteStatus | string | null | undefined) {
  const s = status || "draft";
  if (s === "confirmed") {
    return {
      label: "Confirmed",
      className: "bg-emerald-100 text-emerald-800 border-emerald-200",
    };
  }
  if (s === "cancelled") {
    return {
      label: "Cancelled",
      className: "bg-red-100 text-red-800 border-red-200",
    };
  }
  return {
    label: "Draft",
    className: "bg-slate-100 text-slate-700 border-slate-200",
  };
}

function FormField({
  label,
  children,
  hint,
  className,
}: {
  label: string;
  children: React.ReactNode;
  hint?: string;
  className?: string;
}) {
  return (
    <label className={cn("block", className)}>
      <span className="text-[11px] font-semibold uppercase tracking-[0.12em] text-slate-500">
        {label}
      </span>
      {children}
      {hint ? (
        <p className="mt-1.5 text-[11px] leading-snug text-slate-400">{hint}</p>
      ) : null}
    </label>
  );
}

function Section({
  step,
  title,
  subtitle,
  icon: Icon,
  children,
  tone = "blue",
}: {
  step: string;
  title: string;
  subtitle?: string;
  icon: React.ComponentType<{ className?: string }>;
  children: React.ReactNode;
  tone?: "blue" | "amber";
}) {
  return (
    <section
      className={cn(
        "overflow-hidden rounded-2xl border bg-white shadow-sm",
        tone === "amber" ? "border-amber-200/80" : "border-slate-200/90",
      )}
    >
      <div
        className={cn(
          "flex items-start gap-3 border-b px-4 py-3.5 sm:px-5",
          tone === "amber"
            ? "border-amber-100 bg-gradient-to-r from-amber-50 to-orange-50/40"
            : "border-slate-100 bg-gradient-to-r from-blue-50/90 via-slate-50 to-white",
        )}
      >
        <div
          className={cn(
            "flex h-10 w-10 shrink-0 items-center justify-center rounded-xl shadow-sm",
            tone === "amber"
              ? "bg-amber-500 text-white"
              : "bg-blue-600 text-white",
          )}
        >
          <Icon className="h-5 w-5" />
        </div>
        <div className="min-w-0 flex-1">
          <p
            className={cn(
              "text-[10px] font-bold uppercase tracking-[0.16em]",
              tone === "amber" ? "text-amber-700" : "text-blue-700",
            )}
          >
            Step {step}
          </p>
          <h2 className="text-sm font-semibold text-slate-900 sm:text-[15px]">
            {title}
          </h2>
          {subtitle ? (
            <p className="mt-0.5 text-xs text-slate-500">{subtitle}</p>
          ) : null}
        </div>
      </div>
      <div className="space-y-4 p-4 sm:p-5">{children}</div>
    </section>
  );
}

function Chip({
  label,
  checked,
  onChange,
}: {
  label: string;
  checked: boolean;
  onChange: (v: boolean) => void;
}) {
  return (
    <button
      type="button"
      onClick={() => onChange(!checked)}
      className={cn(
        "inline-flex h-9 items-center rounded-full border px-3.5 text-xs font-semibold transition",
        checked
          ? "border-blue-600 bg-blue-600 text-white shadow-sm"
          : "border-slate-200 bg-white text-slate-600 hover:border-blue-300 hover:bg-blue-50 hover:text-blue-800",
      )}
    >
      {checked ? "✓ " : ""}
      {label}
    </button>
  );
}

export function DeliveryNoteForm({ business }: { business: Business }) {
  const [form, setForm] = useState<DeliveryNoteData>(() =>
    emptyNote("", business.name),
  );
  const [editingId, setEditingId] = useState<string | null>(null);
  const [linkedInvoiceId, setLinkedInvoiceId] = useState<string | null>(null);
  const [saved, setSaved] = useState<DeliveryNote[]>([]);
  const [invoices, setInvoices] = useState<Invoice[]>([]);
  const [invoiceId, setInvoiceId] = useState("");
  const [busy, setBusy] = useState(false);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [dbReady, setDbReady] = useState(true);
  const [statusFilter, setStatusFilter] = useState<
    "all" | DeliveryNoteStatus
  >("all");
  const [statusBusy, setStatusBusy] = useState(false);
  const [panelOpen, setPanelOpen] = useState(false);

  const loadSaved = useCallback(async () => {
    if (DEMO_MODE) {
      setSaved([]);
      setDbReady(true);
      return;
    }
    try {
      const rows = await listDeliveryNotes(business.id);
      setSaved(rows);
      setDbReady(true);
    } catch (e) {
      setDbReady(false);
      setError(
        e instanceof Error
          ? e.message
          : "Delivery notes table missing — run migration 20260322000009",
      );
    }
  }, [business.id]);

  useEffect(() => {
    void loadSaved();
  }, [loadSaved]);

  useEffect(() => {
    async function loadInvoices() {
      if (DEMO_MODE) {
        setInvoices(getDemoInvoices(business.id).slice(0, 30));
        return;
      }
      const supabase = createClient();
      const { data } = await supabase
        .from("invoices")
        .select("*, customers(name, mobile, email, address)")
        .eq("business_id", business.id)
        .eq("status", "issued")
        .order("invoice_date", { ascending: false })
        .limit(40);
      setInvoices((data as Invoice[]) || []);
    }
    void loadInvoices();
  }, [business.id]);

  const balancePreview = useMemo(() => {
    const total = Number(form.total_vehicle_price) || 0;
    const paid = Number(form.amount_received) || 0;
    if (!form.total_vehicle_price && !form.amount_received) return null;
    return Math.max(total - paid, 0);
  }, [form.total_vehicle_price, form.amount_received]);

  const stats = useMemo(() => summarizeDeliveryNotes(saved), [saved]);

  const filteredSaved = useMemo(() => {
    if (statusFilter === "all") return saved;
    return saved.filter(
      (r) => (r.delivery_status || "draft") === statusFilter,
    );
  }, [saved, statusFilter]);

  function patch(p: Partial<DeliveryNoteData>) {
    setForm((prev) => ({ ...prev, ...p }));
  }

  function preparedForm(): DeliveryNoteData {
    return {
      ...form,
      declaration_name:
        form.declaration_name || form.customer_name || form.customer_sign_name,
      customer_sign_name: form.customer_sign_name || form.customer_name,
      balance_amount:
        form.balance_amount ||
        (balancePreview != null ? String(balancePreview) : ""),
    };
  }

  function closePanel() {
    setPanelOpen(false);
  }

  async function startNew() {
    setError(null);
    setMessage(null);
    setEditingId(null);
    setLinkedInvoiceId(null);
    setInvoiceId("");
    if (DEMO_MODE) {
      setForm(emptyNote(`DEMO-DN-${Date.now().toString().slice(-6)}`, business.name));
      setPanelOpen(true);
      return;
    }
    try {
      const no = await allocateDeliveryNoteNumber(business.id);
      setForm(emptyNote(no, business.name));
      setMessage(`New note ${no}`);
    } catch (e) {
      setForm(emptyNote(`YDC-DN-${Date.now().toString().slice(-5)}`, business.name));
      setError(
        e instanceof Error
          ? e.message
          : "Could not allocate number — apply DB migration",
      );
    }
    setPanelOpen(true);
  }

  function openSaved(row: DeliveryNote) {
    setEditingId(row.id);
    setLinkedInvoiceId(row.invoice_id);
    setInvoiceId(row.invoice_id || "");
    setForm(rowToForm(row));
    setMessage(`Editing ${row.delivery_note_number}`);
    setError(null);
    setPanelOpen(true);
  }

  function applyInvoice(id: string) {
    setInvoiceId(id);
    setLinkedInvoiceId(id || null);
    const inv = invoices.find((i) => i.id === id);
    if (!inv) return;
    const cust = inv.customers as
      | { name?: string; mobile?: string; address?: string }
      | null
      | undefined;
    const modelVariant = [inv.car_model, inv.car_variant]
      .filter(Boolean)
      .join(" / ");
    patch({
      customer_name: cust?.name || "",
      customer_mobile: cust?.mobile || "",
      customer_address: cust?.address || "",
      declaration_name: cust?.name || "",
      customer_sign_name: cust?.name || "",
      car_make: inv.car_make || "",
      car_model_variant: modelVariant,
      car_registration_number: inv.car_registration_number || "",
      car_manufacturing_year: inv.car_manufacturing_year
        ? String(inv.car_manufacturing_year)
        : "",
      car_color: inv.car_color || "",
      car_fuel_type: inv.car_fuel_type || "",
      car_chassis_number: inv.car_chassis_number || "",
      car_engine_number: inv.car_engine_number || "",
      total_vehicle_price: String(inv.grand_total ?? ""),
      amount_received: String(inv.amount_paid ?? ""),
      balance_amount: String(inv.amount_outstanding ?? ""),
    });
    setMessage(`Filled from invoice ${inv.invoice_number}`);
  }

  function syncBalance() {
    if (balancePreview == null) return;
    patch({ balance_amount: String(balancePreview) });
  }

  async function onSave() {
    setSaving(true);
    setError(null);
    try {
      if (DEMO_MODE) {
        setMessage("Demo mode — not saved to database");
        return;
      }
      const data = preparedForm();
      if (!data.delivery_note_no.trim()) {
        const no = await allocateDeliveryNoteNumber(business.id);
        data.delivery_note_no = no;
        setForm((f) => ({ ...f, delivery_note_no: no }));
      }
      const result = await saveDeliveryNote({
        business_id: business.id,
        form: data,
        id: editingId,
        invoice_id: linkedInvoiceId,
      });
      if (!result.success || !result.row) {
        setError(result.error || "Save failed");
        return;
      }
      setEditingId(result.row.id);
      setForm(rowToForm(result.row));
      setMessage(
        editingId
          ? `Updated ${result.row.delivery_note_number}`
          : `Saved ${result.row.delivery_note_number}`,
      );
      await loadSaved();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Save failed");
    } finally {
      setSaving(false);
    }
  }

  async function onDelete(id: string, no: string) {
    if (
      !window.confirm(
        `Permanently delete delivery note ${no} from database? This cannot be undone.`,
      )
    ) {
      return;
    }
    const result = await deleteDeliveryNote(business.id, id);
    if (!result.success) {
      setError(result.error || "Delete failed");
      return;
    }
    if (editingId === id) {
      setEditingId(null);
      setForm(emptyNote("", business.name));
      setPanelOpen(false);
    }
    setMessage(`Deleted from database · ${no}`);
    await loadSaved();
  }

  async function preview(print = false, data?: DeliveryNoteData) {
    setBusy(true);
    setError(null);
    try {
      const ok = await openDeliveryNoteWindow(
        business,
        data ?? preparedForm(),
        print,
      );
      if (!ok) setError("Pop-up blocked — allow pop-ups for print/preview.");
      else setMessage(print ? "Print dialog opened" : "Preview opened");
    } catch {
      setError("Could not open delivery note");
    } finally {
      setBusy(false);
    }
  }

  async function onPdf() {
    setBusy(true);
    setError(null);
    try {
      await downloadDeliveryNotePdf(business, preparedForm());
      setMessage("PDF downloaded");
    } catch (e) {
      const msg =
        e instanceof Error ? e.message : "PDF download failed";
      setError(`PDF failed: ${msg}. Try Preview → Print → Save as PDF.`);
    } finally {
      setBusy(false);
    }
  }

  async function setStatus(next: DeliveryNoteStatus) {
    if (!editingId) {
      setError("Pehle note Save karo, phir Confirm / Cancel karo");
      return;
    }
    let reason = form.cancel_reason;
    if (next === "cancelled") {
      const typed = window.prompt(
        "Cancel reason (optional):",
        form.cancel_reason || "",
      );
      if (typed === null) return;
      reason = typed;
    }
    setStatusBusy(true);
    setError(null);
    try {
      if (DEMO_MODE) {
        patch({ delivery_status: next, cancel_reason: reason });
        setMessage(`Demo status → ${next}`);
        return;
      }
      const result = await updateDeliveryNoteStatus({
        business_id: business.id,
        id: editingId,
        status: next,
        cancel_reason: reason,
      });
      if (!result.success || !result.row) {
        setError(result.error || "Status update failed — run migration 00011");
        return;
      }
      setForm(rowToForm(result.row));
      setMessage(
        next === "confirmed"
          ? `Confirmed · ${result.row.delivery_note_number}`
          : next === "cancelled"
            ? `Cancelled · ${result.row.delivery_note_number}`
            : `Moved to draft · ${result.row.delivery_note_number}`,
      );
      await loadSaved();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Status update failed");
    } finally {
      setStatusBusy(false);
    }
  }

  const statusBadge = statusMeta(form.delivery_status);

  const panelMessages = (
    <>
      {message ? (
        <div className="rounded-xl border border-emerald-200 bg-emerald-50 px-3.5 py-2 text-sm text-emerald-800">
          {message}
        </div>
      ) : null}
      {error ? (
        <div className="rounded-xl border border-red-200 bg-red-50 px-3.5 py-2 text-sm text-red-700">
          {error}
        </div>
      ) : null}
    </>
  );

  const panelFooter = (
    <div className="flex flex-wrap gap-2">
      <Button
        type="button"
        size="sm"
        loading={saving}
        onClick={() => void onSave()}
        disabled={!dbReady && !DEMO_MODE}
      >
        <Save className="h-3.5 w-3.5" />
        {editingId ? "Update" : "Save"}
      </Button>
      <Button
        type="button"
        size="sm"
        className="bg-emerald-600 text-white hover:bg-emerald-500"
        loading={statusBusy}
        disabled={!editingId}
        onClick={() => void setStatus("confirmed")}
      >
        <CheckCircle2 className="h-3.5 w-3.5" />
        Confirm
      </Button>
      <Button
        type="button"
        size="sm"
        variant="danger"
        loading={statusBusy}
        disabled={!editingId}
        onClick={() => void setStatus("cancelled")}
      >
        <Ban className="h-3.5 w-3.5" />
        Cancel deal
      </Button>
      <Button
        type="button"
        variant="outline"
        size="sm"
        loading={busy}
        onClick={() => void preview(false)}
      >
        <Eye className="h-3.5 w-3.5" />
        Preview
      </Button>
      <Button
        type="button"
        variant="outline"
        size="sm"
        loading={busy}
        onClick={() => void onPdf()}
      >
        <Download className="h-3.5 w-3.5" />
        PDF
      </Button>
      <Button
        type="button"
        variant="outline"
        size="sm"
        loading={busy}
        onClick={() => void preview(true)}
      >
        <Printer className="h-3.5 w-3.5" />
        Print
      </Button>
    </div>
  );

  return (
    <div className="space-y-5">
      <div className="relative overflow-hidden rounded-2xl border border-slate-200 bg-gradient-to-br from-[#0b1f4d] via-[#123a8c] to-[#1d4ed8] px-5 py-5 text-white shadow-lg sm:px-7 sm:py-6">
        <div className="pointer-events-none absolute -right-10 -top-10 h-40 w-40 rounded-full bg-white/10 blur-2xl" />
        <div className="relative flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p className="text-[11px] font-bold uppercase tracking-[0.18em] text-blue-100/90">
              Your Dream Cars · Operations
            </p>
            <h1 className="mt-1 text-2xl font-bold tracking-tight sm:text-3xl">
              Vehicle Delivery Desk
            </h1>
            <p className="mt-1.5 max-w-xl text-sm text-blue-100/85">
              Create, confirm or cancel delivery notes — saved in your system
              with A4 PDF &amp; print.
            </p>
          </div>
          <Button
            type="button"
            variant="secondary"
            className="bg-white text-blue-900 hover:bg-blue-50"
            onClick={() => void startNew()}
          >
            <FilePlus2 className="h-4 w-4" />
            New note
          </Button>
        </div>
      </div>

      <div className="grid gap-3 sm:grid-cols-3">
        {(
          [
            {
              key: "all" as const,
              label: "Total delivery notes",
              value: stats.total,
              hint: "All saved in system",
              tone: "from-slate-50 to-white border-slate-200",
              valueClass: "text-slate-900",
              icon: FileText,
              iconBg: "bg-slate-900 text-white",
            },
            {
              key: "confirmed" as const,
              label: "Confirmed deliveries",
              value: stats.confirmed,
              hint: "Vehicle handed over",
              tone: "from-emerald-50 to-white border-emerald-200",
              valueClass: "text-emerald-800",
              icon: CheckCircle2,
              iconBg: "bg-emerald-600 text-white",
            },
            {
              key: "cancelled" as const,
              label: "Cancelled deliveries",
              value: stats.cancelled,
              hint: "Deal cancelled",
              tone: "from-red-50 to-white border-red-200",
              valueClass: "text-red-800",
              icon: Ban,
              iconBg: "bg-red-600 text-white",
            },
          ] as const
        ).map((card) => {
          const Icon = card.icon;
          const active =
            statusFilter === card.key ||
            (card.key === "all" && statusFilter === "all");
          return (
            <button
              key={card.key}
              type="button"
              onClick={() =>
                setStatusFilter(card.key === "all" ? "all" : card.key)
              }
              className={cn(
                "rounded-2xl border bg-gradient-to-br p-4 text-left shadow-sm transition hover:shadow-md",
                card.tone,
                active && "ring-2 ring-blue-500 ring-offset-2",
              )}
            >
              <div className="flex items-start justify-between gap-3">
                <div>
                  <p className="text-[11px] font-semibold uppercase tracking-[0.1em] text-slate-500">
                    {card.label}
                  </p>
                  <p
                    className={cn(
                      "mt-2 text-3xl font-bold tabular-nums tracking-tight",
                      card.valueClass,
                    )}
                  >
                    {card.value}
                  </p>
                  <p className="mt-1 text-xs text-slate-500">{card.hint}</p>
                </div>
                <span
                  className={cn(
                    "flex h-10 w-10 items-center justify-center rounded-xl",
                    card.iconBg,
                  )}
                >
                  <Icon className="h-5 w-5" />
                </span>
              </div>
            </button>
          );
        })}
      </div>

      {message ? (
        <div className="rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-2.5 text-sm text-emerald-800">
          {message}
        </div>
      ) : null}
      {error ? (
        <div className="rounded-xl border border-red-200 bg-red-50 px-4 py-2.5 text-sm text-red-700">
          {error}
        </div>
      ) : null}
      {!dbReady && !DEMO_MODE ? (
        <div className="rounded-xl border border-amber-200 bg-amber-50 px-4 py-2.5 text-sm text-amber-900">
          Run migrations{" "}
          <code className="rounded bg-amber-100 px-1.5 py-0.5 text-xs">
            00009 → 00011 delivery_notes
          </code>{" "}
          in Supabase, then refresh.
        </div>
      ) : null}

      <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
        <div className="flex flex-wrap items-center justify-between gap-3 border-b border-slate-100 bg-slate-50/80 px-4 py-3.5 sm:px-5">
          <div className="flex items-center gap-2.5">
            <FileText className="h-4 w-4 text-blue-700" />
            <h3 className="text-sm font-semibold text-slate-900">
              Delivery notes
            </h3>
            <span className="rounded-full bg-blue-100 px-2 py-0.5 text-[11px] font-bold text-blue-800">
              {filteredSaved.length}
            </span>
          </div>
          <div className="flex flex-wrap gap-1.5">
            {(
              [
                ["all", "All"],
                ["draft", "Draft"],
                ["confirmed", "Confirmed"],
                ["cancelled", "Cancelled"],
              ] as const
            ).map(([key, label]) => (
              <button
                key={key}
                type="button"
                onClick={() => setStatusFilter(key)}
                className={cn(
                  "rounded-full px-2.5 py-1 text-[11px] font-semibold transition",
                  statusFilter === key
                    ? "bg-blue-600 text-white"
                    : "bg-white text-slate-600 ring-1 ring-slate-200 hover:bg-slate-50",
                )}
              >
                {label}
              </button>
            ))}
          </div>
        </div>

        {filteredSaved.length === 0 ? (
          <div className="px-4 py-16 text-center">
            <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-2xl bg-slate-100 text-slate-400">
              <FileText className="h-6 w-6" />
            </div>
            <p className="mt-3 text-sm font-medium text-slate-600">
              No notes in this filter
            </p>
            <p className="mt-1 text-xs text-slate-400">
              Click &quot;New note&quot; to create one, or change the filter
            </p>
            <Button
              type="button"
              className="mt-4"
              onClick={() => void startNew()}
            >
              <FilePlus2 className="h-4 w-4" />
              New note
            </Button>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[720px] text-left text-sm">
              <thead>
                <tr className="border-b border-slate-100 bg-slate-50/50">
                  <th className="whitespace-nowrap px-4 py-3 text-[11px] font-semibold uppercase tracking-wider text-slate-500 sm:px-5">
                    Note #
                  </th>
                  <th className="whitespace-nowrap px-4 py-3 text-[11px] font-semibold uppercase tracking-wider text-slate-500">
                    Customer
                  </th>
                  <th className="whitespace-nowrap px-4 py-3 text-[11px] font-semibold uppercase tracking-wider text-slate-500">
                    Vehicle / Reg
                  </th>
                  <th className="whitespace-nowrap px-4 py-3 text-[11px] font-semibold uppercase tracking-wider text-slate-500">
                    Date
                  </th>
                  <th className="whitespace-nowrap px-4 py-3 text-[11px] font-semibold uppercase tracking-wider text-slate-500">
                    Status
                  </th>
                  <th className="whitespace-nowrap px-4 py-3 text-right text-[11px] font-semibold uppercase tracking-wider text-slate-500 sm:px-5">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {filteredSaved.map((row) => {
                  const meta = statusMeta(row.delivery_status);
                  const vehicle = [row.car_make, row.car_model_variant]
                    .filter(Boolean)
                    .join(" ")
                    .trim();
                  const active = panelOpen && editingId === row.id;
                  return (
                    <tr
                      key={row.id}
                      className={cn(
                        "cursor-pointer transition hover:bg-blue-50/40",
                        active && "bg-blue-50/70",
                      )}
                      onClick={() => openSaved(row)}
                    >
                      <td className="whitespace-nowrap px-4 py-3.5 font-semibold text-slate-900 sm:px-5">
                        {row.delivery_note_number}
                      </td>
                      <td className="max-w-[180px] truncate px-4 py-3.5 text-slate-700">
                        {row.customer_name || "—"}
                      </td>
                      <td className="px-4 py-3.5 text-slate-600">
                        <div className="max-w-[200px]">
                          <p className="truncate text-sm">
                            {vehicle || "—"}
                          </p>
                          {row.car_registration_number ? (
                            <p className="mt-0.5 truncate text-xs text-slate-400">
                              {row.car_registration_number}
                            </p>
                          ) : null}
                        </div>
                      </td>
                      <td className="whitespace-nowrap px-4 py-3.5 text-slate-600">
                        {formatDate(row.delivery_date)}
                      </td>
                      <td className="px-4 py-3.5">
                        <span
                          className={cn(
                            "inline-flex rounded-full border px-2.5 py-0.5 text-[11px] font-bold",
                            meta.className,
                          )}
                        >
                          {meta.label}
                        </span>
                      </td>
                      <td className="px-4 py-3.5 sm:px-5">
                        <div
                          className="flex items-center justify-end gap-1.5"
                          onClick={(e) => e.stopPropagation()}
                        >
                          <button
                            type="button"
                            className="inline-flex items-center gap-1 rounded-lg border border-blue-200 bg-white px-2.5 py-1.5 text-[11px] font-semibold text-blue-700 hover:bg-blue-50"
                            onClick={() => openSaved(row)}
                          >
                            <Pencil className="h-3 w-3" />
                            Edit
                          </button>
                          <button
                            type="button"
                            className="inline-flex items-center justify-center rounded-lg border border-slate-200 bg-white px-2 py-1.5 text-slate-500 hover:bg-slate-50"
                            title="Preview"
                            onClick={() => void preview(false, rowToForm(row))}
                          >
                            <Eye className="h-3.5 w-3.5" />
                          </button>
                          <button
                            type="button"
                            className="inline-flex items-center justify-center rounded-lg border border-red-100 bg-white px-2 py-1.5 text-red-500 hover:bg-red-50"
                            title="Delete"
                            onClick={() =>
                              void onDelete(row.id, row.delivery_note_number)
                            }
                          >
                            <Trash2 className="h-3.5 w-3.5" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <div className="rounded-2xl border border-blue-200 bg-gradient-to-br from-blue-50 to-white px-4 py-3.5 text-xs leading-relaxed text-slate-600">
        <p className="font-semibold text-blue-900">Workflow</p>
        <p className="mt-1">
          <strong>Save</strong> → draft · <strong>Confirm</strong> → delivered ·{" "}
          <strong>Cancel</strong> → deal cancelled (GST + fees clause still on
          print).
        </p>
      </div>

      <SidePanel
        open={panelOpen}
        onClose={closePanel}
        widthClass="max-w-[560px] sm:max-w-[640px]"
        eyebrow={statusBadge.label}
        title={form.delivery_note_no || "New delivery note"}
        description={form.customer_name || undefined}
        footer={panelFooter}
      >
        <div className="space-y-4">
          {panelMessages}

          <div className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
            <FormField label="Load from invoice (optional)">
              <select
                className={selectNice}
                value={invoiceId}
                onChange={(e) => applyInvoice(e.target.value)}
              >
                <option value="">— Select invoice to auto-fill —</option>
                {invoices.map((inv) => {
                  const name =
                    (inv.customers as { name?: string } | null)?.name ||
                    "Customer";
                  return (
                    <option key={inv.id} value={inv.id}>
                      {inv.invoice_number} · {name} ·{" "}
                      {formatMoney(inv.grand_total)}
                    </option>
                  );
                })}
              </select>
            </FormField>
          </div>

          <div className="grid gap-4">
            <Section
              step="01"
              title="Delivery header"
              subtitle="Note number, date & time"
              icon={FileText}
            >
              <div className="grid gap-3 sm:grid-cols-3">
                <FormField label="Delivery Note No.">
                  <input
                    className={cn(inputClass, "font-semibold")}
                    value={form.delivery_note_no}
                    onChange={(e) =>
                      patch({ delivery_note_no: e.target.value })
                    }
                  />
                </FormField>
                <FormField label="Date">
                  <input
                    className={inputClass}
                    type="date"
                    value={form.delivery_date}
                    onChange={(e) => patch({ delivery_date: e.target.value })}
                  />
                </FormField>
                <FormField label="Delivery Time">
                  <input
                    className={inputClass}
                    value={form.delivery_time}
                    onChange={(e) => patch({ delivery_time: e.target.value })}
                    placeholder="e.g. 04:30 PM"
                  />
                </FormField>
              </div>
            </Section>

            <Section
              step="02"
              title="Customer details"
              subtitle="Buyer identity & contact"
              icon={UserRound}
            >
              <FormField label="Customer Name">
                <input
                  className={inputClass}
                  value={form.customer_name}
                  onChange={(e) => {
                    const v = e.target.value;
                    patch({
                      customer_name: v,
                      declaration_name: form.declaration_name || v,
                      customer_sign_name: form.customer_sign_name || v,
                    });
                  }}
                  placeholder="Full name as on ID"
                />
              </FormField>
              <FormField label="Address">
                <textarea
                  className={cn(areaClass, "min-h-[88px]")}
                  value={form.customer_address}
                  onChange={(e) => patch({ customer_address: e.target.value })}
                  placeholder="Full residential / correspondence address"
                />
              </FormField>
              <div className="grid gap-3 sm:grid-cols-3">
                <FormField label="Mobile No.">
                  <input
                    className={inputClass}
                    value={form.customer_mobile}
                    onChange={(e) =>
                      patch({ customer_mobile: e.target.value })
                    }
                    placeholder="10-digit mobile"
                  />
                </FormField>
                <FormField label="ID Proof">
                  <input
                    className={inputClass}
                    value={form.id_proof}
                    onChange={(e) => patch({ id_proof: e.target.value })}
                    placeholder="Aadhaar / PAN / DL"
                  />
                </FormField>
                <FormField label="ID No.">
                  <input
                    className={inputClass}
                    value={form.id_no}
                    onChange={(e) => patch({ id_no: e.target.value })}
                  />
                </FormField>
              </div>
            </Section>

            <Section
              step="03"
              title="Vehicle details"
              subtitle="Make, registration, chassis & more"
              icon={Car}
            >
              <div className="grid gap-3 sm:grid-cols-2">
                {(
                  [
                    ["car_make", "Make / Brand", "e.g. Hyundai"],
                    ["car_model_variant", "Model / Variant", "e.g. Creta SX"],
                    ["car_registration_number", "Registration No.", "MH-12-XX-0000"],
                    ["car_manufacturing_year", "Year of Manufacture", "2021"],
                    ["car_color", "Colour", "White"],
                    ["car_fuel_type", "Fuel Type", "Petrol / Diesel / CNG"],
                    ["car_chassis_number", "Chassis No.", ""],
                    ["car_engine_number", "Engine No.", ""],
                    ["odometer_km", "Odometer (KM)", "45000"],
                  ] as const
                ).map(([key, label, ph]) => (
                  <FormField key={key} label={label}>
                    <input
                      className={inputClass}
                      value={form[key]}
                      onChange={(e) => patch({ [key]: e.target.value })}
                      placeholder={ph}
                    />
                  </FormField>
                ))}
              </div>
            </Section>

            <Section
              step="04"
              title="Payment details"
              subtitle="Sale price, received & balance"
              icon={IndianRupee}
            >
              <div className="grid gap-3 sm:grid-cols-3">
                <FormField label="Total Vehicle Price (₹)">
                  <input
                    className={inputClass}
                    type="number"
                    min={0}
                    value={form.total_vehicle_price}
                    onChange={(e) =>
                      patch({ total_vehicle_price: e.target.value })
                    }
                    onBlur={syncBalance}
                  />
                </FormField>
                <FormField label="Amount Received (₹)">
                  <input
                    className={inputClass}
                    type="number"
                    min={0}
                    value={form.amount_received}
                    onChange={(e) =>
                      patch({ amount_received: e.target.value })
                    }
                    onBlur={syncBalance}
                  />
                </FormField>
                <FormField label="Balance Amount (₹)">
                  <input
                    className={inputClass}
                    type="number"
                    min={0}
                    value={form.balance_amount}
                    onChange={(e) =>
                      patch({ balance_amount: e.target.value })
                    }
                    placeholder={
                      balancePreview != null
                        ? String(balancePreview)
                        : undefined
                    }
                  />
                </FormField>
              </div>
              {balancePreview != null ? (
                <div className="rounded-xl border border-slate-100 bg-slate-50 px-3.5 py-2.5 text-xs text-slate-600">
                  Calculated balance:{" "}
                  <strong className="text-slate-900">
                    {formatMoney(balancePreview)}
                  </strong>
                </div>
              ) : null}
              <div>
                <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-slate-500">
                  Payment mode
                </p>
                <div className="mt-2.5 flex flex-wrap gap-2">
                  {(
                    [
                      ["cash", "Cash"],
                      ["upi", "UPI"],
                      ["bank_transfer", "Bank Transfer"],
                      ["finance", "Finance"],
                      ["other", "Other"],
                    ] as const
                  ).map(([key, label]) => (
                    <Chip
                      key={key}
                      label={label}
                      checked={form.payment_modes[key]}
                      onChange={(v) =>
                        patch({
                          payment_modes: {
                            ...form.payment_modes,
                            [key]: v,
                          },
                        })
                      }
                    />
                  ))}
                </div>
                {form.payment_modes.other ? (
                  <input
                    className={cn(inputClass, "mt-3")}
                    value={form.payment_other}
                    onChange={(e) =>
                      patch({ payment_other: e.target.value })
                    }
                    placeholder="Other payment mode details"
                  />
                ) : null}
              </div>
            </Section>

            <Section
              step="05"
              title="Documents / items handed over"
              subtitle="Tap to select what was given"
              icon={IdCard}
            >
              <div className="flex flex-wrap gap-2">
                {(
                  [
                    ["rc", "RC"],
                    ["insurance", "Insurance"],
                    ["puc", "PUC"],
                    ["service_records", "Service Records"],
                    ["keys", "Keys"],
                    ["spare_key", "Spare Key"],
                    ["other", "Other"],
                  ] as const
                ).map(([key, label]) => (
                  <Chip
                    key={key}
                    label={label}
                    checked={form.docs[key]}
                    onChange={(v) =>
                      patch({ docs: { ...form.docs, [key]: v } })
                    }
                  />
                ))}
              </div>
              {form.docs.other ? (
                <input
                  className={inputClass}
                  value={form.docs_other}
                  onChange={(e) => patch({ docs_other: e.target.value })}
                  placeholder="Other items / documents"
                />
              ) : null}
            </Section>

            <Section
              step="06"
              title="Deal cancellation charges"
              subtitle="18% GST + paper processing fees — fully editable"
              icon={AlertTriangle}
              tone="amber"
            >
              <label className="flex cursor-pointer items-center gap-3 rounded-xl border border-amber-200 bg-amber-50/60 px-3.5 py-3">
                <input
                  type="checkbox"
                  className="h-4 w-4 rounded border-amber-300 text-amber-600 focus:ring-amber-500"
                  checked={form.cancel_terms_enabled}
                  onChange={(e) =>
                    patch({ cancel_terms_enabled: e.target.checked })
                  }
                />
                <span className="text-sm font-medium text-amber-950">
                  Print cancellation clause on delivery note
                </span>
              </label>
              {form.cancel_terms_enabled ? (
                <>
                  <div className="grid gap-3 sm:grid-cols-2">
                    <FormField label="GST on cancellation (%)">
                      <input
                        className={inputClass}
                        type="number"
                        min={0}
                        max={100}
                        step="0.01"
                        value={form.cancel_gst_percent}
                        onChange={(e) => {
                          const gst = e.target.value;
                          patch({
                            cancel_gst_percent: gst,
                            cancellation_terms: defaultCancellationTerms(
                              gst,
                              form.paper_processing_fee,
                              business.name,
                            ),
                          });
                        }}
                      />
                    </FormField>
                    <FormField label="Paper processing fees (₹)">
                      <input
                        className={inputClass}
                        type="number"
                        min={0}
                        value={form.paper_processing_fee}
                        onChange={(e) => {
                          const fee = e.target.value;
                          patch({
                            paper_processing_fee: fee,
                            cancellation_terms: defaultCancellationTerms(
                              form.cancel_gst_percent,
                              fee,
                              business.name,
                            ),
                          });
                        }}
                        placeholder="Enter fee amount"
                      />
                    </FormField>
                  </div>
                  <FormField
                    label="Cancellation terms (edit full text)"
                    hint="PDF / print pe yahi dikhega"
                  >
                    <textarea
                      className={cn(areaClass, "min-h-[120px] leading-relaxed")}
                      value={form.cancellation_terms}
                      onChange={(e) =>
                        patch({ cancellation_terms: e.target.value })
                      }
                    />
                  </FormField>
                  <button
                    type="button"
                    className="text-xs font-semibold text-amber-800 hover:underline"
                    onClick={() =>
                      patch({
                        cancellation_terms: defaultCancellationTerms(
                          form.cancel_gst_percent || "18",
                          form.paper_processing_fee,
                          business.name,
                        ),
                      })
                    }
                  >
                    Reset terms from GST % + fees
                  </button>
                  {form.delivery_status === "cancelled" ? (
                    <FormField label="Cancel reason (saved)">
                      <input
                        className={inputClass}
                        value={form.cancel_reason}
                        onChange={(e) =>
                          patch({ cancel_reason: e.target.value })
                        }
                        placeholder="Why was the deal cancelled?"
                      />
                    </FormField>
                  ) : null}
                </>
              ) : null}
            </Section>

            <Section
              step="07"
              title="Declaration & signatures"
              subtitle="Names for print signature blocks"
              icon={ClipboardSignature}
            >
              <FormField label="Declaration name (I, ______, confirm…)">
                <input
                  className={inputClass}
                  value={form.declaration_name}
                  onChange={(e) =>
                    patch({ declaration_name: e.target.value })
                  }
                />
              </FormField>
              <div className="grid gap-3 sm:grid-cols-2">
                <FormField label="Customer sign — Name">
                  <input
                    className={inputClass}
                    value={form.customer_sign_name}
                    onChange={(e) =>
                      patch({ customer_sign_name: e.target.value })
                    }
                  />
                </FormField>
                <FormField label="Customer — Date & Time">
                  <input
                    className={inputClass}
                    value={form.customer_sign_datetime}
                    onChange={(e) =>
                      patch({ customer_sign_datetime: e.target.value })
                    }
                    placeholder="Uses delivery date/time if blank"
                  />
                </FormField>
                <FormField label="Authorized signatory — Name">
                  <input
                    className={inputClass}
                    value={form.auth_sign_name}
                    onChange={(e) =>
                      patch({ auth_sign_name: e.target.value })
                    }
                  />
                </FormField>
                <FormField label="Vehicle Handed Over By">
                  <input
                    className={inputClass}
                    value={form.handed_over_by}
                    onChange={(e) =>
                      patch({ handed_over_by: e.target.value })
                    }
                  />
                </FormField>
              </div>
            </Section>
          </div>
        </div>
      </SidePanel>
    </div>
  );
}
