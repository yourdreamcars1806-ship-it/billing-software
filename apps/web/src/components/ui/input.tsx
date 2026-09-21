import { cn } from "@/lib/utils";

export function Input({
  className,
  label,
  error,
  ...props
}: React.InputHTMLAttributes<HTMLInputElement> & {
  label?: string;
  error?: string;
}) {
  return (
    <label className="block space-y-2">
      {label && (
        <span className="text-[11px] font-semibold uppercase tracking-[0.16em] text-[var(--text-muted)]">
          {label}
        </span>
      )}
      <input
        className={cn(
          "flex h-12 w-full rounded-xl border border-[var(--border)] bg-[var(--pearl)]/80 px-4 text-sm text-[var(--text)] placeholder:text-[#9aa1ab] transition focus:border-[var(--champagne)] focus:bg-white focus:outline-none focus:ring-4 focus:ring-[var(--champagne)]/15",
          error &&
            "border-[var(--danger)]/50 focus:border-[var(--danger)] focus:ring-[var(--danger)]/15",
          className,
        )}
        {...props}
      />
      {error && (
        <span className="text-xs text-[var(--danger)]">{error}</span>
      )}
    </label>
  );
}
