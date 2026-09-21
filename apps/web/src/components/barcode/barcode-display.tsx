"use client";

import { useEffect, useRef } from "react";
import JsBarcode from "jsbarcode";
import { BARCODE_FORMAT } from "@/lib/barcode";
import { cn, formatMoney } from "@/lib/utils";

export type BarcodeLabelMeta = {
  productName?: string;
  size?: string | null;
  color?: string | null;
  price?: number | null;
  brandLabel?: string;
};

/**
 * Sharp compact label — 38mm × 18mm @ 300dpi print.
 * Layout: brand/logo → barcode → product text.
 */
export const BARCODE_LABEL = {
  widthMm: 38,
  heightMm: 18,
  previewW: 200,
  previewH: 95,
  printDpi: 300,
  printW: Math.round((38 / 25.4) * 300), // ~449
  printH: Math.round((18 / 25.4) * 300), // ~213
  barHeightPx: 26,
  barModule: 1.35,
  barFont: 9,
} as const;

export function BarcodeDisplay({
  value,
  className = "",
  productName,
  size,
  color,
  price,
  brandLabel = "Drape & Dream",
}: {
  value: string;
  className?: string;
} & BarcodeLabelMeta) {
  const svgRef = useRef<SVGSVGElement>(null);

  useEffect(() => {
    if (!svgRef.current || !value) return;
    // Clear previous SVG so a second barcode never stacks
    while (svgRef.current.firstChild) {
      svgRef.current.removeChild(svgRef.current.firstChild);
    }
    try {
      JsBarcode(svgRef.current, value, {
        format: BARCODE_FORMAT,
        width: BARCODE_LABEL.barModule,
        height: BARCODE_LABEL.barHeightPx,
        displayValue: false,
        margin: 0,
        background: "#ffffff",
        lineColor: "#000000",
      });
    } catch {
      // invalid barcode
    }
  }, [value]);

  if (!value) {
    return <span className="text-xs text-slate-400">No barcode</span>;
  }

  const metaBits = [
    size?.trim() ? `Sz ${size.trim()}` : null,
    color?.trim() || null,
    price != null ? formatMoney(price) : null,
  ].filter(Boolean);

  const name = productName?.trim() || "";

  return (
    <div
      className={cn("relative mx-auto overflow-hidden bg-white", className)}
      style={{
        width: BARCODE_LABEL.previewW,
        height: BARCODE_LABEL.previewH,
        border: "1px solid #cbd5e1",
      }}
    >
      <div className="flex h-full flex-col items-center px-1.5 py-1 text-center">
        {/* 1. Brand / logo */}
        <p className="w-full shrink-0 truncate text-[7px] font-semibold uppercase tracking-[0.06em] text-[#8b6914]">
          {brandLabel}
        </p>

        {/* 2. One barcode under logo */}
        <div className="mt-0.5 flex w-full shrink-0 flex-col items-center">
          <svg
            ref={svgRef}
            className="max-h-[32px] max-w-full"
            style={{ imageRendering: "crisp-edges" }}
          />
          <p className="mt-0.5 font-mono text-[8px] font-bold leading-none tracking-wide text-slate-900">
            {value}
          </p>
        </div>

        {/* 3. Product text */}
        <div className="mt-1 w-full min-w-0 flex-1 space-y-0.5 leading-tight">
          {name ? (
            <p
              className="line-clamp-2 text-[9px] font-bold leading-snug text-slate-900"
              title={name}
            >
              {name}
            </p>
          ) : null}
          {metaBits.length > 0 ? (
            <p className="truncate text-[8px] font-medium text-slate-600">
              {metaBits.join(" · ")}
            </p>
          ) : null}
        </div>
      </div>
    </div>
  );
}
