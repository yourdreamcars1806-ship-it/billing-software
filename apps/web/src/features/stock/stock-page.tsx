"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { Package, RefreshCw } from "lucide-react";
import { Button } from "@/components/ui/button";
import { LoadingOverlay } from "@/components/ui/spinner";
import {
  loadStockOverview,
  type CategoryStockRow,
  type StockOverview,
} from "@/lib/stock-overview";
import { cn, formatMoney } from "@/lib/utils";
import type { Business } from "@/types";

function CategoryBox({ row }: { row: CategoryStockRow }) {
  const hasStock = row.inStockPcs > 0;

  return (
    <div
      className={cn(
        "border bg-white px-3.5 py-3.5",
        hasStock ? "border-slate-200" : "border-dashed border-slate-200",
      )}
    >
      <div className="flex items-center justify-between gap-2">
        <h3 className="truncate text-[15px] font-semibold text-slate-900">
          {row.category}
        </h3>
        <span
          className={cn(
            "shrink-0 rounded-sm px-2 py-0.5 text-sm font-semibold tabular-nums",
            hasStock
              ? "bg-emerald-50 text-emerald-800"
              : "bg-red-50 text-red-700",
          )}
        >
          {row.inStockPcs} pcs
        </span>
      </div>

      <div className="mt-3 grid grid-cols-2 gap-2">
        <div className="bg-slate-50 px-2.5 py-2">
          <p className="text-[10px] font-medium uppercase tracking-wide text-slate-400">
            Buy
          </p>
          <p className="mt-0.5 truncate text-sm font-semibold tabular-nums text-slate-800">
            {formatMoney(row.buyValue)}
          </p>
        </div>
        <div className="bg-brand-soft/50 px-2.5 py-2">
          <p className="text-[10px] font-medium uppercase tracking-wide text-brand-ink">
            Sell
          </p>
          <p className="mt-0.5 truncate text-sm font-semibold tabular-nums text-brand-ink">
            {formatMoney(row.sellValue)}
          </p>
        </div>
      </div>

      {(row.soldPcs > 0 || row.outOfStockItems > 0) && (
        <p className="mt-2 truncate text-[11px] tabular-nums text-slate-500">
          {row.soldPcs > 0
            ? `Sold ${row.soldPcs} · ${formatMoney(row.soldValue)}`
            : null}
          {row.soldPcs > 0 && row.outOfStockItems > 0 ? " · " : null}
          {row.outOfStockItems > 0 ? `${row.outOfStockItems} out` : null}
        </p>
      )}
    </div>
  );
}

export function StockPage({ business }: { business: Business }) {
  const [overview, setOverview] = useState<StockOverview | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await loadStockOverview(business.id);
      setOverview(data);
    } catch {
      setError("Failed to load stock");
      setOverview(null);
    } finally {
      setLoading(false);
    }
  }, [business.id]);

  useEffect(() => {
    void load();
    const onStock = () => void load();
    window.addEventListener("clothing-stock-changed", onStock);
    return () => window.removeEventListener("clothing-stock-changed", onStock);
  }, [load]);

  const totals = overview?.totals;

  return (
    <div className="space-y-4">
      <LoadingOverlay show={loading} label="Loading stock…" />

      <div className="flex flex-wrap items-center justify-between gap-2 border-b border-slate-200 pb-3.5">
        <div>
          <h1 className="text-lg font-semibold tracking-tight text-slate-900">
            Stock by category
          </h1>
          <p className="mt-0.5 text-sm text-slate-500">
            Stock · buy · sell per category
          </p>
        </div>
        <div className="flex gap-2">
          <Button
            type="button"
            variant="outline"
            size="sm"
            onClick={() => void load()}
            disabled={loading}
          >
            <RefreshCw className="h-3.5 w-3.5" />
            Refresh
          </Button>
          <Link href={`/b/${business.slug}/products`}>
            <Button type="button" variant="outline" size="sm">
              <Package className="h-3.5 w-3.5" />
              Products
            </Button>
          </Link>
        </div>
      </div>

      {error ? (
        <div className="border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
          {error}
        </div>
      ) : null}

      {totals ? (
        <div className="grid grid-cols-2 gap-2.5 sm:grid-cols-4">
          <div className="border border-slate-200 bg-white px-3.5 py-2.5">
            <p className="text-[10px] font-medium uppercase tracking-wide text-slate-400">
              In stock
            </p>
            <p className="mt-0.5 text-xl font-semibold tabular-nums text-emerald-700">
              {totals.inStockPcs}
              <span className="ml-1 text-xs font-normal text-slate-400">
                pcs
              </span>
            </p>
          </div>
          <div className="border border-slate-200 bg-white px-3.5 py-2.5">
            <p className="text-[10px] font-medium uppercase tracking-wide text-slate-400">
              No stock
            </p>
            <p
              className={cn(
                "mt-0.5 text-xl font-semibold tabular-nums",
                totals.outOfStockItems > 0 ? "text-red-600" : "text-slate-800",
              )}
            >
              {totals.outOfStockItems}
            </p>
          </div>
          <div className="border border-slate-200 bg-white px-3.5 py-2.5">
            <p className="text-[10px] font-medium uppercase tracking-wide text-slate-400">
              Buy value
            </p>
            <p className="mt-0.5 truncate text-[15px] font-semibold tabular-nums text-slate-900">
              {formatMoney(totals.buyValue)}
            </p>
          </div>
          <div className="border border-brand-border bg-brand-soft/30 px-3.5 py-2.5">
            <p className="text-[10px] font-medium uppercase tracking-wide text-brand-ink">
              Sell value
            </p>
            <p className="mt-0.5 truncate text-[15px] font-semibold tabular-nums text-brand-ink">
              {formatMoney(totals.sellValue)}
            </p>
          </div>
        </div>
      ) : null}

      {overview ? (
        <div className="grid grid-cols-2 gap-2.5 lg:grid-cols-4">
          {overview.categories.map((row) => (
            <CategoryBox key={row.category} row={row} />
          ))}
        </div>
      ) : null}

      {totals && totals.soldPcs > 0 ? (
        <p className="text-sm tabular-nums text-slate-500">
          Sold · {totals.soldPcs} pcs · {formatMoney(totals.soldValue)}
        </p>
      ) : null}
    </div>
  );
}
