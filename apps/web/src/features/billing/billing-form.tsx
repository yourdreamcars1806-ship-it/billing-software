"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { DEMO_MODE, findDemoProductByBarcode } from "@/lib/demo/data";
import { createInvoice } from "@/lib/create-invoice";
import { Button } from "@/components/ui/button";
import { LoadingOverlay } from "@/components/ui/spinner";
import { formatMoney } from "@/lib/utils";
import { discountFromOffer } from "@/lib/offer";
import type { Business, PaymentMethod, ProductVariant } from "@/types";
import { PAYMENT_METHODS, businessFeatures } from "@/types";

interface LineDraft {
  key: string;
  description: string;
  quantity: number;
  unit_price: number;
  discount_amount: number;
  tax_rate: number;
  offer_percent?: number;
  product_variant_id?: string;
  barcode?: string;
  size?: string;
  color?: string;
}

const emptyLine = (): LineDraft => ({
  key: crypto.randomUUID(),
  description: "",
  quantity: 1,
  unit_price: 0,
  discount_amount: 0,
  tax_rate: 0,
});

type ScannedPreview = {
  title: string;
  barcode: string;
  size?: string;
  color?: string;
  price: number;
};

export function BillingForm({ business }: { business: Business }) {
  const router = useRouter();
  const features = businessFeatures(business.business_type);
  const isCar = business.business_type === "car";
  const [customerName, setCustomerName] = useState("");
  const [customerMobile, setCustomerMobile] = useState("");
  const [lines, setLines] = useState<LineDraft[]>([emptyLine()]);
  const [discount, setDiscount] = useState(0);
  const [additional, setAdditional] = useState(0);
  const [paymentAmount, setPaymentAmount] = useState(0);
  const [paymentMethod, setPaymentMethod] = useState<PaymentMethod>("cash");
  const [notes, setNotes] = useState("");
  const [barcodeInput, setBarcodeInput] = useState("");
  const [scanning, setScanning] = useState(false);
  const [lastScanned, setLastScanned] = useState<ScannedPreview | null>(null);
  const [car, setCar] = useState({
    car_make: "",
    car_model: "",
    car_variant: "",
    car_registration_number: "",
    car_chassis_number: "",
    car_engine_number: "",
    car_manufacturing_year: "",
    car_color: "",
    car_fuel_type: "",
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const totals = useMemo(() => {
    let subtotal = 0;
    let tax = 0;
    for (const line of lines) {
      const taxable = Math.max(
        line.quantity * line.unit_price - line.discount_amount,
        0,
      );
      subtotal += line.quantity * line.unit_price;
      tax += (taxable * line.tax_rate) / 100;
    }
    const itemsNet = lines.reduce((sum, line) => {
      const taxable = Math.max(
        line.quantity * line.unit_price - line.discount_amount,
        0,
      );
      return sum + taxable + (taxable * line.tax_rate) / 100;
    }, 0);
    const grand = Math.max(itemsNet - discount + additional, 0);
    return {
      subtotal: round2(subtotal),
      tax: round2(tax),
      grand: round2(grand),
    };
  }, [lines, discount, additional]);

  function updateLine(key: string, patch: Partial<LineDraft>) {
    setLines((prev) =>
      prev.map((l) => {
        if (l.key !== key) return l;
        const next = { ...l, ...patch };
        if (
          next.offer_percent &&
          next.offer_percent > 0 &&
          ("quantity" in patch || "unit_price" in patch) &&
          !("discount_amount" in patch)
        ) {
          next.discount_amount = discountFromOffer(
            next.quantity,
            next.unit_price,
            next.offer_percent,
          );
        }
        return next;
      }),
    );
  }

  async function scanBarcode() {
    const code = barcodeInput.trim();
    if (!code || !features.barcode || scanning) return;
    setError(null);
    setScanning(true);

    try {
      if (DEMO_MODE) {
        const product = findDemoProductByBarcode(business.id, code);
        if (!product) {
          setLastScanned(null);
          setError(
            `No product found for barcode ${code}. Add it under Products & Barcode.`,
          );
          return;
        }
        const title = [product.brand, product.name].filter(Boolean).join(" · ");
        const offer = Number(product.offer_percent || 0);
        const price = Number(product.selling_price);
        const disc = discountFromOffer(1, price, offer);
        setLines((prev) => [
          ...prev.filter((l) => l.description || l.unit_price),
          {
            key: crypto.randomUUID(),
            description: title,
            quantity: 1,
            unit_price: price,
            discount_amount: disc,
            tax_rate: product.tax_rate,
            offer_percent: offer,
            product_variant_id: product.id,
            barcode: product.barcode,
            size: product.size,
            color: product.color,
          },
        ]);
        setLastScanned({
          title,
          barcode: product.barcode,
          size: product.size,
          color: product.color,
          price,
        });
        setSuccess(
          offer > 0
            ? `Added ${title} · ${offer}% off · Disc ₹${disc.toLocaleString("en-IN")}`
            : `Added ${title} · Size ${product.size} · Color ${product.color} · ₹${price.toLocaleString("en-IN")}`,
        );
        setBarcodeInput("");
        return;
      }

      const supabase = createClient();
      const { data, error: qError } = await supabase
        .from("product_variants")
        .select("*, products(name, brand)")
        .eq("business_id", business.id)
        .ilike("barcode", code)
        .eq("is_active", true)
        .maybeSingle();

      if (qError || !data) {
        setLastScanned(null);
        setError(`No product found for barcode ${code}`);
        return;
      }

      const variant = data as ProductVariant;
      const name = variant.products?.name || "Item";
      const brand = variant.products?.brand;
      const title = [brand, name].filter(Boolean).join(" · ");
      const price = Number(variant.selling_price);
      const offer = Number(variant.offer_percent || 0);
      const disc = discountFromOffer(1, price, offer);
      const barcodeValue = (variant.barcode || code).trim();

      setLines((prev) => [
        ...prev.filter((l) => l.description || l.unit_price),
        {
          key: crypto.randomUUID(),
          description: title,
          quantity: 1,
          unit_price: price,
          discount_amount: disc,
          tax_rate: Number(variant.tax_rate || 0),
          offer_percent: offer,
          product_variant_id: variant.id,
          barcode: barcodeValue,
          size: variant.size || undefined,
          color: variant.color || undefined,
        },
      ]);
      setLastScanned({
        title,
        barcode: barcodeValue,
        size: variant.size || undefined,
        color: variant.color || undefined,
        price,
      });
      setSuccess(
        offer > 0
          ? `Added ${title} · ${offer}% off · Disc ₹${disc.toLocaleString("en-IN")}`
          : `Added ${title}${variant.size ? ` · Size ${variant.size}` : ""}${variant.color ? ` · Color ${variant.color}` : ""} · ₹${price.toLocaleString("en-IN")}`,
      );
      setBarcodeInput("");
    } finally {
      setScanning(false);
    }
  }

  async function submit() {
    setError(null);
    setSuccess(null);
    const validLines = lines.filter((l) => l.description && l.quantity > 0);
    if (!validLines.length) {
      setError("Add at least one line item");
      return;
    }

    setSaving(true);

    if (DEMO_MODE) {
      setSaving(false);
      setSuccess(
        `Demo invoice created - ₹${totals.grand.toLocaleString("en-IN")} (not saved to DB)`,
      );
      return;
    }

    try {
      const result = await createInvoice({
        business_id: business.id,
        customer_name: customerName.trim() || undefined,
        customer_mobile: customerMobile.trim() || undefined,
        items: validLines.map((l) => ({
          description: l.description,
          quantity: l.quantity,
          unit_price: l.unit_price,
          discount_amount: l.discount_amount,
          tax_rate: l.tax_rate,
          product_variant_id: l.product_variant_id,
          barcode: l.barcode,
          size: l.size,
          color: l.color,
        })),
        discount_amount: discount,
        additional_charges: additional,
        notes: notes || undefined,
        auto_whatsapp: true,
        ...(features.carFields
          ? {
              ...car,
              car_manufacturing_year: car.car_manufacturing_year
                ? Number(car.car_manufacturing_year)
                : undefined,
            }
          : {}),
        initial_payment:
          paymentAmount > 0
            ? {
                amount: paymentAmount,
                payment_method: paymentMethod,
              }
            : undefined,
      });

      if (!result.success) {
        setError(result.error || "Failed to create invoice");
        return;
      }

      const invNo =
        (result.invoice?.invoice_number as string | undefined) || "";
      let waNote = "";
      if (result.whatsapp?.sent) waNote = " · WhatsApp sent";
      else if (result.whatsapp?.error)
        waNote = ` · WhatsApp failed: ${result.whatsapp.error}`;
      else if (result.whatsapp?.skipped === "no customer mobile")
        waNote = " · WhatsApp skipped (no mobile) - print from Invoices";
      else if (result.whatsapp?.skipped)
        waNote = ` · WhatsApp skipped (${result.whatsapp.skipped})`;

      setSuccess(`Invoice ${invNo} created${waNote}`);
      router.push(`/b/${business.slug}/invoices`);
    } catch (e) {
      setError(
        e instanceof Error
          ? e.message
          : "Failed to create invoice. Check login / network.",
      );
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="space-y-5">
      <LoadingOverlay
        show={saving || scanning}
        label={scanning ? "Looking up barcode…" : "Creating invoice…"}
      />
      <div className="border-b border-slate-200 pb-4">
        <h1 className="text-xl font-semibold tracking-tight text-slate-900">
          Create Invoice
        </h1>
        <p className="mt-0.5 text-sm text-slate-500">
          Fast billing for {business.name}
        </p>
      </div>

      {error && (
        <div className="border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
          {error}
        </div>
      )}
      {success && (
        <div className="border border-emerald-200 bg-emerald-50 px-3 py-2 text-sm text-emerald-800">
          {success}
        </div>
      )}

      <div className="grid gap-5 lg:grid-cols-[1fr_300px]">
        <div className="space-y-5 border border-slate-200 bg-white p-4 sm:p-5">
          <div className="grid gap-3 sm:grid-cols-2">
            <label className="block">
              <span className="text-[11px] font-semibold uppercase tracking-[0.12em] text-slate-500">
                Customer name
              </span>
              <input
                type="text"
                className="mt-1.5 h-10 w-full border border-slate-200 bg-white px-3 text-sm outline-none focus:border-brand focus:ring-2 focus:ring-brand/15"
                placeholder="Type customer name"
                value={customerName}
                onChange={(e) => setCustomerName(e.target.value)}
                autoComplete="name"
              />
            </label>
            <label className="block">
              <span className="text-[11px] font-semibold uppercase tracking-[0.12em] text-slate-500">
                WhatsApp / Mobile
              </span>
              <input
                type="tel"
                inputMode="numeric"
                className="mt-1.5 h-10 w-full border border-slate-200 bg-white px-3 text-sm outline-none focus:border-brand focus:ring-2 focus:ring-brand/15"
                placeholder="10-digit mobile (optional)"
                value={customerMobile}
                onChange={(e) => setCustomerMobile(e.target.value)}
                autoComplete="tel"
              />
              <p className="mt-1 text-[11px] text-slate-400">
                Number ho to WhatsApp auto; nahi ho to bill phir bhi banega - print kar sakte ho
              </p>
            </label>
          </div>

          {features.barcode && (
            <div className="space-y-3 border border-slate-200 bg-white p-4">
              <div className="flex items-center justify-between gap-2">
                <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-slate-500">
                  Scan barcode
                </p>
                <span className="text-[10px] font-medium text-slate-400">
                  Code 128 · Enter to add
                </span>
              </div>
              <div className="flex flex-col gap-2 sm:flex-row sm:items-stretch">
                <input
                  className="h-11 flex-1 border border-slate-200 bg-slate-50 px-3 font-mono text-sm outline-none transition focus:border-brand focus:bg-white focus:ring-2 focus:ring-brand/15"
                  placeholder="Scan product barcode…"
                  value={barcodeInput}
                  onChange={(e) => setBarcodeInput(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === "Enter") {
                      e.preventDefault();
                      scanBarcode();
                    }
                  }}
                  autoComplete="off"
                />
                <Button
                  type="button"
                  onClick={scanBarcode}
                  loading={scanning}
                  className="sm:min-w-[120px]"
                >
                  Add item
                </Button>
              </div>
              {lastScanned ? (
                <div className="flex flex-wrap items-center justify-between gap-3 border border-emerald-200 bg-emerald-50/50 px-3 py-2.5">
                  <div className="min-w-0">
                    <p className="truncate text-sm font-semibold text-slate-900">
                      {lastScanned.title}
                    </p>
                    <p className="mt-0.5 text-xs text-slate-500">
                      Size {lastScanned.size || "-"} · Color{" "}
                      {lastScanned.color || "-"} ·{" "}
                      <span className="font-mono">{lastScanned.barcode}</span>
                    </p>
                  </div>
                  <p className="shrink-0 text-lg font-bold tabular-nums text-brand-ink">
                    {formatMoney(lastScanned.price)}
                  </p>
                </div>
              ) : null}
            </div>
          )}

          {features.carFields && (
            <div className="space-y-3 border-t border-slate-100 pt-4">
              <p className="text-xs font-semibold uppercase tracking-[0.12em] text-slate-400">
                Vehicle details
              </p>
              <div className="grid gap-3 sm:grid-cols-2">
                {(
                  [
                    ["car_make", "Make / Brand"],
                    ["car_model", "Model"],
                    ["car_variant", "Variant"],
                    ["car_registration_number", "Registration No."],
                    ["car_chassis_number", "Chassis No."],
                    ["car_engine_number", "Engine No."],
                    ["car_manufacturing_year", "Year"],
                    ["car_color", "Color"],
                    ["car_fuel_type", "Fuel Type"],
                  ] as const
                ).map(([key, label]) => (
                  <label key={key} className="block">
                    <span className="text-[11px] font-semibold uppercase tracking-[0.12em] text-slate-500">
                      {label}
                    </span>
                    <input
                      className="mt-1.5 h-10 w-full border border-slate-200 bg-white px-3 text-sm outline-none focus:border-brand focus:ring-2 focus:ring-brand/15"
                      value={car[key]}
                      onChange={(e) =>
                        setCar((prev) => ({ ...prev, [key]: e.target.value }))
                      }
                    />
                  </label>
                ))}
              </div>
            </div>
          )}

          <div className="space-y-3 border-t border-slate-100 pt-4">
            <div className="flex items-center justify-between">
              <p className="text-xs font-semibold uppercase tracking-[0.12em] text-slate-400">
                Line items
              </p>
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => setLines((prev) => [...prev, emptyLine()])}
              >
                Add line
              </Button>
            </div>

            <div className="overflow-x-auto border border-slate-200">
              <table className="min-w-full border-collapse text-sm">
                <thead>
                  <tr className="border-b border-slate-200 bg-slate-50/80">
                    <th className="px-2 py-2 text-left text-[11px] font-semibold uppercase tracking-wider text-slate-500">
                      Description
                    </th>
                    {features.barcode ? (
                      <>
                        <th className="px-2 py-2 text-left text-[11px] font-semibold uppercase tracking-wider text-slate-500">
                          Size
                        </th>
                        <th className="px-2 py-2 text-left text-[11px] font-semibold uppercase tracking-wider text-slate-500">
                          Color
                        </th>
                      </>
                    ) : null}
                    <th className="px-2 py-2 text-left text-[11px] font-semibold uppercase tracking-wider text-slate-500">
                      Qty
                    </th>
                    <th className="px-2 py-2 text-left text-[11px] font-semibold uppercase tracking-wider text-slate-500">
                      Price
                    </th>
                    <th className="px-2 py-2 text-left text-[11px] font-semibold uppercase tracking-wider text-slate-500">
                      Disc
                    </th>
                    <th className="px-2 py-2 text-left text-[11px] font-semibold uppercase tracking-wider text-slate-500">
                      Tax %
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {lines.map((line) => (
                    <tr key={line.key} className="border-b border-slate-100">
                      <td className="p-1.5">
                        <div>
                          <input
                            className="h-9 w-full min-w-[140px] border border-transparent bg-transparent px-2 text-sm outline-none focus:border-brand"
                            placeholder="Description"
                            value={line.description}
                            onChange={(e) =>
                              updateLine(line.key, {
                                description: e.target.value,
                              })
                            }
                          />
                          {line.barcode ? (
                            <p className="px-2 font-mono text-[11px] text-slate-400">
                              {line.barcode}
                            </p>
                          ) : null}
                        </div>
                      </td>
                      {features.barcode ? (
                        <>
                          <td className="p-1.5">
                            <span className="inline-flex min-w-[52px] items-center justify-center rounded-md border border-slate-200 bg-slate-50 px-2 py-1.5 text-sm font-semibold text-slate-800">
                              {line.size || "-"}
                            </span>
                          </td>
                          <td className="p-1.5">
                            <span className="inline-flex min-w-[64px] items-center justify-center rounded-md border border-slate-200 bg-slate-50 px-2 py-1.5 text-sm font-semibold text-slate-800">
                              {line.color || "-"}
                            </span>
                          </td>
                        </>
                      ) : null}
                      <td className="p-1.5">
                        <input
                          className="h-9 w-20 border border-transparent bg-transparent px-2 text-sm outline-none focus:border-brand"
                          type="number"
                          min={0}
                          step="0.001"
                          value={line.quantity}
                          onChange={(e) =>
                            updateLine(line.key, {
                              quantity: Number(e.target.value),
                            })
                          }
                        />
                      </td>
                      <td className="p-1.5">
                        <input
                          className="h-9 w-24 border border-transparent bg-transparent px-2 text-sm font-semibold text-brand-ink outline-none focus:border-brand"
                          type="number"
                          min={0}
                          step="0.01"
                          value={line.unit_price}
                          onChange={(e) =>
                            updateLine(line.key, {
                              unit_price: Number(e.target.value),
                            })
                          }
                        />
                      </td>
                      <td className="p-1.5">
                        <input
                          className="h-9 w-20 border border-transparent bg-transparent px-2 text-sm outline-none focus:border-brand"
                          type="number"
                          min={0}
                          step="0.01"
                          value={line.discount_amount}
                          onChange={(e) =>
                            updateLine(line.key, {
                              discount_amount: Number(e.target.value),
                            })
                          }
                        />
                      </td>
                      <td className="p-1.5">
                        <input
                          className="h-9 w-20 border border-transparent bg-transparent px-2 text-sm outline-none focus:border-brand"
                          type="number"
                          min={0}
                          step="0.01"
                          value={line.tax_rate}
                          onChange={(e) =>
                            updateLine(line.key, {
                              tax_rate: Number(e.target.value),
                            })
                          }
                        />
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>

          <label className="block">
            <span className="text-[11px] font-semibold uppercase tracking-[0.12em] text-slate-500">
              Notes
            </span>
            <input
              className="mt-1.5 h-10 w-full border border-slate-200 bg-white px-3 text-sm outline-none focus:border-brand focus:ring-2 focus:ring-brand/15"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
            />
          </label>
        </div>

        <aside className="h-fit space-y-4 border border-slate-200 bg-white p-4 sm:p-5">
          <p className="text-xs font-semibold uppercase tracking-[0.12em] text-slate-400">
            Totals
          </p>
          <Row label="Subtotal" value={formatMoney(totals.subtotal)} />
          <Row label="Tax" value={formatMoney(totals.tax)} />
          <label className="block">
            <span className="text-[11px] font-semibold uppercase tracking-[0.12em] text-slate-500">
              Invoice discount
            </span>
            <input
              className="mt-1.5 h-10 w-full border border-slate-200 px-3 text-sm outline-none focus:border-brand focus:ring-2 focus:ring-brand/15"
              type="number"
              min={0}
              value={discount}
              onChange={(e) => setDiscount(Number(e.target.value))}
            />
          </label>
          <label className="block">
            <span className="text-[11px] font-semibold uppercase tracking-[0.12em] text-slate-500">
              Additional charges
            </span>
            <input
              className="mt-1.5 h-10 w-full border border-slate-200 px-3 text-sm outline-none focus:border-brand focus:ring-2 focus:ring-brand/15"
              type="number"
              min={0}
              value={additional}
              onChange={(e) => setAdditional(Number(e.target.value))}
            />
          </label>
          <div
            className={
              isCar
                ? "border border-blue-200 bg-blue-50 px-3 py-3"
                : "border border-brand-border bg-brand-soft px-3 py-3"
            }
          >
            <p
              className={
                isCar
                  ? "text-[11px] font-semibold uppercase tracking-wider text-blue-800"
                  : "text-[11px] font-semibold uppercase tracking-wider text-brand-ink"
              }
            >
              Grand total (Sales)
            </p>
            <p className="mt-1 text-2xl font-bold tabular-nums text-slate-900">
              {formatMoney(totals.grand)}
            </p>
          </div>

          <label className="block">
            <span className="text-[11px] font-semibold uppercase tracking-[0.12em] text-slate-500">
              {isCar ? "Token / payment now" : "Payment received now"}
            </span>
            <input
              className="mt-1.5 h-10 w-full border border-slate-200 px-3 text-sm outline-none focus:border-brand focus:ring-2 focus:ring-brand/15"
              type="number"
              min={0}
              value={paymentAmount}
              onChange={(e) => setPaymentAmount(Number(e.target.value))}
            />
          </label>
          <label className="block">
            <span className="text-[11px] font-semibold uppercase tracking-[0.12em] text-slate-500">
              {isCar ? "Token method" : "Payment method"}
            </span>
            <select
              className="mt-1.5 h-10 w-full border border-slate-200 px-3 text-sm outline-none focus:border-brand focus:ring-2 focus:ring-brand/15"
              value={paymentMethod}
              onChange={(e) =>
                setPaymentMethod(e.target.value as PaymentMethod)
              }
            >
              {PAYMENT_METHODS.map((m) => (
                <option key={m.value} value={m.value}>
                  {m.label}
                </option>
              ))}
            </select>
          </label>

          <Button
            className="w-full"
            size="lg"
            onClick={submit}
            loading={saving}
          >
            Create Invoice
          </Button>
          <p className="text-center text-[11px] text-slate-500">
            Mobile daloge to WhatsApp auto trigger; warna bill create + print normal
          </p>
        </aside>
      </div>
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between text-sm">
      <span className="text-slate-600">{label}</span>
      <span className="font-medium tabular-nums">{value}</span>
    </div>
  );
}

function round2(n: number) {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}
