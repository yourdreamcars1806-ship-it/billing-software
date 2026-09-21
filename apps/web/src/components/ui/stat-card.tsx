import { cn, formatMoney } from "@/lib/utils";

export function StatCard({
  label,
  value,
  hint,
  tone = "default",
}: {
  label: string;
  value: string | number;
  hint?: string;
  tone?: "default" | "success" | "warning" | "danger" | "info";
}) {
  const display = typeof value === "number" ? formatMoney(value) : value;

  return (
    <div className="border border-slate-200 bg-white p-4 transition hover:border-slate-300">
      <div className="flex items-center justify-between gap-2">
        <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-slate-500">
          {label}
        </p>
        <span
          className={cn(
            "h-1.5 w-1.5 rounded-full",
            tone === "default" && "bg-slate-300",
            tone === "info" && "bg-brand",
            tone === "success" && "bg-emerald-500",
            tone === "warning" && "bg-amber-500",
            tone === "danger" && "bg-red-500",
          )}
        />
      </div>
      <p className="mt-2.5 text-2xl font-bold tracking-tight text-slate-900 tabular-nums">
        {display}
      </p>
      {hint ? (
        <p className="mt-1.5 text-xs leading-snug text-slate-400">{hint}</p>
      ) : null}
    </div>
  );
}
