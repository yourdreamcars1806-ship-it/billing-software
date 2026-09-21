"use client";

import JsBarcode from "jsbarcode";
import { BARCODE_FORMAT } from "@/lib/barcode";
import {
  BARCODE_LABEL,
  type BarcodeLabelMeta,
} from "@/components/barcode/barcode-display";

function moneyInr(n: number) {
  return `₹${Number(n).toLocaleString("en-IN", {
    maximumFractionDigits: 0,
  })}`;
}

/** Fit text into maxWidth; ellipsis if needed */
function fitText(
  ctx: CanvasRenderingContext2D,
  text: string,
  maxWidth: number,
): string {
  if (!text) return "";
  if (ctx.measureText(text).width <= maxWidth) return text;
  const ell = "…";
  let lo = 0;
  let hi = text.length;
  while (lo < hi) {
    const mid = Math.ceil((lo + hi) / 2);
    const slice = text.slice(0, mid) + ell;
    if (ctx.measureText(slice).width <= maxWidth) lo = mid;
    else hi = mid - 1;
  }
  return lo > 0 ? text.slice(0, lo) + ell : ell;
}

function renderBars(
  value: string,
  module: number,
  barH: number,
): HTMLCanvasElement | null {
  const canvas = document.createElement("canvas");
  try {
    JsBarcode(canvas, value, {
      format: BARCODE_FORMAT,
      width: module,
      height: barH,
      displayValue: false,
      margin: 0,
      background: "#ffffff",
      lineColor: "#000000",
    });
    return canvas;
  } catch {
    return null;
  }
}

export type BulkBarcodeItem = {
  barcode: string;
  productName?: string;
  size?: string | null;
  color?: string | null;
  price?: number | null;
};

/**
 * Sharp 38×18mm label @ 300 DPI.
 * Layout: brand/logo → one barcode → product text.
 */
export async function buildBarcodeStickerCanvas(
  value: string,
  meta?: BarcodeLabelMeta,
): Promise<HTMLCanvasElement | null> {
  const W = BARCODE_LABEL.printW;
  const H = BARCODE_LABEL.printH;
  const dpi = BARCODE_LABEL.printDpi;
  const scale = dpi / 96;

  const padX = Math.round(5 * scale);
  const padY = Math.round(3 * scale);
  const maxBarW = W - padX * 2;
  const barH = Math.round(4.8 * (dpi / 25.4));

  let module = 2;
  const estimateW = (m: number) => 11 * (value.length + 3) * m + 20 * m;
  while (module > 1 && estimateW(module) > maxBarW) module -= 1;
  if (estimateW(2) <= maxBarW) module = 2;

  let bars = renderBars(value, module, barH);
  if (!bars) return null;
  if (bars.width > maxBarW) {
    bars = renderBars(value, 1, barH);
    if (!bars) return null;
  }

  const out = document.createElement("canvas");
  out.width = W;
  out.height = H;
  const ctx = out.getContext("2d");
  if (!ctx) return null;

  ctx.fillStyle = "#ffffff";
  ctx.fillRect(0, 0, W, H);
  ctx.strokeStyle = "#d4d4d8";
  ctx.lineWidth = 1;
  ctx.strokeRect(0.5, 0.5, W - 1, H - 1);

  const name = meta?.productName?.trim() || "";
  const size = meta?.size?.trim() || "";
  const color = meta?.color?.trim() || "";
  const brand = meta?.brandLabel?.trim() || "Drape & Dream";
  const price =
    meta?.price != null && !Number.isNaN(Number(meta.price))
      ? moneyInr(Number(meta.price))
      : "";

  const textMax = W - padX * 2;
  const bottomPad = Math.round(2.5 * scale);
  let y = padY;

  ctx.textAlign = "center";
  ctx.textBaseline = "top";
  ctx.imageSmoothingEnabled = true;

  // 1. Brand / logo line
  const brandFont = Math.max(9, Math.round(5.5 * scale));
  ctx.fillStyle = "#8b6914";
  ctx.font = `600 ${brandFont}px system-ui, sans-serif`;
  ctx.fillText(fitText(ctx, brand.toUpperCase(), textMax), W / 2, y);
  y += brandFont + Math.round(2.5 * scale);

  // 2. One barcode under logo (1:1, no stretch)
  ctx.imageSmoothingEnabled = false;
  const drawW = bars.width;
  const drawH = bars.height;
  const bx = Math.round((W - drawW) / 2);
  ctx.drawImage(bars, bx, y);
  y += drawH + Math.round(2 * scale);

  // Code number (text only — not a second barcode)
  ctx.imageSmoothingEnabled = true;
  ctx.fillStyle = "#0f172a";
  const codeFont = Math.max(10, Math.round(7.5 * scale));
  ctx.font = `700 ${codeFont}px "Courier New", Courier, monospace`;
  ctx.fillText(fitText(ctx, value, textMax), W / 2, y);
  y += codeFont + Math.round(2.5 * scale);

  // 3. Product name
  if (name) {
    const nameFont = Math.max(10, Math.round(6.8 * scale));
    ctx.fillStyle = "#0f172a";
    ctx.font = `700 ${nameFont}px system-ui, sans-serif`;
    const lineH = nameFont + Math.round(1.2 * scale);
    const words = name.split(/\s+/);
    const lines: string[] = [];
    let cur = "";
    for (const w of words) {
      const next = cur ? `${cur} ${w}` : w;
      if (ctx.measureText(next).width <= textMax) cur = next;
      else {
        if (cur) lines.push(cur);
        cur = w;
        if (lines.length >= 2) break;
      }
    }
    if (cur && lines.length < 2) lines.push(cur);
    if (lines.length === 2) lines[1] = fitText(ctx, lines[1], textMax);
    for (const line of lines.slice(0, 2)) {
      if (y + nameFont > H - bottomPad) break;
      ctx.fillText(line, W / 2, y);
      y += lineH;
    }
  }

  // Size · Color · Price
  const metaLine = [size && `Sz ${size}`, color, price]
    .filter(Boolean)
    .join(" · ");
  if (metaLine) {
    const metaFont = Math.max(9, Math.round(6 * scale));
    ctx.fillStyle = "#475569";
    ctx.font = `600 ${metaFont}px system-ui, sans-serif`;
    if (y + metaFont <= H - bottomPad) {
      ctx.fillText(fitText(ctx, metaLine, textMax), W / 2, y);
    }
  }

  return out;
}

export async function downloadBarcodePng(
  value: string,
  filename = `${value}.png`,
  meta?: BarcodeLabelMeta,
) {
  const out = await buildBarcodeStickerCanvas(value, meta);
  if (!out) return false;

  const link = document.createElement("a");
  link.download = filename.replace(/[^\w.-]+/g, "_");
  link.href = out.toDataURL("image/png");
  link.click();
  return true;
}

/** Bulk A4 — sharp PNG labels, 5×12 = 60 per page */
export async function downloadBulkBarcodePdf(
  items: BulkBarcodeItem[],
  filename = "barcodes-bulk.pdf",
) {
  if (!items.length) return false;

  const { jsPDF } = await import("jspdf");
  const pdf = new jsPDF({
    orientation: "portrait",
    unit: "mm",
    format: "a4",
    compress: true,
  });

  const pageW = 210;
  const pageH = 297;
  const labelW = BARCODE_LABEL.widthMm;
  const labelH = BARCODE_LABEL.heightMm;
  const cols = 5;
  const rows = 12;
  const perPage = cols * rows;
  const gapX = 3;
  const gapY = 2.5;
  const gridW = cols * labelW + (cols - 1) * gapX;
  const gridH = rows * labelH + (rows - 1) * gapY;
  const startX = (pageW - gridW) / 2;
  const startY = (pageH - gridH) / 2 - 2;

  for (let i = 0; i < items.length; i++) {
    const item = items[i];
    const slot = i % perPage;
    if (i > 0 && slot === 0) pdf.addPage();

    const col = slot % cols;
    const row = Math.floor(slot / cols);
    const x = startX + col * (labelW + gapX);
    const y = startY + row * (labelH + gapY);

    const canvas = await buildBarcodeStickerCanvas(item.barcode, {
      productName: item.productName,
      size: item.size,
      color: item.color,
      price: item.price,
    });
    if (!canvas) continue;

    const data = canvas.toDataURL("image/png");
    pdf.addImage(data, "PNG", x, y, labelW, labelH, undefined, "NONE");
  }

  const totalPages = pdf.getNumberOfPages();
  for (let p = 1; p <= totalPages; p++) {
    pdf.setPage(p);
    pdf.setFontSize(7);
    pdf.setTextColor(150);
    pdf.text(
      `Drape & Dream · ${items.length} labels · ${p}/${totalPages}`,
      pageW / 2,
      pageH - 6,
      { align: "center" },
    );
  }

  pdf.save(filename.replace(/[^\w.-]+/g, "_"));
  return true;
}
