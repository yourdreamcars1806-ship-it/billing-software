"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Eye, EyeOff } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { DEMO_MODE } from "@/lib/demo/data";
import { Spinner } from "@/components/ui/spinner";

export default function UpdatePasswordPage() {
  const router = useRouter();
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [show, setShow] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);

    if (password.length < 8) {
      setError("Password must be at least 8 characters");
      return;
    }
    if (password !== confirm) {
      setError("Passwords do not match");
      return;
    }

    setLoading(true);
    try {
      if (DEMO_MODE) {
        router.push("/login");
        return;
      }

      const supabase = createClient();
      const { error: updateError } = await supabase.auth.updateUser({
        password,
      });
      if (updateError) {
        setError(updateError.message);
        return;
      }
      router.push("/login");
    } catch {
      setError("Unable to update password. Try the reset link again.");
    } finally {
      setLoading(false);
    }
  }

  const fieldClass =
    "flex h-10 w-full rounded-lg border border-slate-200 bg-slate-50/80 px-3 text-sm text-slate-900 outline-none transition focus:border-slate-400 focus:bg-white focus:ring-2 focus:ring-slate-100";

  return (
    <div className="flex min-h-screen flex-col bg-[#eef0f3]">
      <header className="border-b border-slate-200/90 bg-white">
        <div className="mx-auto flex h-14 max-w-5xl items-center px-4 sm:px-6">
          <Link href="/login" className="flex items-center gap-2.5">
            <span className="flex h-8 w-8 items-center justify-center rounded-md bg-slate-900 text-[11px] font-bold text-white">
              BA
            </span>
            <p className="text-sm font-semibold text-slate-900">
              Billing Atelier
            </p>
          </Link>
        </div>
      </header>

      <main className="flex flex-1 items-center justify-center px-4 py-8">
        <div className="w-full max-w-[380px] rounded-2xl bg-white p-5 shadow-[0_2px_8px_rgba(15,23,42,0.04),0_24px_48px_-24px_rgba(15,23,42,0.22)] ring-1 ring-slate-200/80 sm:p-6">
          <h1 className="text-lg font-semibold text-slate-900">
            Set new password
          </h1>
          <p className="mt-1 text-sm text-slate-500">
            Choose a new password for your account.
          </p>

          <form onSubmit={onSubmit} className="mt-5 space-y-3.5">
            <div className="relative space-y-1.5">
              <label className="text-xs font-medium text-slate-600">
                New password
              </label>
              <input
                type={show ? "text" : "password"}
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                autoComplete="new-password"
                className={`${fieldClass} pr-10`}
              />
              <button
                type="button"
                onClick={() => setShow((v) => !v)}
                className="absolute right-2 top-[1.85rem] rounded-md p-1.5 text-slate-400 hover:bg-slate-100 hover:text-slate-700"
                aria-label={show ? "Hide password" : "Show password"}
              >
                {show ? (
                  <EyeOff className="h-3.5 w-3.5" />
                ) : (
                  <Eye className="h-3.5 w-3.5" />
                )}
              </button>
            </div>

            <div className="space-y-1.5">
              <label className="text-xs font-medium text-slate-600">
                Confirm password
              </label>
              <input
                type={show ? "text" : "password"}
                required
                value={confirm}
                onChange={(e) => setConfirm(e.target.value)}
                autoComplete="new-password"
                className={fieldClass}
              />
            </div>

            {error && (
              <p className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-700">
                {error}
              </p>
            )}

            <button
              type="submit"
              disabled={loading}
              className="inline-flex h-10 w-full items-center justify-center gap-2 rounded-lg bg-slate-900 text-sm font-semibold text-white transition hover:bg-slate-800 disabled:opacity-60"
            >
              {loading ? <Spinner className="h-3.5 w-3.5 text-white" /> : null}
              {loading ? "Saving…" : "Update password"}
            </button>
          </form>
        </div>
      </main>
    </div>
  );
}
