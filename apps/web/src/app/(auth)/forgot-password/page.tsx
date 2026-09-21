"use client";

import Link from "next/link";
import { useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { Button } from "@/components/ui/button";

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState("");
  const [sent, setSent] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);

    if (process.env.NEXT_PUBLIC_DEMO_MODE === "true") {
      setLoading(false);
      setSent(true);
      return;
    }

    const supabase = createClient();
    const { error: resetError } = await supabase.auth.resetPasswordForEmail(
      email.trim(),
      { redirectTo: `${window.location.origin}/login` },
    );
    setLoading(false);
    if (resetError) {
      setError(resetError.message);
      return;
    }
    setSent(true);
  }

  return (
    <div className="app-canvas flex min-h-screen flex-col">
      <header className="sticky top-0 z-40 border-b border-[var(--border)] bg-white/85 backdrop-blur-xl">
        <div className="mx-auto flex h-14 max-w-5xl items-center justify-between px-4 sm:px-6">
          <Link href="/login" className="flex items-center gap-2.5">
            <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-gradient-to-br from-[var(--champagne-light)] to-[var(--champagne-deep)]">
              <span className="font-display text-sm font-semibold text-[var(--ink)]">
                BA
              </span>
            </span>
            <p className="text-sm font-semibold text-[var(--ink)]">
              Billing Atelier
            </p>
          </Link>
          <Link
            href="/login"
            className="rounded-lg px-3 py-1.5 text-xs font-semibold text-[var(--champagne-deep)] hover:bg-[var(--pearl)]"
          >
            Back to login
          </Link>
        </div>
      </header>

      <main className="flex flex-1 items-center justify-center px-4 py-8">
        <div className="w-full max-w-[380px] rounded-2xl border border-[var(--border)] bg-white p-5 shadow-[0_20px_50px_-32px_rgba(12,15,20,0.45)] sm:p-6">
          <h1 className="font-display text-2xl text-[var(--ink)]">
            Reset password
          </h1>
          <p className="mt-1 text-xs text-[var(--text-muted)]">
            We&apos;ll email you a reset link.
          </p>

          {sent ? (
            <div className="mt-4 space-y-3">
              <p className="rounded-lg border border-[var(--success)]/20 bg-[var(--success)]/[0.06] px-3 py-2 text-xs text-[var(--success)]">
                Check your inbox for the reset link.
              </p>
              <Link
                href="/login"
                className="text-xs font-medium text-[var(--champagne-deep)]"
              >
                Back to login
              </Link>
            </div>
          ) : (
            <form onSubmit={onSubmit} className="mt-4 space-y-3">
              <label className="block space-y-1">
                <span className="text-[10px] font-semibold uppercase tracking-[0.14em] text-[var(--text-muted)]">
                  Email
                </span>
                <input
                  type="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="flex h-10 w-full rounded-lg border border-[var(--border)] bg-[var(--pearl)]/80 px-3 text-sm outline-none focus:border-[var(--champagne)] focus:ring-2 focus:ring-[var(--champagne)]/15"
                />
              </label>
              {error && (
                <p className="text-xs text-[var(--danger)]">{error}</p>
              )}
              <Button type="submit" className="w-full" disabled={loading}>
                {loading ? "Sending…" : "Send reset link"}
              </Button>
            </form>
          )}
        </div>
      </main>
    </div>
  );
}
