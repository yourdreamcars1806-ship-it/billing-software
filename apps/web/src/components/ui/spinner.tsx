import { cn } from "@/lib/utils";

export function Spinner({
  className,
}: {
  className?: string;
}) {
  return (
    <span
      aria-hidden
      className={cn(
        "inline-block h-4 w-4 shrink-0 animate-spin rounded-full border-2 border-current border-r-transparent",
        className,
      )}
    />
  );
}

/** Full-screen loader so user knows click registered */
export function LoadingOverlay({
  show,
  label = "Please wait…",
}: {
  show: boolean;
  label?: string;
}) {
  if (!show) return null;

  return (
    <div className="fixed inset-0 z-[200] flex items-center justify-center bg-slate-900/30 backdrop-blur-[1px]">
      <div className="flex min-w-[180px] items-center gap-3 rounded-xl border border-slate-200 bg-white px-5 py-4 shadow-xl">
        <Spinner className="h-5 w-5 text-slate-800" />
        <p className="text-sm font-semibold text-slate-800">{label}</p>
      </div>
    </div>
  );
}
