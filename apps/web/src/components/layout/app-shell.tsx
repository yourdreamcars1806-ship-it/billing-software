"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import {
  LayoutDashboard,
  Receipt,
  FileText,
  CreditCard,
  BarChart3,
  Settings,
  LogOut,
  Menu,
  X,
  Search,
  Shirt,
  Car,
  ScanBarcode,
  Plus,
  KeyRound,
} from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { clearClientSessionCookies } from "@/lib/auth/session-cookies";
import { createClient } from "@/lib/supabase/client";
import { DEMO_MODE } from "@/lib/demo/data";
import { BusinessSync } from "@/components/business/business-sync";
import { useBusinessStore } from "@/hooks/use-business-store";
import type { Business } from "@/types";
import { cn } from "@/lib/utils";

const NAV_ITEMS = [
  { href: "dashboard", label: "Dashboard", icon: LayoutDashboard },
  { href: "billing", label: "Billing", icon: Receipt },
  {
    href: "products",
    label: "Products",
    icon: ScanBarcode,
    clothingOnly: true,
  },
  { href: "invoices", label: "Invoices", icon: FileText },
  { href: "payments", label: "Payments", icon: CreditCard },
  { href: "reports", label: "Reports", icon: BarChart3 },
  { href: "settings", label: "Settings", icon: Settings },
] as const;

const PAGE_TITLES: Record<string, string> = {
  dashboard: "Dashboard",
  billing: "Create Invoice",
  products: "Products & Barcode",
  invoices: "Invoices",
  payments: "Payments",
  reports: "Reports",
  settings: "Settings",
  "login-account": "Change password",
  "business-profile": "Business profile",
  "invoice-tax": "Invoice & tax",
  whatsapp: "WhatsApp invoice",
};

function businessLogoSrc(business?: Business | null) {
  if (!business) return null;
  if (business.logo_url) return business.logo_url;
  if (business.slug === "drape-and-dream")
    return "/images/drape-and-dream-logo.png";
  if (business.slug === "your-dream-cars")
    return "/images/your-dream-cars-logo.png";
  return null;
}

export function AppShell({
  businesses,
  children,
}: {
  businesses: Business[];
  children: React.ReactNode;
  locked?: boolean;
}) {
  const pathname = usePathname();
  const router = useRouter();
  const { activeBusiness, clear } = useBusinessStore();
  const [mobileOpen, setMobileOpen] = useState(false);
  const [signedInEmail, setSignedInEmail] = useState<string | null>(null);

  useEffect(() => {
    if (DEMO_MODE) {
      const slug =
        businesses[0]?.slug ||
        activeBusiness?.slug ||
        pathname.split("/")[2] ||
        "drape-and-dream";
      setSignedInEmail(
        slug === "your-dream-cars"
          ? "yourdreamcars1806@gmail.com"
          : "drapedream@gmail.com",
      );
      return;
    }
    const supabase = createClient();
    supabase.auth.getUser().then(({ data }) => {
      setSignedInEmail(data.user?.email ?? null);
    });
  }, [businesses, activeBusiness?.slug, pathname]);

  const currentBusiness = businesses[0] || activeBusiness;
  const slug = currentBusiness?.slug || pathname.split("/")[2];
  const isCar = currentBusiness?.business_type === "car";
  const theme = isCar ? "car" : "clothing";
  const logoSrc = businessLogoSrc(currentBusiness);

  const currentSection = useMemo(() => {
    const parts = pathname.split("/");
    const section = parts[3] || "dashboard";
    if (section === "settings") {
      const sub = parts[4];
      return (sub && PAGE_TITLES[sub]) || "Settings";
    }
    if (section === "payments" && isCar) return "Tokens & payments";
    return PAGE_TITLES[section] || "Workspace";
  }, [pathname, isCar]);

  async function logout() {
    if (!DEMO_MODE) {
      const supabase = createClient();
      await supabase.auth.signOut();
    }
    clearClientSessionCookies();
    clear();
    router.push("/login");
    router.refresh();
  }

  function NavLink({
    href,
    label,
    icon: Icon,
    onNavigate,
  }: {
    href: string;
    label: string;
    icon: React.ComponentType<{ className?: string }>;
    onNavigate?: () => void;
  }) {
    const full = `/b/${slug}/${href}`;
    const active =
      href === "settings"
        ? pathname.startsWith(full)
        : pathname === full || pathname.startsWith(`${full}/`);
    return (
      <Link
        href={href === "settings" ? `${full}/login-account` : full}
        onClick={onNavigate}
        data-active={active}
        className="sidebar-nav-item"
      >
        <Icon className="sidebar-nav-icon" />
        <span className="truncate">{label}</span>
      </Link>
    );
  }

  function SidebarContent({ onNavigate }: { onNavigate?: () => void }) {
    const items = NAV_ITEMS.filter(
      (item) => !("clothingOnly" in item && item.clothingOnly) || !isCar,
    ).map((item) => ({
      ...item,
      label:
        item.href === "payments" && isCar ? "Tokens" : item.label,
    }));

    return (
      <div className="flex h-full min-h-0 flex-col overflow-hidden">
        {/* Brand — fixed */}
        <div className="shrink-0 border-b border-slate-200 px-3.5 pb-3.5 pt-4">
          <Link
            href={slug ? `/b/${slug}/dashboard` : "/login"}
            onClick={onNavigate}
            className="flex items-center gap-2.5"
          >
            <span
              className={cn(
                "relative flex h-9 w-9 shrink-0 items-center justify-center overflow-hidden text-xs font-bold text-white",
                logoSrc
                  ? "rounded-full bg-white ring-1 ring-[var(--brand-border)]"
                  : "rounded-lg bg-brand",
              )}
            >
              {logoSrc ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={logoSrc}
                  alt={currentBusiness?.name || "Logo"}
                  className="h-full w-full object-contain p-1"
                />
              ) : isCar ? (
                "YC"
              ) : (
                "DD"
              )}
            </span>
            <div className="min-w-0 flex-1">
              <p className="truncate text-[13px] font-semibold leading-tight text-slate-900">
                {currentBusiness?.name || "Billing"}
              </p>
              <p className="mt-0.5 truncate text-[10.5px] text-slate-500">
                {isCar ? "Automobile desk" : "Clothing desk"}
              </p>
            </div>
          </Link>

          <Link
            href={`/b/${slug}/billing`}
            onClick={onNavigate}
            className="sidebar-cta mt-3.5"
          >
            <Plus className="h-3.5 w-3.5" />
            New invoice
          </Link>
        </div>

        {/* Nav — no page scroll; overflow only if viewport is tiny */}
        <nav className="sidebar-nav min-h-0 flex-1 overflow-y-auto overflow-x-hidden px-2.5 py-3">
          <div className="space-y-0.5">
            {items.map((item) => (
              <NavLink
                key={item.href}
                href={item.href}
                label={item.label}
                icon={item.icon}
                onNavigate={onNavigate}
              />
            ))}
          </div>
        </nav>

        {/* Footer — fixed */}
        <div className="shrink-0 border-t border-slate-200 p-2.5">
          <div className="mb-2 flex items-center gap-2 rounded-lg bg-slate-50 px-2 py-2">
            <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-brand text-[10px] font-bold text-white">
              {(signedInEmail || "S").slice(0, 1).toUpperCase()}
            </span>
            <div className="min-w-0 flex-1">
              <p className="truncate text-[11px] font-medium text-slate-700">
                {signedInEmail || "Staff"}
              </p>
            </div>
          </div>
          <Link
            href={`/b/${slug}/settings/login-account`}
            onClick={onNavigate}
            className="mb-1.5 flex w-full items-center justify-center gap-1.5 rounded-lg border border-slate-200 bg-white px-2.5 py-1.5 text-xs font-medium text-slate-600 transition hover:bg-slate-50 hover:text-slate-900"
          >
            <KeyRound className="h-3.5 w-3.5" />
            Change password
          </Link>
          <button
            type="button"
            onClick={logout}
            className="flex w-full items-center justify-center gap-1.5 rounded-lg border border-slate-200 bg-white px-2.5 py-1.5 text-xs font-medium text-slate-600 transition hover:bg-slate-50 hover:text-slate-900"
          >
            <LogOut className="h-3.5 w-3.5" />
            Sign out
          </button>
        </div>
      </div>
    );
  }

  return (
    <div
      className="app-shell flex h-dvh overflow-hidden"
      data-theme={theme}
    >
      <BusinessSync businesses={businesses} />

      {/* Fixed-height sidebar — never scrolls with page */}
      <aside className="sidebar hidden h-dvh w-[232px] shrink-0 overflow-hidden lg:flex lg:flex-col">
        <SidebarContent />
      </aside>

      {mobileOpen && (
        <div className="fixed inset-0 z-50 lg:hidden">
          <button
            type="button"
            className="absolute inset-0 bg-slate-900/40"
            aria-label="Close menu"
            onClick={() => setMobileOpen(false)}
          />
          <aside className="sidebar absolute inset-y-0 left-0 flex h-dvh w-[272px] flex-col overflow-hidden shadow-xl">
            <button
              type="button"
              onClick={() => setMobileOpen(false)}
              className="absolute right-2.5 top-3 z-10 rounded-md p-2 text-slate-400 hover:bg-slate-100 hover:text-slate-700"
            >
              <X className="h-4 w-4" />
            </button>
            <SidebarContent onNavigate={() => setMobileOpen(false)} />
          </aside>
        </div>
      )}

      {/* Only this column scrolls */}
      <div className="flex min-h-0 min-w-0 flex-1 flex-col overflow-hidden">
        <header className="z-20 shrink-0 border-b border-slate-200 bg-white">
          <div className="flex h-14 items-center gap-3 px-4 sm:px-6">
            <button
              type="button"
              className="inline-flex h-9 w-9 items-center justify-center rounded-lg border border-slate-200 text-slate-500 hover:bg-slate-50 lg:hidden"
              onClick={() => setMobileOpen(true)}
              aria-label="Open menu"
            >
              <Menu className="h-4 w-4" />
            </button>

            <div className="min-w-0 flex-1">
              <h1 className="truncate text-[15px] font-semibold tracking-tight text-slate-900">
                {currentSection}
              </h1>
              <p className="truncate text-xs text-slate-500">
                {currentBusiness?.name}
              </p>
            </div>

            <div className="hidden max-w-xs flex-1 md:block lg:max-w-sm">
              <label className="relative block">
                <Search className="pointer-events-none absolute left-3 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-slate-400" />
                <input
                  type="search"
                  placeholder="Search invoices…"
                  className="h-9 w-full rounded-lg border border-slate-200 bg-slate-50 pl-9 pr-3 text-sm outline-none transition focus:border-slate-300 focus:bg-white focus:ring-2 focus:ring-slate-100"
                />
              </label>
            </div>

            {currentBusiness && (
              <div className="hidden items-center gap-2 rounded-full border border-slate-200 bg-white py-1 pl-1 pr-3 sm:flex">
                <span
                  className={cn(
                    "relative flex h-7 w-7 items-center justify-center overflow-hidden text-white",
                    logoSrc
                      ? "rounded-full bg-white ring-1 ring-slate-200"
                      : "rounded-full bg-brand",
                  )}
                >
                  {logoSrc ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={logoSrc}
                      alt=""
                      className="h-full w-full object-contain p-0.5"
                    />
                  ) : isCar ? (
                    <Car className="h-3.5 w-3.5" />
                  ) : (
                    <Shirt className="h-3.5 w-3.5" />
                  )}
                </span>
                <span className="max-w-[120px] truncate text-xs font-semibold text-slate-800">
                  {currentBusiness.name}
                </span>
              </div>
            )}
          </div>
        </header>

        <main className="min-h-0 flex-1 overflow-y-auto overflow-x-hidden px-4 py-5 sm:px-6 lg:px-8">
          <div className="mx-auto max-w-6xl pb-8">{children}</div>
        </main>
      </div>
    </div>
  );
}
