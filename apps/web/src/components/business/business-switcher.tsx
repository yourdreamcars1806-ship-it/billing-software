"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { ChevronDown, Check, Shirt, Car } from "lucide-react";
import { useBusinessStore } from "@/hooks/use-business-store";
import type { Business } from "@/types";
import { cn } from "@/lib/utils";

export function BusinessSwitcher({
  businesses,
  compact = false,
}: {
  businesses: Business[];
  compact?: boolean;
}) {
  const router = useRouter();
  const { activeBusiness, setActiveBusiness } = useBusinessStore();
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function onClick(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        setOpen(false);
      }
    }
    document.addEventListener("mousedown", onClick);
    return () => document.removeEventListener("mousedown", onClick);
  }, []);

  async function switchTo(business: Business) {
    setActiveBusiness(business);
    setOpen(false);
    router.push(`/b/${business.slug}/dashboard`);
    router.refresh();
  }

  const current =
    businesses.find((b) => b.id === activeBusiness?.id) ??
    activeBusiness ??
    businesses[0];

  if (!current) return null;

  return (
    <div className="relative" ref={ref}>
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        className={cn(
          "flex items-center gap-2.5 rounded-2xl border border-[var(--border)] bg-white text-left shadow-sm transition hover:border-[var(--champagne)]/40",
          compact ? "h-10 px-2.5 sm:min-w-[180px] sm:px-3" : "min-w-[220px] px-3.5 py-2",
        )}
      >
        <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-xl bg-[var(--ink)] text-[var(--champagne-light)]">
          {current.business_type === "clothing" ? (
            <Shirt className="h-3.5 w-3.5" />
          ) : (
            <Car className="h-3.5 w-3.5" />
          )}
        </span>
        <div className={cn("min-w-0 flex-1", compact && "hidden sm:block")}>
          <p className="truncate text-[13px] font-semibold text-[var(--ink)]">
            {current.name}
          </p>
          {!compact && (
            <p className="truncate text-[11px] text-[var(--text-muted)]">
              {current.description ||
                (current.business_type === "clothing"
                  ? "Clothing Billing"
                  : "Car Billing")}
            </p>
          )}
          {compact && (
            <p className="truncate text-[10px] text-[var(--text-muted)]">
              Switch business
            </p>
          )}
        </div>
        <ChevronDown
          className={cn(
            "h-4 w-4 shrink-0 text-[var(--text-muted)] transition",
            open && "rotate-180",
          )}
        />
      </button>

      {open && (
        <div className="absolute right-0 z-50 mt-2 w-[300px] overflow-hidden rounded-2xl border border-[var(--border)] bg-white shadow-[0_28px_60px_-28px_rgba(12,15,20,0.55)]">
          <div className="border-b border-[var(--border)] bg-[var(--pearl)]/90 px-4 py-3">
            <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-[var(--champagne-deep)]">
              Switch Business
            </p>
            <p className="mt-1 text-xs text-[var(--text-muted)]">
              Data stays isolated per business
            </p>
          </div>
          <ul className="p-2">
            {businesses.map((b) => {
              const selected = b.id === current.id;
              return (
                <li key={b.id}>
                  <button
                    type="button"
                    onClick={() => switchTo(b)}
                    className={cn(
                      "flex w-full items-start gap-3 rounded-xl px-3 py-3 text-left transition",
                      selected
                        ? "bg-[var(--ink)] text-white"
                        : "hover:bg-[var(--pearl)]",
                    )}
                  >
                    <span
                      className={cn(
                        "mt-0.5 flex h-9 w-9 items-center justify-center rounded-xl",
                        selected
                          ? "bg-[var(--champagne)]/20 text-[var(--champagne-light)]"
                          : "bg-[var(--ink)]/5 text-[var(--ink)]",
                      )}
                    >
                      {b.business_type === "clothing" ? (
                        <Shirt className="h-4 w-4" />
                      ) : (
                        <Car className="h-4 w-4" />
                      )}
                    </span>
                    <span className="flex-1">
                      <span
                        className={cn(
                          "block text-sm font-semibold",
                          selected ? "text-white" : "text-[var(--ink)]",
                        )}
                      >
                        {b.name}
                      </span>
                      <span
                        className={cn(
                          "block text-xs",
                          selected
                            ? "text-white/55"
                            : "text-[var(--text-muted)]",
                        )}
                      >
                        {b.description ||
                          (b.business_type === "clothing"
                            ? "Clothing Billing"
                            : "Car Billing")}
                      </span>
                    </span>
                    {selected && (
                      <Check className="mt-1 h-4 w-4 text-[var(--champagne-light)]" />
                    )}
                  </button>
                </li>
              );
            })}
          </ul>
        </div>
      )}
    </div>
  );
}
