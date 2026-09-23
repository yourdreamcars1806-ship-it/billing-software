"use client";

import type { Business } from "@/types";
import { businessLogoUrl, resolveLogoUrl } from "@/lib/invoice-document";
import { formatMoney } from "@/lib/utils";

export type DeliveryNoteData = {
  delivery_note_no: string;
  delivery_date: string;
  delivery_time: string;
  customer_name: string;
  customer_address: string;
  customer_mobile: string;
  id_proof: string;
  id_no: string;
  car_make: string;
  car_model_variant: string;
  car_registration_number: string;
  car_manufacturing_year: string;
  car_color: string;
  car_fuel_type: string;
  car_chassis_number: string;
  car_engine_number: string;
  odometer_km: string;
  total_vehicle_price: string;
  amount_received: string;
  balance_amount: string;
  payment_modes: {
    cash: boolean;
    upi: boolean;
    bank_transfer: boolean;
    finance: boolean;
    other: boolean;
  };
  payment_other: string;
  docs: {
    rc: boolean;
    insurance: boolean;
    puc: boolean;
    service_records: boolean;
    keys: boolean;
    spare_key: boolean;
    other: boolean;
  };
  docs_other: string;
  declaration_name: string;
  customer_sign_name: string;
  customer_sign_datetime: string;
  auth_sign_name: string;
  handed_over_by: string;
  cancel_terms_enabled: boolean;
  cancel_gst_percent: string;
  paper_processing_fee: string;
  cancellation_terms: string;
  delivery_status: "draft" | "confirmed" | "cancelled";
  cancel_reason: string;
};

export function defaultCancellationTerms(
  gstPercent = "18",
  paperFee = "",
  businessName = "Your Dream Cars",
) {
  const gst = gstPercent.trim() || "18";
  const feePart = paperFee.trim()
    ? `plus a paper / documentation processing fee of ${formatMoney(Number(paperFee) || 0)}`
    : "plus applicable paper / documentation processing fees";
  return (
    `Deal cancellation: If this deal or booking is cancelled by the customer for any reason, ` +
    `${businessName} shall be entitled to charge ${gst}% GST on the applicable amount ${feePart}. ` +
    `Token / advance amounts may be adjusted against these charges as per dealership policy.`
  );
}

function escapeHtml(s: string) {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function val(value: string, blank = "______________________________") {
  const v = value.trim();
  return escapeHtml(v || blank);
}

function moneyVal(raw: string) {
  const n = Number(String(raw).replace(/,/g, ""));
  if (!raw.trim() || Number.isNaN(n)) return "₹ ____________________";
  return escapeHtml(formatMoney(n));
}

function formatDisplayDate(iso: string) {
  const t = iso.trim();
  if (!t) return "____ / ____ / ______";
  const d = new Date(t.includes("T") ? t : `${t}T12:00:00`);
  if (Number.isNaN(d.getTime())) return t;
  return d.toLocaleDateString("en-IN", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  });
}

function box(on: boolean) {
  return on ? "☑" : "☐";
}

async function logoToDataUrl(src: string | null): Promise<string | null> {
  if (!src) return null;
  try {
    const url = src.startsWith("data:") ? src : resolveLogoUrl(src) || src;
    const isRemote = /^https?:\/\//i.test(url);
    const img = await new Promise<HTMLImageElement>((resolve, reject) => {
      const el = new Image();
      if (isRemote) el.crossOrigin = "anonymous";
      el.onload = () => resolve(el);
      el.onerror = () => reject(new Error("logo load failed"));
      el.src = url;
    });
    const canvas = document.createElement("canvas");
    canvas.width = img.width;
    canvas.height = img.height;
    const ctx = canvas.getContext("2d");
    if (!ctx) return url;
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.drawImage(img, 0, 0);
    return canvas.toDataURL("image/png");
  } catch {
    return resolveLogoUrl(src);
  }
}

export async function buildPrintableDeliveryNoteHtml(
  business: Business,
  data: DeliveryNoteData,
): Promise<string> {
  const raw = businessLogoUrl(business);
  const embedded = await logoToDataUrl(raw);
  return buildDeliveryNoteHtml(business, data, {
    logoUrl: embedded || resolveLogoUrl(raw),
  });
}

function line(label: string, valueHtml: string, wide = false) {
  return `<tr class="${wide ? "wide" : ""}">
    <td class="lbl">${escapeHtml(label)}</td>
    <td class="sep">:</td>
    <td class="val">${valueHtml}</td>
  </tr>`;
}

export function buildDeliveryNoteHtml(
  business: Business,
  data: DeliveryNoteData,
  options?: { logoUrl?: string | null },
): string {
  const logoUrl = options?.logoUrl ?? resolveLogoUrl(businessLogoUrl(business));
  const address =
    business.address?.trim() || "Clover Hills Plaza, NIBM, Pune";
  const phone = business.phone?.trim() || "";
  const email = business.email?.trim() || "";
  const name = business.name || "Your Dream Cars";

  const logoBlock = logoUrl
    ? `<img class="logo" src="${escapeHtml(logoUrl)}" alt="${escapeHtml(name)}" />`
    : "";

  const declName =
    data.declaration_name.trim() ||
    data.customer_name.trim() ||
    "____________________";

  const cancelText =
    data.cancellation_terms.trim() ||
    defaultCancellationTerms(
      data.cancel_gst_percent,
      data.paper_processing_fee,
      name,
    );

  const gstLabel = data.cancel_gst_percent.trim() || "18";
  const feeLabel = data.paper_processing_fee.trim()
    ? formatMoney(Number(data.paper_processing_fee) || 0)
    : "As applicable";

  const status = data.delivery_status || "draft";
  const statusLabel =
    status === "confirmed"
      ? "CONFIRMED"
      : status === "cancelled"
        ? "CANCELLED"
        : "DRAFT";

  const payRow = [
    `${box(data.payment_modes.cash)} Cash`,
    `${box(data.payment_modes.upi)} UPI`,
    `${box(data.payment_modes.bank_transfer)} Bank Transfer`,
    `${box(data.payment_modes.finance)} Finance`,
    `${box(data.payment_modes.other)} Other${
      data.payment_other.trim() ? ` (${escapeHtml(data.payment_other.trim())})` : ""
    }`,
  ].join("&nbsp;&nbsp;&nbsp;");

  const docRow = [
    `${box(data.docs.rc)} RC`,
    `${box(data.docs.insurance)} Insurance`,
    `${box(data.docs.puc)} PUC`,
    `${box(data.docs.service_records)} Service Records`,
    `${box(data.docs.keys)} Keys`,
    `${box(data.docs.spare_key)} Spare Key`,
    `${box(data.docs.other)} Other${
      data.docs_other.trim() ? ` (${escapeHtml(data.docs_other.trim())})` : ""
    }`,
  ].join("&nbsp;&nbsp;&nbsp;");

  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8" />
<title>Vehicle Delivery Note — ${escapeHtml(data.delivery_note_no || name)}</title>
<style>
  @page { size: A4 portrait; margin: 12mm; }
  * { box-sizing: border-box; }
  html, body {
    margin: 0;
    padding: 0;
    background: #fff;
    color: #111;
    font-family: Georgia, "Times New Roman", Times, serif;
    font-size: 11px;
    line-height: 1.45;
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }
  .sheet {
    width: 186mm;
    max-width: 186mm;
    margin: 0 auto;
    padding: 2mm 1mm 3mm;
    background: #fff;
    overflow: visible;
  }
  .frame {
    border: 2px solid #1a1a1a;
    padding: 10px 12px 12px;
    overflow: visible;
  }
  .frame-inner {
    border: 1px solid #444;
    padding: 12px 14px 14px;
    overflow: visible;
  }

  .letterhead {
    display: flex;
    align-items: center;
    gap: 14px;
    padding-bottom: 8px;
    border-bottom: 1.5px solid #1a1a1a;
  }
  .logo {
    width: 58px;
    height: 58px;
    object-fit: contain;
    flex-shrink: 0;
  }
  .company { flex: 1; text-align: center; }
  .company h1 {
    margin: 0;
    font-size: 18px;
    font-weight: 700;
    letter-spacing: 0.12em;
    text-transform: uppercase;
    color: #0b1f4d;
  }
  .company .addr {
    margin: 3px 0 0;
    font-family: "Segoe UI", Arial, sans-serif;
    font-size: 9.5px;
    color: #333;
  }
  .company .contact {
    margin: 1px 0 0;
    font-family: "Segoe UI", Arial, sans-serif;
    font-size: 9px;
    color: #555;
  }
  .stamp-status {
    flex-shrink: 0;
    font-family: "Segoe UI", Arial, sans-serif;
    font-size: 9px;
    font-weight: 700;
    letter-spacing: 0.08em;
    border: 1.5px solid #0b1f4d;
    color: #0b1f4d;
    padding: 5px 7px;
    text-align: center;
    min-width: 72px;
  }
  .stamp-status.confirmed { border-color: #166534; color: #166534; }
  .stamp-status.cancelled { border-color: #991b1b; color: #991b1b; }

  .doc-title {
    text-align: center;
    margin: 10px 0 4px;
    font-size: 15px;
    font-weight: 700;
    letter-spacing: 0.18em;
    text-transform: uppercase;
    text-decoration: underline;
    text-underline-offset: 3px;
  }
  .doc-sub {
    text-align: center;
    font-family: "Segoe UI", Arial, sans-serif;
    font-size: 9px;
    color: #555;
    margin-bottom: 10px;
  }

  .meta-row {
    display: flex;
    justify-content: space-between;
    gap: 12px;
    margin-bottom: 10px;
    font-family: "Segoe UI", Arial, sans-serif;
    font-size: 10.5px;
  }
  .meta-row strong { font-weight: 700; }

  .section-title {
    margin: 11px 0 6px;
    font-size: 11.5px;
    font-weight: 700;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    border-bottom: 1px solid #1a1a1a;
    padding-bottom: 2px;
  }

  table.fields {
    width: 100%;
    border-collapse: collapse;
    table-layout: fixed;
  }
  table.fields td {
    vertical-align: bottom;
    padding: 3px 0 4px;
    font-family: "Segoe UI", Arial, sans-serif;
    font-size: 10.5px;
  }
  table.fields td.lbl {
    width: 28%;
    color: #222;
    white-space: nowrap;
    padding-right: 4px;
  }
  table.fields td.sep {
    width: 12px;
    color: #222;
  }
  table.fields td.val {
    width: auto;
    font-weight: 600;
    color: #000;
    border-bottom: 1px dotted #666;
    word-wrap: break-word;
    overflow-wrap: anywhere;
    padding-left: 4px;
    min-height: 16px;
  }
  table.fields tr.wide td.lbl { width: 28%; }

  .two-col {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0 16px;
  }

  .checks {
    font-family: "Segoe UI", Arial, sans-serif;
    font-size: 10.5px;
    line-height: 1.7;
    margin-top: 2px;
  }

  .decl {
    font-family: "Segoe UI", Arial, sans-serif;
    font-size: 10px;
    text-align: justify;
    color: #222;
    margin: 4px 0;
  }

  .sign-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 16px;
    margin-top: 10px;
  }
  .sign-box {
    border: 1px solid #333;
    padding: 8px 10px 10px;
    min-height: 108px;
  }
  .sign-box h4 {
    margin: 0 0 28px;
    font-family: "Segoe UI", Arial, sans-serif;
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }
  .sign-box .sl {
    border-top: 1px solid #333;
    margin-top: 12px;
    padding-top: 3px;
    font-family: "Segoe UI", Arial, sans-serif;
    font-size: 9.5px;
  }

  .terms {
    margin-top: 10px;
    border: 1px solid #333;
    padding: 7px 9px;
    background: #fafafa;
  }
  .terms h4 {
    margin: 0 0 4px;
    font-family: "Segoe UI", Arial, sans-serif;
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;
  }
  .terms .nums {
    font-family: "Segoe UI", Arial, sans-serif;
    font-size: 10px;
    font-weight: 700;
    margin-bottom: 3px;
  }
  .terms p {
    margin: 0;
    font-family: "Segoe UI", Arial, sans-serif;
    font-size: 9.5px;
    text-align: justify;
    color: #222;
  }

  .footer-note {
    margin-top: 10px;
    font-family: "Segoe UI", Arial, sans-serif;
    font-size: 8.5px;
    color: #444;
    text-align: center;
    border-top: 1px solid #999;
    padding-top: 6px;
  }

  .cancel-banner {
    margin: 8px 0;
    padding: 6px;
    text-align: center;
    font-family: "Segoe UI", Arial, sans-serif;
    font-size: 11px;
    font-weight: 700;
    letter-spacing: 0.08em;
    border: 2px solid #991b1b;
    color: #991b1b;
  }

  @media print {
    .sheet { width: 100%; max-width: none; }
  }
</style>
</head>
<body>
  <div class="sheet" id="dn-root">
    <div class="frame">
      <div class="frame-inner">
        <div class="letterhead">
          ${logoBlock}
          <div class="company">
            <h1>${escapeHtml(name)}</h1>
            <p class="addr">${escapeHtml(address)}</p>
            <p class="contact">${[
              phone ? `Tel: ${escapeHtml(phone)}` : "",
              email ? `Email: ${escapeHtml(email)}` : "",
            ]
              .filter(Boolean)
              .join("  |  ")}</p>
          </div>
          <div class="stamp-status ${escapeHtml(status)}">${escapeHtml(statusLabel)}</div>
        </div>

        ${
          status === "cancelled"
            ? `<div class="cancel-banner">DEAL / DELIVERY CANCELLED${
                data.cancel_reason.trim()
                  ? ` — ${escapeHtml(data.cancel_reason.trim())}`
                  : ""
              }</div>`
            : ""
        }

        <div class="doc-title">Vehicle Delivery Note</div>
        <div class="doc-sub">Official handover record · Keep two signed copies</div>

        <div class="meta-row">
          <div><strong>Delivery Note No.:</strong> ${val(data.delivery_note_no, "____________________")}</div>
          <div><strong>Date:</strong> ${escapeHtml(formatDisplayDate(data.delivery_date))}</div>
          <div><strong>Time:</strong> ${val(data.delivery_time, "____________")}</div>
        </div>

        <div class="section-title">1. Customer Details</div>
        <table class="fields">
          ${line("Customer Name", val(data.customer_name))}
          ${line("Address", val(data.customer_address), true)}
          ${line("Mobile No.", val(data.customer_mobile, "____________________"))}
          ${line(
            "ID Proof / ID No.",
            val(
              [data.id_proof, data.id_no].filter((x) => x.trim()).join(" / "),
              "____________________",
            ),
          )}
        </table>

        <div class="section-title">2. Vehicle Details</div>
        <div class="two-col">
          <table class="fields">
            ${line("Make / Brand", val(data.car_make, "____________________"))}
            ${line("Registration No.", val(data.car_registration_number, "____________________"))}
            ${line("Colour", val(data.car_color, "____________________"))}
            ${line("Chassis No.", val(data.car_chassis_number, "____________________"))}
          </table>
          <table class="fields">
            ${line("Model / Variant", val(data.car_model_variant, "____________________"))}
            ${line("Year of Manufacture", val(data.car_manufacturing_year, "____________________"))}
            ${line("Fuel Type", val(data.car_fuel_type, "____________________"))}
            ${line("Engine No.", val(data.car_engine_number, "____________________"))}
          </table>
        </div>
        <table class="fields" style="margin-top:2px">
          ${line("Odometer Reading", val(data.odometer_km ? `${data.odometer_km} KM` : "", "____________________ KM"))}
        </table>

        <div class="section-title">3. Payment Details</div>
        <div class="two-col">
          <table class="fields">
            ${line("Total Vehicle Price", moneyVal(data.total_vehicle_price))}
            ${line("Balance Amount", moneyVal(data.balance_amount))}
          </table>
          <table class="fields">
            ${line("Amount Received", moneyVal(data.amount_received))}
            ${line("Payment Mode", `<span style="font-weight:500">${payRow}</span>`)}
          </table>
        </div>

        <div class="section-title">4. Documents / Items Handed Over</div>
        <div class="checks">${docRow}</div>

        <div class="section-title">5. Delivery Declaration</div>
        <p class="decl">
          I, <strong>${escapeHtml(declName)}</strong>, confirm that I have inspected the above-mentioned vehicle
          and have taken physical delivery of it from <strong>${escapeHtml(name)}</strong>
          in the condition mutually agreed upon.
        </p>
        <p class="decl">
          I acknowledge receipt of the vehicle, keys and documents/items mentioned above.
          Any pending documentation, ownership transfer, payment or other commitment, if applicable,
          shall be completed according to the separately agreed terms.
        </p>

        <div class="sign-grid">
          <div class="sign-box">
            <h4>Customer Signature</h4>
            <div class="sl">Name: ${val(data.customer_sign_name || data.customer_name, "____________________")}</div>
            <div class="sl">Date &amp; Time: ${val(
              data.customer_sign_datetime ||
                [formatDisplayDate(data.delivery_date), data.delivery_time]
                  .filter((x) => x && !x.includes("____"))
                  .join(" · "),
              "____________________",
            )}</div>
          </div>
          <div class="sign-box">
            <h4>For ${escapeHtml(name.toUpperCase())}</h4>
            <div class="sl">Authorized Signature / Stamp</div>
            <div class="sl">Name: ${val(data.auth_sign_name, "____________________")}</div>
            <div class="sl">Handed Over By: ${val(data.handed_over_by, "____________________")}</div>
          </div>
        </div>

        ${
          data.cancel_terms_enabled
            ? `<div class="terms">
          <h4>6. Deal Cancellation Charges</h4>
          <div class="nums">GST on cancellation: ${escapeHtml(gstLabel)}% &nbsp;|&nbsp; Paper processing fees: ${escapeHtml(feeLabel)}</div>
          <p>${escapeHtml(cancelText)}</p>
        </div>`
            : ""
        }

        <div class="footer-note">
          This delivery note supplements (does not replace) the sale agreement / receipt and RTO transfer documents.
          &nbsp;·&nbsp; Customer copy &amp; dealer copy to be signed.
          &nbsp;·&nbsp; ${escapeHtml(data.delivery_note_no || "")}
        </div>
      </div>
    </div>
  </div>
</body>
</html>`;
}

export async function openDeliveryNoteWindow(
  business: Business,
  data: DeliveryNoteData,
  autoPrint = false,
) {
  const w = window.open("", "_blank", "width=900,height=1200");
  if (!w) return false;
  const html = await buildPrintableDeliveryNoteHtml(business, data);
  const printBoot = autoPrint
    ? `<script>
        window.onload=function(){
          var imgs=[].slice.call(document.images||[]);
          var left=imgs.length;
          function go(){ setTimeout(function(){ window.print(); }, 250); }
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

/**
 * A4 PDF download — same reliable html2canvas + slice pattern as invoice PDFs.
 * Does not use jsPDF.html() (often hangs / blank on Windows Chrome).
 */
export async function downloadDeliveryNotePdf(
  business: Business,
  data: DeliveryNoteData,
) {
  const [{ default: html2canvas }, { jsPDF }] = await Promise.all([
    import("html2canvas"),
    import("jspdf"),
  ]);

  const html = await buildPrintableDeliveryNoteHtml(business, data);

  // A4 @ ~96dpi content width (~190mm usable)
  const hostWidth = 794;
  const host = document.createElement("div");
  host.style.cssText = `position:fixed;left:0;top:0;width:${hostWidth}px;background:#fff;pointer-events:none;overflow:visible;height:auto;opacity:0;z-index:-1;`;
  document.body.appendChild(host);

  try {
    const match = html.match(/<body[^>]*>([\s\S]*)<\/body>/i);
    host.innerHTML = match?.[1] || html;

    const styleMatch = html.match(/<style>([\s\S]*?)<\/style>/i);
    if (styleMatch) {
      const style = document.createElement("style");
      style.textContent =
        styleMatch[1] +
        ` .sheet{width:${hostWidth}px!important;max-width:${hostWidth}px!important;margin:0!important;}`;
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
            const src = img.getAttribute("src");
            if (src) img.src = src;
          }),
      ),
    );

    await new Promise((r) => requestAnimationFrame(() => r(undefined)));
    await new Promise((r) => setTimeout(r, 50));

    const target =
      (host.querySelector("#dn-root") as HTMLElement | null) ||
      (host.querySelector(".sheet") as HTMLElement | null) ||
      host;

    const fullH = Math.max(
      target.scrollHeight,
      target.offsetHeight,
      target.getBoundingClientRect().height,
      1,
    );

    if (fullH < 40) {
      throw new Error("Delivery note layout failed to render");
    }

    const canvas = await html2canvas(target, {
      scale: 2,
      useCORS: true,
      allowTaint: true,
      backgroundColor: "#ffffff",
      logging: false,
      imageTimeout: 8000,
      width: hostWidth,
      height: Math.ceil(fullH),
      windowWidth: hostWidth,
      windowHeight: Math.ceil(fullH),
      scrollX: 0,
      scrollY: -window.scrollY,
    });

    if (!canvas.width || !canvas.height) {
      throw new Error("PDF canvas is empty");
    }

    const pdf = new jsPDF({
      orientation: "portrait",
      unit: "mm",
      format: "a4",
      compress: true,
    });

    const pageW = pdf.internal.pageSize.getWidth();
    const pageH = pdf.internal.pageSize.getHeight();
    const marginMm = 8;
    const contentW = pageW - marginMm * 2;
    const contentH = pageH - marginMm * 2;
    const imgW = contentW;
    const pageCanvasH = (contentH / imgW) * canvas.width;
    // Small overlap so lines aren't cut at page breaks
    const overlapPx = Math.round(pageCanvasH * 0.03);

    let srcY = 0;
    let pageIndex = 0;

    while (srcY < canvas.height - 2) {
      if (pageIndex > 0) pdf.addPage();

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
      pdf.addImage(
        slice.toDataURL("image/jpeg", 0.95),
        "JPEG",
        marginMm,
        marginMm,
        imgW,
        sliceMmH,
      );

      if (remaining <= pageCanvasH + 1) break;
      srcY += sliceH - overlapPx;
      pageIndex += 1;
      if (pageIndex > 12) break;
    }

    const no = data.delivery_note_no.trim() || "delivery-note";
    pdf.save(`${no.replace(/[^\w.-]+/g, "_")}.pdf`);
  } finally {
    if (host.parentNode) host.parentNode.removeChild(host);
  }
}
