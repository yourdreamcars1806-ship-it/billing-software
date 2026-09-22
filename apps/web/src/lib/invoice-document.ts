"use client";

import type { Business, Invoice } from "@/types";
import { formatDate, formatMoney } from "@/lib/utils";
import { paymentStatusLabel } from "@/lib/payment-status";
import { BARCODE_FORMAT } from "@/lib/barcode";

export interface InvoiceLineItem {
  description: string;
  quantity: number;
  unit_price: number;
  discount_amount?: number;
  tax_rate?: number;
  tax_amount?: number;
  line_total?: number;
  size?: string | null;
  color?: string | null;
  barcode?: string | null;
  product_variant_id?: string | null;
}

export type InvoiceWithItems = Invoice & {
  invoice_items?: InvoiceLineItem[];
  payments?: {
    amount: number;
    payment_date: string;
    payment_method: string;
    reference_number?: string | null;
  }[];
};

function money(n: number) {
  return formatMoney(n);
}

/** Resolve logo path to absolute URL for print/download windows */
export function resolveLogoUrl(logoUrl: string | null | undefined): string | null {
  if (!logoUrl) return null;
  if (
    logoUrl.startsWith("http://") ||
    logoUrl.startsWith("https://") ||
    logoUrl.startsWith("data:")
  ) {
    return logoUrl;
  }
  if (typeof window === "undefined") return logoUrl;
  const path = logoUrl.startsWith("/") ? logoUrl : `/${logoUrl}`;
  return `${window.location.origin}${path}`;
}

/** Business logo with built-in defaults for demo brands */
export function businessLogoUrl(business: Business): string | null {
  if (business.logo_url) {
    if (business.logo_url.includes("drape-and-dream-logo") && !business.logo_url.includes("?")) {
      return `${business.logo_url}?v=pad4`;
    }
    return business.logo_url;
  }
  if (business.slug === "drape-and-dream") {
    return "/images/drape-and-dream-logo.png?v=pad4";
  }
  if (business.slug === "your-dream-cars") {
    return "/images/your-dream-cars-logo.png";
  }
  return null;
}

/** Embed logo as data-URL with side padding so D / M never clip on 80mm slips */
async function logoToDataUrl(src: string | null): Promise<string | null> {
  if (!src) return null;
  try {
    const url = src.startsWith("data:")
      ? src
      : resolveLogoUrl(src) || src;
    const isRemote = /^https?:\/\//i.test(url);

    const img = await new Promise<HTMLImageElement>((resolve, reject) => {
      const el = new Image();
      // Only set CORS for remote hosts — same-origin + anonymous can taint canvas
      if (isRemote) el.crossOrigin = "anonymous";
      el.onload = () => resolve(el);
      el.onerror = () => reject(new Error("logo load failed"));
      el.src = url;
    });

    // Side padding keeps D/M safe; keep top/bottom tight so barcode sits close
    const padX = Math.max(16, Math.round(img.width * 0.1));
    const padTop = Math.max(8, Math.round(img.height * 0.04));
    const padBottom = Math.max(4, Math.round(img.height * 0.02));
    const canvas = document.createElement("canvas");
    canvas.width = img.width + padX * 2;
    canvas.height = img.height + padTop + padBottom;
    const ctx = canvas.getContext("2d");
    if (!ctx) return url;
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.drawImage(img, padX, padTop);
    return canvas.toDataURL("image/png");
  } catch {
    return resolveLogoUrl(src);
  }
}

export function buildInvoiceHtml(
  business: Business,
  invoice: InvoiceWithItems,
  options?: { logoUrl?: string | null },
): string {
  const customer = invoice.customers as
    | { name?: string; mobile?: string; email?: string; address?: string }
    | null
    | undefined;
  const items = invoice.invoice_items || [];
  const isCar = business.business_type === "car";
  const logoUrl = options?.logoUrl ?? resolveLogoUrl(business.logo_url);
  const status = (invoice.payment_status || "pending").toLowerCase();
  const statusLabel = paymentStatusLabel(
    invoice.payment_status,
    business.business_type,
  );
  const statusBadgeHtml = `${
    status === "paid" ? `<span class="tick"></span>` : ""
  }${escapeHtml(statusLabel)}`;
  const theme = isCar
    ? {
        headerBg: "#1a73e8",
        accent: "#1a73e8",
        accentSoft: "#eef5ff",
        accentBorder: "#c5dbf8",
      }
    : {
        /* Drape & Dream logo gold */
        headerBg: "#c89018",
        accent: "#a87000",
        accentSoft: "#fbf7eb",
        accentBorder: "#e5c76b",
      };

  const itemRows =
    items.length > 0
      ? items
          .map(
            (item, i) => `
        <tr>
          <td class="c-no">${i + 1}</td>
          <td class="c-item">
            <div class="item-name">${escapeHtml(item.description)}</div>
            ${item.barcode ? `<div class="item-meta mono">${escapeHtml(item.barcode)}</div>` : ""}
          </td>
          ${
            !isCar
              ? `<td class="c-size">${escapeHtml(item.size || "-")}</td>
          <td class="c-color">${escapeHtml(item.color || "-")}</td>`
              : ""
          }
          <td class="c-qty">${item.quantity}</td>
          <td class="c-price">${money(item.unit_price)}</td>
          <td class="c-disc">${money(item.discount_amount || 0)}</td>
          <td class="c-tax">${item.tax_rate || 0}%</td>
          <td class="c-amt">${money(item.line_total ?? item.quantity * item.unit_price)}</td>
        </tr>`,
          )
          .join("")
      : `<tr><td colspan="${isCar ? 7 : 9}" class="empty">No line items</td></tr>`;

  const carBlock = isCar
    ? `
    <section class="panel">
      <div class="panel-title">Vehicle details</div>
      <div class="vehicle-grid">
        <div class="kv"><span>Make / Model</span><strong>${escapeHtml([invoice.car_make, invoice.car_model, invoice.car_variant].filter(Boolean).join(" · ") || "-")}</strong></div>
        <div class="kv"><span>Registration</span><strong>${escapeHtml(invoice.car_registration_number || "-")}</strong></div>
        <div class="kv"><span>Color</span><strong>${escapeHtml(invoice.car_color || "-")}</strong></div>
        <div class="kv"><span>Fuel</span><strong>${escapeHtml(invoice.car_fuel_type || "-")}</strong></div>
        <div class="kv"><span>Chassis</span><strong class="mono">${escapeHtml(invoice.car_chassis_number || "-")}</strong></div>
        <div class="kv"><span>Engine</span><strong class="mono">${escapeHtml(invoice.car_engine_number || "-")}</strong></div>
        <div class="kv"><span>Year</span><strong>${invoice.car_manufacturing_year || "-"}</strong></div>
      </div>
    </section>`
    : "";

  const logoBlock = logoUrl
    ? `<div class="logo-wrap"><img class="logo" src="${escapeHtml(logoUrl)}" alt="${escapeHtml(business.name)}" /></div>`
    : `<div class="logo-wrap logo-fallback">${escapeHtml(business.name.slice(0, 2).toUpperCase())}</div>`;

  return `<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <title>${escapeHtml(invoice.invoice_number)}</title>
  <style>
    * { box-sizing: border-box; }
    html, body {
      margin: 0; padding: 0; background: #fff;
      overflow: visible !important;
    }
    body {
      font-family: Arial, Helvetica, sans-serif;
      color: #111827;
      padding: 22px;
      width: 760px;
      line-height: 1.45;
      background: #ffffff;
    }
    .sheet {
      width: 100%;
      overflow: visible;
      background: #ffffff;
    }

    .header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 18px;
      padding: 16px 18px;
      border-radius: 12px;
      background: ${theme.headerBg};
      color: #ffffff;
      -webkit-print-color-adjust: exact;
      print-color-adjust: exact;
    }
    .brand {
      display: flex;
      align-items: flex-start;
      gap: 12px;
      flex: 1 1 auto;
      min-width: 0;
    }
    .logo-wrap {
      width: 96px; height: 96px; flex: 0 0 96px;
      border-radius: 10px; background: #ffffff;
      display: flex; align-items: center; justify-content: center;
      overflow: hidden;
      padding: 12px;
      box-sizing: border-box;
    }
    .logo {
      width: 100%; height: 100%;
      object-fit: contain;
      object-position: center;
      display: block;
    }
    .logo-fallback {
      font-size: 15px; font-weight: 800; color: ${theme.accent};
    }
    .brand-text { flex: 1 1 auto; min-width: 0; }
    .brand-text h1 {
      margin: 0 0 6px; font-size: 19px; font-weight: 700;
      line-height: 1.25; color: #ffffff; word-wrap: break-word;
    }
    .brand-text p {
      margin: 0 0 3px; font-size: 11.5px; line-height: 1.45;
      color: #ffffff; opacity: 0.95; word-wrap: break-word;
      white-space: normal;
    }
    .header-right {
      flex: 0 0 176px;
      width: 176px;
      text-align: center;
      border-left: 1px solid rgba(255,255,255,0.35);
      padding: 2px 0 2px 14px;
      display: flex;
      flex-direction: column;
      justify-content: center;
      align-items: center;
      gap: 6px;
      overflow: visible;
    }
    .eyebrow {
      width: 100%;
      font-size: 10px; font-weight: 700; letter-spacing: 0.12em;
      text-transform: uppercase; color: #ffffff; opacity: 0.9;
    }
    .inv-no {
      width: 100%;
      font-size: 17px; font-weight: 700; color: #ffffff;
      white-space: nowrap; line-height: 1.2;
    }
    .inv-date {
      width: 100%;
      font-size: 12px; color: #ffffff; opacity: 0.95;
      white-space: nowrap;
    }
    .badge {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 6px;
      width: auto;
      min-width: 120px;
      max-width: 100%;
      margin-top: 2px;
      padding: 8px 12px;
      border-radius: 8px;
      font-size: 10px; font-weight: 800; text-transform: uppercase;
      letter-spacing: 0.04em; color: #ffffff;
      border: none;
      text-align: center;
      line-height: 1;
      white-space: nowrap;
      overflow: hidden;
      box-sizing: border-box;
      -webkit-print-color-adjust: exact;
      print-color-adjust: exact;
    }
    .badge .tick {
      display: inline-block;
      width: 13px;
      height: 13px;
      border-radius: 50%;
      background: #ffffff;
      flex-shrink: 0;
      position: relative;
      overflow: hidden;
      vertical-align: middle;
    }
    .badge .tick::after {
      content: "";
      position: absolute;
      left: 4px;
      top: 1.5px;
      width: 3.5px;
      height: 7px;
      border: solid #059669;
      border-width: 0 1.8px 1.8px 0;
      transform: rotate(45deg);
      box-sizing: border-box;
    }
    .badge.paid { background: #059669; }
    .badge.partial { background: #c89018; }
    .badge.pending { background: #dc2626; }

    .meta {
      display: flex; gap: 12px; margin: 16px 0 14px;
    }
    .card {
      flex: 1 1 0;
      border: 1px solid #e5e7eb;
      border-radius: 10px;
      padding: 14px;
      overflow: visible;
      background: #ffffff;
    }
    .card-title {
      font-size: 10px; font-weight: 700; text-transform: uppercase;
      letter-spacing: 0.1em; color: #6b7280; margin: 0 0 8px;
    }
    .card .name {
      margin: 0 0 5px; font-size: 14px; font-weight: 700; color: #111827;
      word-wrap: break-word;
    }
    .card p {
      margin: 0 0 3px; font-size: 12px; color: #374151;
      line-height: 1.45; word-wrap: break-word;
    }
    .sum-row {
      display: flex; justify-content: space-between;
      gap: 8px; font-size: 12px; color: #4b5563; margin-bottom: 6px;
    }
    .sum-row b { color: #111827; white-space: nowrap; font-size: 12.5px; }

    .panel {
      border: 1px solid ${theme.accentBorder};
      background: ${theme.accentSoft};
      border-radius: 8px;
      padding: 12px;
      margin-bottom: 12px;
      overflow: visible;
      -webkit-print-color-adjust: exact;
      print-color-adjust: exact;
    }
    .panel-title {
      font-size: 10px; font-weight: 700; text-transform: uppercase;
      letter-spacing: 0.08em; color: ${theme.accent}; margin: 0 0 10px;
    }
    .vehicle-grid {
      display: flex; flex-wrap: wrap; gap: 10px 0;
    }
    .kv {
      width: 33.33%;
      padding-right: 10px;
      box-sizing: border-box;
    }
    .kv span {
      display: block; font-size: 9px; text-transform: uppercase;
      letter-spacing: 0.05em; color: #64748b; margin-bottom: 2px;
    }
    .kv strong {
      display: block; font-size: 11px; font-weight: 700; color: #0f172a;
      word-break: break-word; white-space: normal;
    }
    .mono { font-family: Consolas, monospace; font-size: 10px; }

    .table-wrap {
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      overflow: visible;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      table-layout: fixed;
    }
    th, td {
      padding: 8px 6px;
      font-size: 11px;
      vertical-align: top;
      word-wrap: break-word;
      overflow-wrap: anywhere;
    }
    thead th {
      background: #f8fafc;
      font-size: 9px; font-weight: 700; text-transform: uppercase;
      letter-spacing: 0.05em; color: #64748b;
      border-bottom: 1px solid #e2e8f0;
      text-align: left;
      -webkit-print-color-adjust: exact;
      print-color-adjust: exact;
    }
    tbody td { border-bottom: 1px solid #f1f5f9; color: #1e293b; }
    tbody tr:last-child td { border-bottom: none; }
    .c-no { width: 28px; color: #94a3b8; }
    .c-item { width: auto; }
    .c-size { width: 52px; font-weight: 700; }
    .c-color { width: 72px; font-weight: 700; }
    .c-qty { width: 40px; text-align: right; }
    .c-price { width: 78px; text-align: right; }
    .c-disc { width: 68px; text-align: right; }
    .c-tax { width: 42px; text-align: right; }
    .c-amt { width: 86px; text-align: right; font-weight: 700; }
    .item-name { font-weight: 700; color: #0f172a; }
    .item-meta { margin-top: 2px; font-size: 10px; color: #64748b; }
    .empty { text-align: center; color: #94a3b8; padding: 14px !important; }

    .bottom {
      display: flex;
      gap: 14px;
      margin-top: 14px;
      align-items: flex-start;
    }
    .notes {
      flex: 1 1 auto;
      font-size: 11px; color: #475569; line-height: 1.5;
      word-wrap: break-word;
      padding-top: 2px;
    }
    .notes strong { color: #0f172a; }
    .totals {
      flex: 0 0 230px;
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      overflow: visible;
    }
    .totals .row {
      display: flex; justify-content: space-between; gap: 8px;
      padding: 7px 10px; font-size: 11px; color: #475569;
      border-bottom: 1px solid #f1f5f9;
    }
    .totals .row:last-child { border-bottom: none; }
    .totals .row span:last-child {
      color: #0f172a; font-weight: 700; white-space: nowrap;
    }
    .totals .grand {
      background: ${theme.accentSoft};
      font-size: 12px; font-weight: 700;
      border-top: 1px solid ${theme.accentBorder};
      border-bottom: 1px solid ${theme.accentBorder};
      -webkit-print-color-adjust: exact;
      print-color-adjust: exact;
    }
    .totals .grand span:last-child { color: ${theme.accent}; }

    .footer {
      margin-top: 14px; padding-top: 10px;
      border-top: 1px solid #e2e8f0;
      display: flex; justify-content: space-between; gap: 10px;
      font-size: 10px; color: #64748b;
    }
    .footer .thanks { font-weight: 700; color: #334155; }
    .footer span:last-child {
      text-align: right; word-wrap: break-word; max-width: 55%;
    }

    @media print {
      body { padding: 12px; width: auto; }
      .header, .panel, thead th, .totals .grand {
        -webkit-print-color-adjust: exact; print-color-adjust: exact;
      }
    }
  </style>
</head>
<body>
  <div class="sheet">
    <div class="header">
      <div class="brand">
        ${logoBlock}
        <div class="brand-text">
          <h1>${escapeHtml(business.name)}</h1>
          ${business.address ? `<p>${escapeHtml(business.address)}</p>` : ""}
        </div>
      </div>
      <div class="header-right">
        <div class="eyebrow">Tax Invoice</div>
        <div class="inv-no">${escapeHtml(invoice.invoice_number)}</div>
        <div class="inv-date">${formatDate(invoice.invoice_date)}</div>
        <span class="badge ${escapeHtml(status)}">${statusBadgeHtml}</span>
      </div>
    </div>

    <div class="meta">
      <div class="card">
        <div class="card-title">Bill to</div>
        <div class="name">${escapeHtml(customer?.name || "Walk-in customer")}</div>
        <p>${escapeHtml(customer?.mobile?.trim() || "-")}</p>
      </div>
      <div class="card">
        <div class="card-title">Payment summary</div>
        <div class="sum-row"><span>Sales</span><b>${money(invoice.grand_total)}</b></div>
        <div class="sum-row"><span>Collected</span><b>${money(invoice.amount_paid)}</b></div>
        <div class="sum-row"><span>Outstanding</span><b>${money(invoice.amount_outstanding)}</b></div>
      </div>
    </div>

    ${carBlock}

    <div class="table-wrap">
      <table>
        <thead>
          <tr>
            <th class="c-no">#</th>
            <th class="c-item">Item</th>
            ${!isCar ? `<th class="c-size">Size</th><th class="c-color">Color</th>` : ""}
            <th class="c-qty">Qty</th>
            <th class="c-price">Price</th>
            <th class="c-disc">Disc</th>
            <th class="c-tax">Tax</th>
            <th class="c-amt">Amount</th>
          </tr>
        </thead>
        <tbody>${itemRows}</tbody>
      </table>
    </div>

    <div class="bottom">
      <div class="notes">
        ${
          invoice.notes
            ? `<strong>Notes:</strong> ${escapeHtml(invoice.notes)}`
            : `<span style="color:#94a3b8">No additional notes</span>`
        }
      </div>
      <div class="totals">
        <div class="row"><span>Subtotal</span><span>${money(invoice.subtotal)}</span></div>
        <div class="row"><span>Discount</span><span>${money(invoice.discount_amount)}</span></div>
        <div class="row"><span>Tax</span><span>${money(invoice.tax_amount)}</span></div>
        <div class="row"><span>Additional</span><span>${money(invoice.additional_charges)}</span></div>
        <div class="row grand"><span>Grand Total</span><span>${money(invoice.grand_total)}</span></div>
        <div class="row"><span>Paid</span><span>${money(invoice.amount_paid)}</span></div>
        <div class="row"><span>Outstanding</span><span>${money(invoice.amount_outstanding)}</span></div>
      </div>
    </div>

    <div class="footer">
      <span class="thanks">Thank you for your business</span>
      <span>${escapeHtml(business.address || business.name)}</span>
    </div>
  </div>
</body>
</html>`;
}

function escapeHtml(value: string) {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

/**
 * Narrow thermal receipt (≈80mm) — D-Mart style slip for both businesses.
 * Cars: vehicle block + Token. Clothing: line items with Size / Color / Price.
 */
export function buildThermalReceiptHtml(
  business: Business,
  invoice: InvoiceWithItems,
  options?: {
    logoUrl?: string | null;
    /** barcode value → PNG data URL for scannable bars on clothing lines */
    barcodeImages?: Record<string, string>;
  },
): string {
  const isCar = business.business_type === "car";
  const logoUrl = options?.logoUrl ?? resolveLogoUrl(business.logo_url);
  const barcodeImages = options?.barcodeImages || {};
  const customer = invoice.customers as
    | { name?: string; mobile?: string; email?: string; address?: string }
    | null
    | undefined;
  const items = invoice.invoice_items || [];
  const statusLabel = paymentStatusLabel(
    invoice.payment_status,
    business.business_type,
  );

  // One barcode only when all lines share one purchased code (one color).
  // Multi different colors → one barcode per purchased line (not every variant).
  const purchasedCodes = [
    ...new Set(
      items
        .map((i) => i.barcode?.trim())
        .filter((c): c is string => Boolean(c)),
    ),
  ];
  const singleBarcodePurchase = !isCar && purchasedCodes.length === 1;
  const logoBarcodeCode = singleBarcodePurchase ? purchasedCodes[0] : "";
  const logoBarcodeImg = logoBarcodeCode
    ? barcodeImages[logoBarcodeCode]
    : "";

  const logoBarcodeBlock =
    logoBarcodeCode && logoBarcodeImg
      ? `<div class="logo-barcodes"><div class="logo-bc">
          <img class="bc-img" src="${logoBarcodeImg}" alt="${escapeHtml(logoBarcodeCode)}" />
        </div></div>`
      : logoBarcodeCode
        ? `<div class="logo-barcodes"><div class="logo-bc">
          <div class="bc-code">${escapeHtml(logoBarcodeCode)}</div>
        </div></div>`
        : "";

  const itemRows =
    items.length > 0
      ? items
          .map((item) => {
            const amt =
              item.line_total ?? item.quantity * item.unit_price;
            // Only THIS purchased line's size/color
            const meta = !isCar
              ? [
                  item.size && `Size ${item.size}`,
                  item.color && `Color ${item.color}`,
                ]
                  .filter(Boolean)
                  .join(" · ")
              : "";
            const code = !isCar ? item.barcode?.trim() || "" : "";
            const img = code ? barcodeImages[code] : "";
            const showLineBarcode = Boolean(code) && !singleBarcodePurchase;
            return `
        <div class="item">
          <div class="item-name">${escapeHtml(item.description)}</div>
          ${meta ? `<div class="item-meta">${escapeHtml(meta)}</div>` : ""}
          ${
            showLineBarcode
              ? `<div class="item-barcode">
            ${img ? `<img class="bc-img" src="${img}" alt="${escapeHtml(code)}" />` : `<div class="bc-code">${escapeHtml(code)}</div>`}
          </div>`
              : ""
          }
          <div class="item-row">
            <span>${item.quantity} x ${money(item.unit_price)}${(item.discount_amount || 0) > 0 ? ` - Disc ${money(Number(item.discount_amount || 0))}` : ""}</span>
            <span>${money(amt)}</span>
          </div>
        </div>`;
          })
          .join("")
      : `<div class="item"><div class="item-name">${isCar ? "Vehicle billing" : "No items"}</div></div>`;


  const vehicleLines = [
    ["Make/Model", [invoice.car_make, invoice.car_model, invoice.car_variant].filter(Boolean).join(" ")],
    ["Reg. No", invoice.car_registration_number],
    ["Color", invoice.car_color],
    ["Fuel", invoice.car_fuel_type],
    ["Chassis", invoice.car_chassis_number],
    ["Engine", invoice.car_engine_number],
    ["Year", invoice.car_manufacturing_year ? String(invoice.car_manufacturing_year) : ""],
  ]
    .filter(([, v]) => v && String(v).trim())
    .map(
      ([k, v]) =>
        `<div class="kv"><span>${escapeHtml(String(k))}</span><b>${escapeHtml(String(v))}</b></div>`,
    )
    .join("");

  const paidLabel = isCar ? "Paid / Token" : "Paid";

  return `<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <title>${escapeHtml(invoice.invoice_number)}</title>
  <style>
    * { box-sizing: border-box; }
    /* Shorter pages = billing machines print full content without bottom cut */
    @page { size: 80mm 140mm; margin: 2mm; }
    html, body {
      margin: 0; padding: 0;
      background: #fff;
      height: auto !important;
      overflow: visible !important;
      -webkit-print-color-adjust: exact;
      print-color-adjust: exact;
    }
    body {
      width: 76mm;
      max-width: 76mm;
      margin: 0 auto;
      padding: 3mm 2.5mm 6mm;
      font-family: "Courier New", Courier, monospace;
      font-size: 11px;
      line-height: 1.35;
      color: #111;
    }
    .receipt {
      width: 100%;
      height: auto !important;
      min-height: 0;
      overflow: visible !important;
      padding-bottom: 8mm;
    }
    .center { text-align: center; }
    .shop {
      font-size: 12px;
      font-weight: 800;
      text-transform: uppercase;
      letter-spacing: 0.02em;
      margin: 2px 0 1px;
    }
    /* Compact logo — tight gap before barcode */
    .logo-box {
      width: 100%;
      max-width: 58mm;
      margin: 0 auto 0;
      padding: 0;
      background: #fff;
      overflow: visible !important;
      page-break-inside: avoid;
      break-inside: avoid;
      text-align: center;
      line-height: 0;
    }
    .logo-box img {
      display: block;
      max-width: 100%;
      width: auto;
      height: auto;
      max-height: 28mm;
      margin: 0 auto;
    }
    .muted { color: #333; font-size: 10px; }
    .loc {
      font-size: 9.5px;
      line-height: 1.35;
      margin: 2px auto 0;
      max-width: 68mm;
    }
    .dash {
      border: none;
      border-top: 1px dashed #222;
      margin: 6px 0;
    }
    .kv {
      display: flex;
      justify-content: space-between;
      gap: 8px;
      margin: 2px 0;
      font-size: 10.5px;
      page-break-inside: avoid;
      break-inside: avoid;
    }
    .kv span { color: #444; flex: 0 0 auto; }
    .kv b { text-align: right; font-weight: 700; word-break: break-word; }
    .item {
      margin: 5px 0;
      page-break-inside: avoid;
      break-inside: avoid;
    }
    .item-barcode {
      margin: 2px 0 4px;
      text-align: center;
      page-break-inside: avoid;
      break-inside: avoid;
    }
    /* Barcode sits tight under the logo */
    .logo-barcodes {
      margin: 1px 0 3px;
      text-align: center;
      line-height: 1.2;
    }
    .logo-bc {
      margin: 0 auto;
      page-break-inside: avoid;
      break-inside: avoid;
    }
    .logo-bc .bc-img,
    .item-barcode .bc-img {
      display: inline-block;
      width: auto;
      max-width: 100%;
      height: auto;
      max-height: 16mm;
      margin: 0 auto;
      image-rendering: -webkit-optimize-contrast;
      image-rendering: crisp-edges;
    }
    .logo-bc .bc-code,
    .item-meta.mono {
      font-family: "Courier New", Courier, monospace;
      letter-spacing: 0.04em;
      font-size: 10px;
      font-weight: 700;
      color: #111;
      margin-top: 1px;
    }
    .item-name {
      font-weight: 700;
      font-size: 11px;
      margin-top: 2px;
      word-break: break-word;
    }
    .item-meta { font-size: 10px; color: #333; margin-top: 1px; }
    .item-row {
      display: flex;
      justify-content: space-between;
      font-size: 10.5px;
      margin-top: 2px;
    }
    .totals-block {
      page-break-inside: avoid;
      break-inside: avoid;
    }
    .total-row {
      display: flex;
      justify-content: space-between;
      margin: 3px 0;
      font-size: 11px;
    }
    .total-row.grand {
      font-size: 13px;
      font-weight: 800;
      margin-top: 6px;
    }
    .badge {
      display: inline-block;
      margin-top: 4px;
      padding: 2px 6px;
      border: 1px solid #111;
      font-size: 10px;
      font-weight: 800;
      text-transform: uppercase;
    }
    .thanks {
      margin-top: 8px;
      font-weight: 700;
      font-size: 11px;
      page-break-inside: avoid;
      break-inside: avoid;
    }
    .page-continue {
      display: none;
      text-align: center;
      font-size: 9px;
      color: #666;
      margin-top: 4px;
    }
    @media print {
      body { width: 76mm; height: auto !important; overflow: visible !important; }
      .item, .kv, .totals-block, .thanks { page-break-inside: avoid; break-inside: avoid; }
    }
  </style>
</head>
<body>
  <div class="receipt">
  <div class="center">
    ${
      logoUrl
        ? `<div class="logo-box"><img src="${escapeHtml(logoUrl)}" alt="${escapeHtml(business.name)}" /></div>`
        : `<div class="shop">${escapeHtml(business.name)}</div>`
    }
    ${logoBarcodeBlock}
    ${logoUrl ? `<div class="shop">${escapeHtml(business.name)}</div>` : ""}
    ${business.address ? `<div class="muted loc">${escapeHtml(business.address)}</div>` : ""}
    ${business.phone ? `<div class="muted loc">Ph: ${escapeHtml(business.phone)}</div>` : ""}
    ${business.gstin ? `<div class="muted loc">GSTIN: ${escapeHtml(business.gstin)}</div>` : ""}
    ${business.pan ? `<div class="muted loc">PAN: ${escapeHtml(business.pan)}</div>` : ""}
  </div>

  <hr class="dash" />

  <div class="kv"><span>Bill No</span><b>${escapeHtml(invoice.invoice_number)}</b></div>
  <div class="kv"><span>Date</span><b>${formatDate(invoice.invoice_date)}</b></div>
  <div class="kv"><span>Customer</span><b>${escapeHtml(customer?.name || "Walk-in")}</b></div>
  <div class="kv"><span>Mobile</span><b>${escapeHtml(customer?.mobile?.trim() || "-")}</b></div>
  <div class="center"><span class="badge">${escapeHtml(statusLabel)}</span></div>

  ${
    isCar
      ? `<hr class="dash" />
  <div class="center muted" style="font-weight:700;margin-bottom:4px">VEHICLE</div>
  ${vehicleLines || `<div class="muted center">No vehicle details</div>`}`
      : ""
  }

  <hr class="dash" />
  <div class="center muted" style="font-weight:700;margin-bottom:4px">ITEMS</div>
  ${itemRows}

  <hr class="dash" />
  <div class="totals-block">
  <div class="total-row"><span>Subtotal</span><span>${money(invoice.subtotal)}</span></div>
  <div class="total-row"><span>Tax</span><span>${money(invoice.tax_amount)}</span></div>
  ${invoice.discount_amount ? `<div class="total-row"><span>Discount</span><span>${money(invoice.discount_amount)}</span></div>` : ""}
  ${invoice.additional_charges ? `<div class="total-row"><span>Other</span><span>${money(invoice.additional_charges)}</span></div>` : ""}
  <div class="total-row grand"><span>TOTAL</span><span>${money(invoice.grand_total)}</span></div>
  <div class="total-row"><span>${paidLabel}</span><span>${money(invoice.amount_paid)}</span></div>
  <div class="total-row"><span>Balance</span><span>${money(invoice.amount_outstanding)}</span></div>
  </div>

  <hr class="dash" />
  <div class="thanks center">
    <div>Thank you · Visit again</div>
    <div class="muted">${escapeHtml(business.name)}</div>
  </div>
  </div>
</body>
</html>`;
}

/** @deprecated use buildThermalReceiptHtml — kept for older imports */
export function buildCarThermalReceiptHtml(
  business: Business,
  invoice: InvoiceWithItems,
  options?: { logoUrl?: string | null },
): string {
  return buildThermalReceiptHtml(business, invoice, options);
}

async function buildInvoiceBarcodeImages(
  invoice: InvoiceWithItems,
): Promise<Record<string, string>> {
  const map: Record<string, string> = {};
  const codes = new Set<string>();
  for (const item of invoice.invoice_items || []) {
    const code = item.barcode?.trim();
    if (code) codes.add(code);
  }
  if (!codes.size) return map;

  const JsBarcode = (await import("jsbarcode")).default;
  for (const code of codes) {
    const canvas = document.createElement("canvas");
    try {
      // Bars + number in ONE image (no second text barcode under it)
      JsBarcode(canvas, code, {
        format: BARCODE_FORMAT,
        width: 2,
        height: 40,
        displayValue: true,
        fontSize: 12,
        textMargin: 2,
        margin: 4,
        background: "#ffffff",
        lineColor: "#000000",
        fontOptions: "bold",
        textAlign: "center",
      });
      map[code] = canvas.toDataURL("image/png");
    } catch {
      try {
        JsBarcode(canvas, code, {
          width: 2,
          height: 40,
          displayValue: true,
          fontSize: 12,
          textMargin: 2,
          margin: 4,
          background: "#ffffff",
          lineColor: "#000000",
        });
        map[code] = canvas.toDataURL("image/png");
      } catch {
        // text-only fallback
      }
    }
  }
  return map;
}

/** Fill missing barcodes from product_variants (older invoices / incomplete rows). */
export async function enrichInvoiceItemBarcodes(
  invoice: InvoiceWithItems,
  businessId: string,
): Promise<InvoiceWithItems> {
  const items = invoice.invoice_items || [];
  if (!items.length) return invoice;

  const missingVariantIds = items
    .filter((i) => !i.barcode?.trim() && i.product_variant_id)
    .map((i) => i.product_variant_id as string);

  if (!missingVariantIds.length) return invoice;

  try {
    const { createClient } = await import("@/lib/supabase/client");
    const supabase = createClient();
    const { data } = await supabase
      .from("product_variants")
      .select("id, barcode, size, color")
      .eq("business_id", businessId)
      .in("id", missingVariantIds);

    if (!data?.length) return invoice;

    const byId = new Map(data.map((r) => [r.id as string, r]));
    return {
      ...invoice,
      invoice_items: items.map((item) => {
        if (item.barcode?.trim() || !item.product_variant_id) return item;
        const v = byId.get(item.product_variant_id);
        if (!v?.barcode) return item;
        return {
          ...item,
          barcode: v.barcode as string,
          size: item.size || (v.size as string | null) || null,
          color: item.color || (v.color as string | null) || null,
        };
      }),
    };
  } catch {
    return invoice;
  }
}

export async function buildPrintableInvoiceHtml(
  business: Business,
  invoice: InvoiceWithItems,
  options?: { logoUrl?: string | null },
): Promise<string> {
  let inv = invoice;
  if (business.business_type === "clothing") {
    inv = await enrichInvoiceItemBarcodes(invoice, business.id);
  }
  const barcodeImages =
    business.business_type === "clothing"
      ? await buildInvoiceBarcodeImages(inv)
      : {};

  const rawLogo =
    options?.logoUrl ?? resolveLogoUrl(businessLogoUrl(business));
  const logoUrl = await logoToDataUrl(rawLogo);

  return buildThermalReceiptHtml(business, inv, {
    logoUrl,
    barcodeImages,
  });
}

/** Open printable invoice window (View / Print) — always 80mm thermal slip */
export async function openInvoiceWindow(
  business: Business,
  invoice: InvoiceWithItems,
  autoPrint = false,
) {
  const w = window.open("", "_blank", "width=360,height=800");
  if (!w) return false;
  const html = await buildPrintableInvoiceHtml(business, invoice, {
    logoUrl: resolveLogoUrl(businessLogoUrl(business)),
  });
  const printBoot = autoPrint
    ? `<script>
        window.onload=function(){
          var imgs=[].slice.call(document.images||[]);
          var left=imgs.length;
          function go(){ setTimeout(function(){ window.print(); }, 120); }
          if(!left){ go(); return; }
          imgs.forEach(function(img){
            if(img.complete){ if(--left===0) go(); }
            else { img.onload=img.onerror=function(){ if(--left===0) go(); }; }
          });
        }
      <\/script>`
    : "";
  w.document.write(html.replace("</body>", `${printBoot}</body>`));
  w.document.close();
  return true;
}

/** Download invoice as HTML file (open in browser / print to PDF) */
export async function downloadInvoiceHtml(
  business: Business,
  invoice: InvoiceWithItems,
) {
  const html = await buildPrintableInvoiceHtml(business, invoice, {
    logoUrl: resolveLogoUrl(businessLogoUrl(business)),
  });
  const blob = new Blob([html], { type: "text/html;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `${invoice.invoice_number}-receipt.html`;
  a.click();
  URL.revokeObjectURL(url);
}

/** Download invoice as PDF — 80mm thermal, multi-page (no bottom crop) */
export async function downloadInvoicePdf(
  business: Business,
  invoice: InvoiceWithItems,
) {
  const [{ default: html2canvas }, { jsPDF }] = await Promise.all([
    import("html2canvas"),
    import("jspdf"),
  ]);

  const html = await buildPrintableInvoiceHtml(business, invoice, {
    logoUrl: resolveLogoUrl(businessLogoUrl(business)),
  });

  const hostWidth = 302; // ~80mm
  const host = document.createElement("div");
  // Keep in viewport (off-screen) so html2canvas measures full height
  host.style.cssText = `position:fixed;left:0;top:0;width:${hostWidth}px;background:#fff;pointer-events:none;overflow:visible;height:auto;opacity:0;z-index:-1;`;
  document.body.appendChild(host);

  const match = html.match(/<body[^>]*>([\s\S]*)<\/body>/i);
  host.innerHTML = match?.[1] || html;

  const styleMatch = html.match(/<style>([\s\S]*?)<\/style>/i);
  if (styleMatch) {
    const style = document.createElement("style");
    style.textContent = styleMatch[1];
    host.prepend(style);
  }

  const images = Array.from(host.querySelectorAll("img"));
  await Promise.all(
    images.map(
      (img) =>
        new Promise<void>((resolve) => {
          if (img.complete && img.naturalHeight > 0) {
            resolve();
            return;
          }
          img.onload = () => resolve();
          img.onerror = () => resolve();
          // force reload for cached broken states
          const src = img.getAttribute("src");
          if (src) img.src = src;
        }),
    ),
  );

  // let layout settle
  await new Promise((r) => requestAnimationFrame(() => r(undefined)));

  const target =
    (host.querySelector(".receipt") as HTMLElement | null) || host;

  const fullH = Math.max(target.scrollHeight, target.offsetHeight, 1);

  const canvas = await html2canvas(target, {
    scale: 2,
    useCORS: true,
    allowTaint: true,
    backgroundColor: "#ffffff",
    logging: false,
    imageTimeout: 4000,
    width: hostWidth,
    height: fullH,
    windowWidth: hostWidth,
    windowHeight: fullH,
    scrollY: -window.scrollY,
    scrollX: 0,
  });

  // 80mm × 140mm pages — long bills go to page 2+
  const pageWidthMm = 80;
  const pageHeightMm = 140;
  const marginMm = 2.5;
  const contentW = pageWidthMm - marginMm * 2;
  const contentH = pageHeightMm - marginMm * 2 - 4; // leave footer band

  const pdf = new jsPDF({
    orientation: "portrait",
    unit: "mm",
    format: [pageWidthMm, pageHeightMm],
    compress: true,
  });

  const imgW = contentW;
  const pageCanvasH = (contentH / imgW) * canvas.width;
  const overlapPx = Math.round(pageCanvasH * 0.04); // ~4% overlap so lines aren't cut

  let srcY = 0;
  let pageIndex = 0;

  while (srcY < canvas.height - 2) {
    if (pageIndex > 0) pdf.addPage([pageWidthMm, pageHeightMm], "portrait");

    const remaining = canvas.height - srcY;
    const sliceH = Math.min(pageCanvasH, remaining);
    const slice = document.createElement("canvas");
    slice.width = canvas.width;
    slice.height = Math.max(1, Math.ceil(sliceH));
    const sctx = slice.getContext("2d");
    if (!sctx) break;
    sctx.fillStyle = "#ffffff";
    sctx.fillRect(0, 0, slice.width, slice.height);
    sctx.drawImage(
      canvas,
      0,
      srcY,
      canvas.width,
      sliceH,
      0,
      0,
      canvas.width,
      sliceH,
    );

    const sliceMmH = (slice.height * imgW) / canvas.width;
    const data = slice.toDataURL("image/jpeg", 0.95);
    pdf.addImage(
      data,
      "JPEG",
      marginMm,
      marginMm,
      imgW,
      sliceMmH,
      undefined,
      "FAST",
    );

    const hasMore = srcY + sliceH < canvas.height - 2;
    if (hasMore) {
      pdf.setFontSize(7);
      pdf.setTextColor(90);
      pdf.text("…continued →", pageWidthMm / 2, pageHeightMm - 2, {
        align: "center",
      });
      srcY += sliceH - overlapPx;
    } else {
      srcY += sliceH;
    }
    pageIndex += 1;
    if (pageIndex > 50) break;
  }

  pdf.save(`${invoice.invoice_number}-receipt.pdf`);
  host.remove();
}

/** Prefetch PDF libs so first download feels instant */
export function prefetchInvoicePdfLibs() {
  if (typeof window === "undefined") return;
  void Promise.all([import("html2canvas"), import("jspdf")]);
}
