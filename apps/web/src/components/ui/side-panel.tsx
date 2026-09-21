"use client";

import { X } from "lucide-react";

export function SidePanel({
  open,
  onClose,
  eyebrow,
  title,
  description,
  children,
  footer,
  widthClass = "max-w-[420px]",
}: {
  open: boolean;
  onClose: () => void;
  eyebrow?: string;
  title: string;
  description?: string;
  children: React.ReactNode;
  footer?: React.ReactNode;
  widthClass?: string;
}) {
  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50 flex justify-end">
      <button
        type="button"
        className="absolute inset-0 bg-slate-900/35"
        aria-label="Close panel"
        onClick={onClose}
      />
      <aside
        className={`relative z-10 flex h-full w-full flex-col bg-white shadow-2xl ${widthClass}`}
      >
        <div className="flex items-start justify-between border-b border-slate-200 px-6 py-5">
          <div className="pr-4">
            {eyebrow ? (
              <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-brand-ink">
                {eyebrow}
              </p>
            ) : null}
            <h2 className="mt-1 text-lg font-semibold text-slate-900">{title}</h2>
            {description ? (
              <p className="mt-1 text-sm text-slate-500">{description}</p>
            ) : null}
          </div>
          <button
            type="button"
            onClick={onClose}
            className="rounded-md p-2 text-slate-400 hover:bg-slate-100 hover:text-slate-800"
          >
            <X className="h-4 w-4" />
          </button>
        </div>
        <div className="flex-1 overflow-y-auto px-6 py-6">{children}</div>
        {footer ? (
          <div className="border-t border-slate-200 bg-white px-6 py-4">
            {footer}
          </div>
        ) : null}
      </aside>
    </div>
  );
}

export const fieldClass =
  "mt-1.5 h-10 w-full border border-slate-200 bg-white px-3 text-sm text-slate-900 outline-none transition placeholder:text-slate-400 focus:border-brand focus:ring-2 focus:ring-brand/15";

export const selectClass =
  "h-10 w-full border border-slate-200 bg-white px-3 text-sm text-slate-900 outline-none focus:border-brand focus:ring-2 focus:ring-brand/15";

export const searchClass =
  "h-9 w-full max-w-sm border border-slate-200 bg-white px-3 text-sm outline-none focus:border-brand focus:ring-2 focus:ring-brand/15";

export function Field({
  label,
  children,
  hint,
}: {
  label: string;
  children: React.ReactNode;
  hint?: string;
}) {
  return (
    <label className="block">
      <span className="text-[11px] font-semibold uppercase tracking-[0.12em] text-slate-500">
        {label}
      </span>
      {children}
      {hint ? <p className="mt-1 text-[11px] text-slate-400">{hint}</p> : null}
    </label>
  );
}

export function PageHeader({
  title,
  description,
  action,
}: {
  title: string;
  description?: string;
  action?: React.ReactNode;
}) {
  return (
    <div className="flex flex-col gap-3 border-b border-slate-200 pb-4 sm:flex-row sm:items-end sm:justify-between">
      <div>
        <h1 className="text-xl font-semibold tracking-tight text-slate-900">
          {title}
        </h1>
        {description ? (
          <p className="mt-0.5 text-sm text-slate-500">{description}</p>
        ) : null}
      </div>
      {action}
    </div>
  );
}

export function DataTableShell({ children }: { children: React.ReactNode }) {
  return (
    <div className="overflow-x-auto border border-slate-200 bg-white">
      {children}
    </div>
  );
}

export const thClass =
  "whitespace-nowrap px-3 py-2.5 text-[11px] font-semibold uppercase tracking-wider text-slate-500";

export const tdClass = "px-3 py-2.5 text-slate-700";
