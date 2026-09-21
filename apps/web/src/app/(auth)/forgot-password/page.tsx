"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Suspense, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { DEMO_MODE } from "@/lib/demo/data";
import { Spinner } from "@/components/ui/spinner";

function ForgotPasswordForm() {
  const searchParams = useSearchParams();
  const [email, setEmail] = useState(
    () => searchParams.get("email")?.trim() || "",
  );
  const [sent, setSent] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);

    if (DEMO_MODE) {
      setLoading(false);
      setSent(true);
      return;
    }

    const supabase = createClient();
    const { error: resetError } = await supabase.auth.resetPasswordForEmail(
      email.trim(),
      {
        redirectTo: `${window.location.origin}/auth/callback?next=/update-password`,
      },
    );
    setLoading(false);
    if (resetError) {
      setError(resetError.message);
      return;
    }
    setSent(true);
  }

  const fieldClass =
    "flex h-10 w-full rounded-lg border border-slate-200 bg-slate-50/80 px-3 text-sm text-slate-900 outline-none transition focus:border-slate-400 focus:bg-white focus:ring-2 focus:ring-slate-100";

  return (
    <div className="w-full max-w-[380px] rounded-2xl bg-white p-5 shadow-[0_2px_8px_rgba(15,23,42,0.04),0_24px_48px_-24px_rgba(15,23,42,0.22)] ring-1 ring-slate-200/80 sm:p-6">
      <h1 className="text-lg font-semibold text-slate-900">Forgot password</h1>
      <p className="mt-1 text-sm text-slate-500">
        Enter your login email and we&apos;ll send a reset link.
      </p>

      {sent ? (
        <div className="mt-5 space-y-3">
          <p className="rounded-lg border border-emerald-200 bg-emerald-50 px-3 py-2 text-xs text-emerald-800">
            Check your inbox for the reset link. It may take a minute.
          </p>
          <Link
            href="/login"
            className="text-xs font-semibold text-slate-700 underline-offset-2 hover:underline"
          >
            Back to login
          </Link>
        </div>
      ) : (
        <form onSubmit={onSubmit} className="mt-5 space-y-3.5">
          <div className="space-y-1.5">
            <label
              className="text-xs font-medium text-slate-600"
              htmlFor="reset-email"
            >
              Email
            </label>
            <input
              id="reset-email"
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="you@business.com"
              autoComplete="email"
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
            {loading ? "Sending…" : "Send reset link"}
          </button>
        </form>
      )}
    </div>
  );
}

export default function ForgotPasswordPage() {
  return (
    <div className="flex min-h-screen flex-col bg-[#eef0f3]">
      <header className="border-b border-slate-200/90 bg-white">
        <div className="mx-auto flex h-14 max-w-5xl items-center justify-between px-4 sm:px-6">
          <Link href="/login" className="flex items-center gap-2.5">
            <span className="flex h-8 w-8 items-center justify-center rounded-md bg-slate-900 text-[11px] font-bold text-white">
              BA
            </span>
            <p className="text-sm font-semibold text-slate-900">
              Billing Atelier
            </p>
          </Link>
          <Link
            href="/login"
            className="rounded-lg px-3 py-1.5 text-xs font-semibold text-slate-600 hover:bg-slate-50 hover:text-slate-900"
          >
            Back to login
          </Link>
        </div>
      </header>

      <main className="flex flex-1 items-center justify-center px-4 py-8">
        <Suspense
          fallback={
            <div className="text-sm text-slate-500">Loading…</div>
          }
        >
          <ForgotPasswordForm />
        </Suspense>
      </main>
    </div>
  );
}
