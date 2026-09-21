"use client";

import { useEffect, useState } from "react";
import { Eye, EyeOff } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { DEMO_MODE } from "@/lib/demo/data";
import { Button } from "@/components/ui/button";
import { LoadingOverlay } from "@/components/ui/spinner";
import { Field, PageHeader, fieldClass } from "@/components/ui/side-panel";
import type { Business } from "@/types";

export function LoginAccountSettings({ business }: { business: Business }) {
  const [loginEmail, setLoginEmail] = useState("");
  const [newEmail, setNewEmail] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [showNew, setShowNew] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function load() {
      if (DEMO_MODE) {
        setLoginEmail(
          business.slug === "your-dream-cars"
            ? "yourdreamcars1806@gmail.com"
            : "drapedream@gmail.com",
        );
        return;
      }
      const supabase = createClient();
      const {
        data: { user },
      } = await supabase.auth.getUser();
      setLoginEmail(user?.email || "");
    }
    load();
  }, [business.slug]);

  async function updateEmail() {
    setSaving(true);
    setError(null);
    setMessage(null);

    const trimmed = newEmail.trim();
    if (!trimmed || !trimmed.includes("@")) {
      setError("Enter a valid email address");
      setSaving(false);
      return;
    }

    if (DEMO_MODE) {
      setLoginEmail(trimmed);
      setNewEmail("");
      setSaving(false);
      setMessage("Demo: login email updated locally");
      return;
    }

    const supabase = createClient();
    const { error: updateError } = await supabase.auth.updateUser({
      email: trimmed,
    });
    setSaving(false);
    if (updateError) {
      setError(updateError.message);
      return;
    }
    setMessage(
      "Confirmation sent to your new email. Click the link to finish changing email.",
    );
    setNewEmail("");
  }

  async function updatePassword() {
    setSaving(true);
    setError(null);
    setMessage(null);

    if (newPassword.length < 6) {
      setError("Password must be at least 6 characters");
      setSaving(false);
      return;
    }
    if (newPassword !== confirmPassword) {
      setError("Passwords do not match");
      setSaving(false);
      return;
    }

    if (DEMO_MODE) {
      setNewPassword("");
      setConfirmPassword("");
      setSaving(false);
      setMessage("Demo: password updated locally");
      return;
    }

    const supabase = createClient();
    const { error: updateError } = await supabase.auth.updateUser({
      password: newPassword,
    });
    setSaving(false);
    if (updateError) {
      setError(updateError.message);
      return;
    }
    setMessage("Password updated successfully");
    setNewPassword("");
    setConfirmPassword("");
  }

  return (
    <div className="space-y-5 border border-slate-200 bg-white p-5">
      <LoadingOverlay show={saving} label="Updating account…" />
      <PageHeader
        title="Change password"
        description={`Sign-in email & password for ${business.name}`}
      />

      {(message || error) && (
        <div
          className={`border px-3 py-2 text-sm ${
            error
              ? "border-red-200 bg-red-50 text-red-700"
              : "border-emerald-200 bg-emerald-50 text-emerald-800"
          }`}
        >
          {error || message}
        </div>
      )}

      <div className="border border-slate-100 bg-slate-50 px-4 py-3">
        <p className="text-[11px] font-semibold uppercase tracking-[0.1em] text-slate-400">
          Current login email
        </p>
        <p className="mt-1 text-sm font-medium text-slate-900">
          {loginEmail || "-"}
        </p>
      </div>

      <div className="grid gap-5 lg:grid-cols-2">
        <div className="space-y-3 border border-slate-200 bg-white p-4 shadow-sm">
          <p className="text-sm font-semibold text-slate-900">Change password</p>
          <p className="text-xs text-slate-500">
            New password will apply the next time you sign in.
          </p>
          <Field label="New password">
            <div className="relative">
              <input
                className={`${fieldClass} pr-10`}
                type={showNew ? "text" : "password"}
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                placeholder="Min 6 characters"
                autoComplete="new-password"
              />
              <button
                type="button"
                className="absolute right-2 top-1/2 -translate-y-1/2 rounded p-1 text-slate-400 hover:text-slate-700"
                onClick={() => setShowNew((v) => !v)}
                aria-label={showNew ? "Hide password" : "Show password"}
              >
                {showNew ? (
                  <EyeOff className="h-4 w-4" />
                ) : (
                  <Eye className="h-4 w-4" />
                )}
              </button>
            </div>
          </Field>
          <Field label="Confirm password">
            <div className="relative">
              <input
                className={`${fieldClass} pr-10`}
                type={showConfirm ? "text" : "password"}
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                placeholder="Re-enter password"
                autoComplete="new-password"
              />
              <button
                type="button"
                className="absolute right-2 top-1/2 -translate-y-1/2 rounded p-1 text-slate-400 hover:text-slate-700"
                onClick={() => setShowConfirm((v) => !v)}
                aria-label={
                  showConfirm ? "Hide password" : "Show password"
                }
              >
                {showConfirm ? (
                  <EyeOff className="h-4 w-4" />
                ) : (
                  <Eye className="h-4 w-4" />
                )}
              </button>
            </div>
          </Field>
          <Button
            type="button"
            size="md"
            loading={saving}
            onClick={updatePassword}
          >
            Update password
          </Button>
        </div>

        <div className="space-y-3 border border-slate-100 p-4">
          <p className="text-sm font-medium text-slate-900">Change email</p>
          <Field label="New email">
            <input
              className={fieldClass}
              type="email"
              value={newEmail}
              onChange={(e) => setNewEmail(e.target.value)}
              placeholder="newemail@gmail.com"
            />
          </Field>
          <Button type="button" size="sm" loading={saving} onClick={updateEmail}>
            Update email
          </Button>
        </div>
      </div>
    </div>
  );
}
