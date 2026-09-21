import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import {
  DEMO_MODE,
  getDemoBusiness,
  getDemoInvoices,
  getDemoStats,
} from "@/lib/demo/data";
import { StatCard } from "@/components/ui/stat-card";
import { formatDate, formatMoney } from "@/lib/utils";
import { paymentStatusLabel } from "@/lib/payment-status";
import type { Business, DashboardStats, Invoice } from "@/types";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { ArrowUpRight, Plus } from "lucide-react";
import { cn } from "@/lib/utils";

async function getBusiness(slug: string) {
  if (DEMO_MODE) return getDemoBusiness(slug) || null;

  const supabase = await createClient();
  const { data } = await supabase
    .from("businesses")
    .select("*")
    .eq("slug", slug)
    .maybeSingle();
  return data as Business | null;
}

export default async function DashboardPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const business = await getBusiness(slug);
  if (!business) notFound();

  let stats: DashboardStats;
  let invoices: Invoice[];

  if (DEMO_MODE) {
    stats = getDemoStats(business.id);
    invoices = getDemoInvoices(business.id);
  } else {
    const supabase = await createClient();

    const { data: statsRow } = await supabase
      .from("dashboard_stats")
      .select("*")
      .eq("business_id", business.id)
      .maybeSingle();

    stats = statsRow || {
      business_id: business.id,
      today_sales: 0,
      today_collection: 0,
      pending_amount: 0,
      total_invoices: 0,
      paid_invoices: 0,
      partial_invoices: 0,
      pending_invoices: 0,
    };

    const { data: recent } = await supabase
      .from("invoices")
      .select("*, customers(name)")
      .eq("business_id", business.id)
      .eq("status", "issued")
      .order("invoice_date", { ascending: false })
      .order("created_at", { ascending: false })
      .limit(8);

    invoices = (recent || []) as Invoice[];
  }

  const isCar = business.business_type === "car";

  return (
    <div className="w-full max-w-full space-y-6 overflow-x-hidden">
      <div className="flex flex-wrap items-end justify-between gap-4 border-b border-slate-200 pb-5">
        <div className="min-w-0">
          <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-brand-ink">
            {isCar ? "Automobile desk" : "Clothing desk"}
          </p>
          <h2 className="mt-1 text-xl font-semibold tracking-tight text-slate-900">
            Today&apos;s overview
          </h2>
          <p className="mt-1 text-sm text-slate-500">
            Sales from invoices · Collection from payments · Outstanding balance
          </p>
        </div>
        <Link href={`/b/${slug}/billing`}>
          <Button size="lg">
            <Plus className="h-4 w-4" />
            New invoice
          </Button>
        </Link>
      </div>

      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          label="Today's Sales"
          value={Number(stats.today_sales)}
          hint="Invoice totals today"
          tone="info"
        />
        <StatCard
          label="Today's Collection"
          value={Number(stats.today_collection)}
          hint="Payments received today"
          tone="success"
        />
        <StatCard
          label="Pending Amount"
          value={Number(stats.pending_amount)}
          hint="Outstanding balance"
          tone="warning"
        />
        <StatCard
          label="Total Invoices"
          value={String(stats.total_invoices)}
          hint="Issued invoices"
        />
      </div>

      <section className="w-full max-w-full overflow-hidden border border-slate-200 bg-white">
        <div className="flex items-center justify-between gap-2 border-b border-slate-200 px-4 py-3.5 sm:px-5">
          <div className="min-w-0">
            <h3 className="text-sm font-semibold text-slate-900">
              Recent invoices
            </h3>
            <p className="text-xs text-slate-500">Latest issued bills</p>
          </div>
          <Link
            href={`/b/${slug}/invoices`}
            className={cn(
              "inline-flex shrink-0 items-center gap-1 text-sm font-semibold",
              isCar
                ? "text-blue-700 hover:text-blue-800"
                : "text-brand-ink hover:text-brand-dark",
            )}
          >
            View all
            <ArrowUpRight className="h-4 w-4" />
          </Link>
        </div>

        {invoices.length === 0 ? (
          <div className="px-5 py-14 text-center">
            <p className="text-sm font-semibold text-slate-900">
              No invoices yet
            </p>
            <p className="mt-1 text-sm text-slate-500">
              Create your first bill to see activity here.
            </p>
            <Link href={`/b/${slug}/billing`} className="mt-4 inline-block">
              <Button size="md">
                <Plus className="h-4 w-4" />
                Create invoice
              </Button>
            </Link>
          </div>
        ) : (
          <div className="w-full overflow-x-hidden">
            <table className="w-full table-fixed border-collapse text-sm">
              <thead className="border-b border-slate-200 bg-slate-50/80 text-left text-[11px] font-semibold uppercase tracking-wider text-slate-500">
                <tr>
                  <th className="w-[22%] px-3 py-2.5 sm:px-4">Invoice</th>
                  <th className="w-[22%] px-2 py-2.5">Customer</th>
                  <th className="hidden w-[14%] px-2 py-2.5 sm:table-cell">
                    Date
                  </th>
                  <th className="w-[16%] px-2 py-2.5 text-right">Sales</th>
                  <th className="hidden w-[14%] px-2 py-2.5 text-right md:table-cell">
                    Collected
                  </th>
                  <th className="w-[26%] px-2 py-2.5 sm:w-[12%]">Status</th>
                </tr>
              </thead>
              <tbody>
                {invoices.map((inv) => (
                  <tr
                    key={inv.id}
                    className="border-b border-slate-100 last:border-0 hover:bg-slate-50/70"
                  >
                    <td className="truncate px-3 py-2.5 font-semibold sm:px-4">
                      <Link
                        href={`/b/${slug}/invoices?id=${inv.id}`}
                        className="text-slate-900 hover:underline"
                      >
                        {inv.invoice_number}
                      </Link>
                    </td>
                    <td className="truncate px-2 py-2.5 text-slate-600">
                      {(inv.customers as { name?: string } | null)?.name ||
                        "-"}
                    </td>
                    <td className="hidden truncate px-2 py-2.5 text-slate-500 sm:table-cell">
                      {formatDate(inv.invoice_date)}
                    </td>
                    <td className="truncate px-2 py-2.5 text-right font-medium tabular-nums text-slate-900">
                      {formatMoney(inv.grand_total)}
                    </td>
                    <td className="hidden truncate px-2 py-2.5 text-right tabular-nums text-slate-500 md:table-cell">
                      {formatMoney(inv.amount_paid)}
                    </td>
                    <td className="px-2 py-2.5">
                      <StatusBadge
                        status={inv.payment_status}
                        businessType={business.business_type}
                      />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}

function StatusBadge({
  status,
  businessType,
}: {
  status: string;
  businessType?: string;
}) {
  const styles: Record<string, string> = {
    paid: "bg-emerald-50 text-emerald-700 ring-emerald-200",
    partial: "bg-amber-50 text-amber-700 ring-amber-200",
    pending: "bg-red-50 text-red-700 ring-red-200",
  };
  return (
    <span
      className={`inline-flex rounded-full px-2 py-0.5 text-[11px] font-semibold ring-1 ring-inset ${styles[status] || "bg-slate-50 text-slate-600"}`}
    >
      {paymentStatusLabel(status, businessType)}
    </span>
  );
}
