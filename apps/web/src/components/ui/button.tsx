import { cn } from "@/lib/utils";
import { Spinner } from "@/components/ui/spinner";

export function Button({
  className,
  variant = "primary",
  size = "md",
  loading = false,
  children,
  disabled,
  ...props
}: React.ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: "primary" | "secondary" | "ghost" | "danger" | "outline";
  size?: "sm" | "md" | "lg";
  loading?: boolean;
}) {
  return (
    <button
      className={cn(
        "inline-flex items-center justify-center gap-2 rounded-lg font-semibold transition disabled:pointer-events-none disabled:opacity-50",
        variant === "primary" && "btn-brand shadow-sm",
        variant === "secondary" &&
          "bg-slate-100 text-slate-900 hover:bg-slate-200",
        variant === "ghost" && "text-slate-600 hover:bg-slate-100",
        variant === "danger" && "bg-red-600 text-white hover:bg-red-700",
        variant === "outline" &&
          "border border-slate-200 bg-white text-slate-800 hover:bg-slate-50",
        size === "sm" && "h-8 px-3 text-xs",
        size === "md" && "h-9 px-4 text-sm",
        size === "lg" && "h-10 px-5 text-sm",
        className,
      )}
      disabled={disabled || loading}
      aria-busy={loading || undefined}
      {...props}
    >
      {loading ? <Spinner className="h-3.5 w-3.5" /> : null}
      {children}
    </button>
  );
}
