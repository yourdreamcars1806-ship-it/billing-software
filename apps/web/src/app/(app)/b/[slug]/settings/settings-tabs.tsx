"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { KeyRound, Building2, Receipt, MessageCircle } from "lucide-react";
import { cn } from "@/lib/utils";

const TABS = [
  {
    href: "login-account",
    label: "Change password",
    icon: KeyRound,
  },
  {
    href: "business-profile",
    label: "Business profile",
    icon: Building2,
  },
  {
    href: "invoice-tax",
    label: "Invoice & tax",
    icon: Receipt,
  },
  {
    href: "whatsapp",
    label: "WhatsApp",
    icon: MessageCircle,
  },
] as const;

export function SettingsTabs({ slug }: { slug: string }) {
  const pathname = usePathname();

  return (
    <div className="mb-5 overflow-x-auto border-b border-slate-200">
      <nav className="flex min-w-max gap-1 pb-px">
        {TABS.map((tab) => {
          const href = `/b/${slug}/settings/${tab.href}`;
          const active = pathname.includes(`/settings/${tab.href}`);
          const Icon = tab.icon;
          return (
            <Link
              key={tab.href}
              href={href}
              className={cn(
                "inline-flex items-center gap-1.5 border-b-2 px-3 py-2.5 text-sm font-medium transition",
                active
                  ? "border-[var(--brand)] text-slate-900"
                  : "border-transparent text-slate-500 hover:border-slate-200 hover:text-slate-800",
              )}
            >
              <Icon className="h-3.5 w-3.5 shrink-0" />
              {tab.label}
            </Link>
          );
        })}
      </nav>
    </div>
  );
}
