"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Eye, EyeOff, Shirt, Car, X } from "lucide-react";
import { clearClientSessionCookies } from "@/lib/auth/session-cookies";
import {
  DEMO_BUSINESS_COOKIE,
  DEMO_BUSINESSES,
  DEMO_COOKIE,
  DEMO_MODE,
  getBusinessLogin,
} from "@/lib/demo/data";
import { createClient } from "@/lib/supabase/client";
import { useBusinessStore } from "@/hooks/use-business-store";
import { Spinner, LoadingOverlay } from "@/components/ui/spinner";
import { cn } from "@/lib/utils";
import type { Business } from "@/types";

export function LoginForm({ compact = false }: { compact?: boolean }) {
  const router = useRouter();
  const setActiveBusiness = useBusinessStore((s) => s.setActiveBusiness);
  const [selectedSlug, setSelectedSlug] = useState<string>(
    DEMO_BUSINESSES[0].slug,
  );
  const initialLogin = getBusinessLogin(DEMO_BUSINESSES[0].slug);
  const [email, setEmail] = useState(initialLogin.email);
  const [password, setPassword] = useState(
    DEMO_MODE ? initialLogin.password : "",
  );
  const [showPassword, setShowPassword] = useState(false);
  const [remember, setRemember] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const [forgotOpen, setForgotOpen] = useState(false);
  const [forgotEmail, setForgotEmail] = useState("");
  const [forgotLoading, setForgotLoading] = useState(false);
  const [forgotSent, setForgotSent] = useState(false);
  const [forgotError, setForgotError] = useState<string | null>(null);

  const selectedBusiness =
    DEMO_BUSINESSES.find((b) => b.slug === selectedSlug) || DEMO_BUSINESSES[0];

  const isClothing = selectedBusiness.business_type === "clothing";

  useEffect(() => {
    if (!DEMO_MODE) {
      clearClientSessionCookies({ keepBusinessLock: false });
    }
  }, []);

  useEffect(() => {
    const creds = getBusinessLogin(selectedSlug);
    setEmail(creds.email);
    if (DEMO_MODE) setPassword(creds.password);
  }, [selectedSlug]);

  function openForgot() {
    setForgotEmail(email.trim());
    setForgotSent(false);
    setForgotError(null);
    setForgotOpen(true);
  }

  function closeForgot() {
    setForgotOpen(false);
    setForgotLoading(false);
    setForgotError(null);
  }

  async function onForgotSubmit(e: React.FormEvent) {
    e.preventDefault();
    setForgotLoading(true);
    setForgotError(null);

    if (DEMO_MODE) {
      setForgotLoading(false);
      setForgotSent(true);
      return;
    }

    const supabase = createClient();
    const { error: resetError } = await supabase.auth.resetPasswordForEmail(
      forgotEmail.trim(),
      {
        redirectTo: `${window.location.origin}/auth/callback?next=/update-password`,
      },
    );
    setForgotLoading(false);

    if (resetError) {
      const msg = resetError.message.toLowerCase();
      if (
        resetError.status === 429 ||
        msg.includes("rate limit") ||
        msg.includes("over_email")
      ) {
        setForgotError(
          "Too many reset emails sent. Wait about 1 hour, or check spam for an earlier mail.",
        );
      } else {
        setForgotError(resetError.message);
      }
      return;
    }

    setForgotSent(true);
  }

  function lockSession(business: Business, maxAge: number) {
    document.cookie = `${DEMO_COOKIE}=1; path=/; max-age=${maxAge}; SameSite=Lax`;
    document.cookie = `${DEMO_BUSINESS_COOKIE}=${business.slug}; path=/; max-age=${maxAge}; SameSite=Lax`;
    localStorage.setItem("billing_locked_business", business.slug);
    setActiveBusiness(business);
  }

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);

    const maxAge = remember ? 60 * 60 * 24 * 30 : 60 * 60 * 12;

    try {
      if (!selectedSlug) {
        setError("Please select a business to login");
        return;
      }

      if (DEMO_MODE) {
        const expected = getBusinessLogin(selectedSlug);
        const ok =
          email.trim().toLowerCase() === expected.email.toLowerCase() &&
          password === expected.password;

        if (!ok) {
          setError(`Use ${expected.email} for ${selectedBusiness.name}`);
          return;
        }

        lockSession(selectedBusiness, maxAge);
        router.push(`/b/${selectedBusiness.slug}/dashboard`);
        return;
      }

      clearClientSessionCookies({ keepBusinessLock: false });

      const supabase = createClient();

      const { error: signInError } = await supabase.auth.signInWithPassword({
        email: email.trim(),
        password,
      });

      if (signInError) {
        setError(signInError.message);
        return;
      }

      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (user) {
        void supabase
          .from("profiles")
          .update({ remember_session: remember })
          .eq("id", user.id);

        const { data: membership } = await supabase
          .from("business_users")
          .select("id, businesses!inner(slug)")
          .eq("user_id", user.id)
          .eq("is_active", true)
          .eq("businesses.slug", selectedBusiness.slug)
          .maybeSingle();

        if (!membership) {
          await supabase.auth.signOut();
          setError(`No access to ${selectedBusiness.name}`);
          return;
        }
      }

      document.cookie = `${DEMO_BUSINESS_COOKIE}=${selectedBusiness.slug}; path=/; max-age=${maxAge}; SameSite=Lax`;
      localStorage.setItem("billing_locked_business", selectedBusiness.slug);
      setActiveBusiness(selectedBusiness);

      router.push(`/b/${selectedBusiness.slug}/dashboard`);
    } catch {
      setError("Unable to sign in. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  const fieldClass =
    "flex h-10 w-full rounded-lg border border-slate-200 bg-slate-50/80 px-3 text-sm text-slate-900 placeholder:text-slate-400 outline-none transition focus:border-slate-400 focus:bg-white focus:ring-2 focus:ring-slate-100";

  return (
    <>
      <LoadingOverlay show={loading} label="Signing in…" />
      <form
        onSubmit={onSubmit}
        className={cn(compact ? "space-y-3.5" : "space-y-4")}
      >
        <div className="space-y-1.5">
          <label className="text-xs font-medium text-slate-600">Business</label>
          <div className="grid grid-cols-2 gap-2">
            {DEMO_BUSINESSES.map((b) => {
              const active = selectedSlug === b.slug;
              const clothing = b.business_type === "clothing";
              return (
                <button
                  key={b.id}
                  type="button"
                  onClick={() => setSelectedSlug(b.slug)}
                  className={cn(
                    "flex items-center gap-2 rounded-xl border px-2.5 py-2.5 text-left transition",
                    active &&
                      clothing &&
                      "border-brand bg-brand-soft ring-2 ring-brand-border/70",
                    active &&
                      !clothing &&
                      "border-blue-500 bg-blue-50 ring-2 ring-blue-200/70",
                    !active &&
                      "border-slate-200 bg-white hover:border-slate-300 hover:bg-slate-50",
                  )}
                >
                  <span
                    className={cn(
                      "relative flex h-9 w-9 shrink-0 items-center justify-center overflow-hidden",
                      clothing
                        ? "rounded-full bg-white"
                        : "rounded-lg bg-blue-100 text-blue-700",
                    )}
                  >
                    {clothing && b.logo_url ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img
                        src={b.logo_url}
                        alt={b.name}
                        className="h-full w-full rounded-full object-cover object-[center_12%]"
                      />
                    ) : clothing ? (
                      <Shirt className="h-3.5 w-3.5 text-brand-ink" />
                    ) : (
                      <Car className="h-3.5 w-3.5" />
                    )}
                  </span>
                  <span className="min-w-0">
                    <span className="block truncate text-xs font-semibold text-slate-900">
                      {b.name}
                    </span>
                    <span
                      className={cn(
                        "block truncate text-[10px] font-medium",
                        clothing ? "text-brand-ink" : "text-blue-700",
                      )}
                    >
                      {clothing ? "Clothing" : "Cars"}
                    </span>
                  </span>
                </button>
              );
            })}
          </div>
        </div>

        <div className="space-y-1.5">
          <label className="text-xs font-medium text-slate-600" htmlFor="email">
            Email
          </label>
          <input
            id="email"
            type="email"
            autoComplete="email"
            required
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="you@business.com"
            className={fieldClass}
          />
        </div>

        <div className="relative space-y-1.5">
          <label
            className="text-xs font-medium text-slate-600"
            htmlFor="password"
          >
            Password
          </label>
          <input
            id="password"
            type={showPassword ? "text" : "password"}
            autoComplete="current-password"
            required
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            placeholder="Enter password"
            className={cn(fieldClass, "pr-10")}
          />
          <button
            type="button"
            onClick={() => setShowPassword((v) => !v)}
            className="absolute right-2 top-[1.85rem] rounded-md p-1.5 text-slate-400 hover:bg-slate-100 hover:text-slate-700"
            aria-label={showPassword ? "Hide password" : "Show password"}
          >
            {showPassword ? (
              <EyeOff className="h-3.5 w-3.5" />
            ) : (
              <Eye className="h-3.5 w-3.5" />
            )}
          </button>
        </div>

        <div className="flex items-center justify-between gap-3">
          <label className="flex cursor-pointer items-center gap-2 text-xs text-slate-600">
            <input
              type="checkbox"
              checked={remember}
              onChange={(e) => setRemember(e.target.checked)}
              className="h-3.5 w-3.5 rounded border-slate-300"
            />
            Remember session
          </label>
          <button
            type="button"
            onClick={openForgot}
            className="shrink-0 text-xs font-semibold text-slate-700 underline-offset-2 hover:text-slate-900 hover:underline"
          >
            Forgot password?
          </button>
        </div>

        {error && (
          <div className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-700">
            {error}
          </div>
        )}

        <button
          type="submit"
          disabled={loading}
          className={cn(
            "inline-flex h-10 w-full items-center justify-center gap-2 rounded-lg text-sm font-semibold text-white transition disabled:opacity-60",
            isClothing
              ? "bg-brand hover:bg-brand-dark"
              : "bg-blue-600 hover:bg-blue-700",
          )}
        >
          {loading ? <Spinner className="h-3.5 w-3.5 text-white" /> : null}
          {loading ? "Signing in…" : `Login to ${selectedBusiness.name}`}
        </button>
      </form>

      {forgotOpen ? (
        <div className="fixed inset-0 z-[80] flex items-center justify-center p-4">
          <button
            type="button"
            className="absolute inset-0 bg-slate-900/45 backdrop-blur-[2px]"
            aria-label="Close"
            onClick={closeForgot}
          />
          <div
            role="dialog"
            aria-modal="true"
            aria-labelledby="forgot-title"
            className="relative z-10 w-full max-w-[400px] rounded-2xl bg-white p-5 shadow-[0_24px_64px_-20px_rgba(15,23,42,0.45)] ring-1 ring-slate-200/80 sm:p-6"
          >
            <div className="mb-4 flex items-start justify-between gap-3">
              <div>
                <h2
                  id="forgot-title"
                  className="text-lg font-semibold text-slate-900"
                >
                  Forgot password
                </h2>
                <p className="mt-1 text-sm text-slate-500">
                  We&apos;ll email you a reset link.
                </p>
              </div>
              <button
                type="button"
                onClick={closeForgot}
                className="rounded-lg p-1.5 text-slate-400 transition hover:bg-slate-100 hover:text-slate-700"
                aria-label="Close dialog"
              >
                <X className="h-4 w-4" />
              </button>
            </div>

            {forgotSent ? (
              <div className="space-y-4">
                <p className="rounded-xl border border-emerald-200 bg-emerald-50 px-3.5 py-3 text-sm text-emerald-800">
                  Check your inbox for the reset link. It may take a minute -
                  also check Spam.
                </p>
                <button
                  type="button"
                  onClick={closeForgot}
                  className={cn(
                    "inline-flex h-10 w-full items-center justify-center rounded-lg text-sm font-semibold text-white transition",
                    isClothing
                      ? "bg-brand hover:bg-brand-dark"
                      : "bg-blue-600 hover:bg-blue-700",
                  )}
                >
                  Back to login
                </button>
              </div>
            ) : (
              <form onSubmit={onForgotSubmit} className="space-y-3.5">
                <div className="space-y-1.5">
                  <label
                    className="text-xs font-medium text-slate-600"
                    htmlFor="forgot-email"
                  >
                    Email
                  </label>
                  <input
                    id="forgot-email"
                    type="email"
                    required
                    autoFocus
                    value={forgotEmail}
                    onChange={(e) => setForgotEmail(e.target.value)}
                    placeholder="you@business.com"
                    autoComplete="email"
                    className={fieldClass}
                  />
                </div>

                {forgotError && (
                  <p className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-700">
                    {forgotError}
                  </p>
                )}

                <div className="flex gap-2 pt-1">
                  <button
                    type="button"
                    onClick={closeForgot}
                    className="inline-flex h-10 flex-1 items-center justify-center rounded-lg border border-slate-200 bg-white text-sm font-medium text-slate-700 transition hover:bg-slate-50"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={forgotLoading}
                    className={cn(
                      "inline-flex h-10 flex-[1.4] items-center justify-center gap-2 rounded-lg text-sm font-semibold text-white transition disabled:opacity-60",
                      isClothing
                        ? "bg-brand hover:bg-brand-dark"
                        : "bg-blue-600 hover:bg-blue-700",
                    )}
                  >
                    {forgotLoading ? (
                      <Spinner className="h-3.5 w-3.5 text-white" />
                    ) : null}
                    {forgotLoading ? "Sending…" : "Send reset link"}
                  </button>
                </div>
              </form>
            )}
          </div>
        </div>
      ) : null}
    </>
  );
}
