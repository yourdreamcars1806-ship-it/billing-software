import { notFound } from "next/navigation";
import { DEMO_MODE, getDemoBusiness, getDemoStats } from "@/lib/demo/data";
import { createClient } from "@/lib/supabase/server";
import { StatCard } from "@/components/ui/stat-card";
import { paymentStatusFilterLabel } from "@/lib/payment-status";
import type { Business } from "@/types";

export default async function ReportsPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;

  if (DEMO_MODE) {
    const b = getDemoBusiness(slug);
    if (!b) notFound();
    const stats = getDemoStats(b.id);
    return (
      <ReportsView
        business={b}
        monthlySales={stats.today_sales * 12}
        monthlyCollection={stats.today_collection * 10}
        outstanding={stats.pending_amount}
        paid={stats.paid_invoices}
        partial={stats.partial_invoices}
        pending={stats.pending_invoices}
        methods={[
          { method: "upi", amount: stats.today_collection * 0.45 },
          { method: "cash", amount: stats.today_collection * 0.35 },
          { method: "card", amount: stats.today_collection * 0.2 },
        ]}
      />
    );
  }

  const supabase = await createClient();
  const { data: business } = await supabase
    .from("businesses")
    .select("*")
    .eq("slug", slug)
    .maybeSingle();
  if (!business) notFound();
  const b = business as Business;

  const today = new Date().toISOString().slice(0, 10);
  const monthStart = `${today.slice(0, 7)}-01`;

  const [{ data: monthInvoices }, { data: monthPayments }, { data: byMethod }] =
    await Promise.all([
      supabase
        .from("invoices")
        .select("grand_total, payment_status, amount_outstanding")
        .eq("business_id", b.id)
        .eq("status", "issued")
        .gte("invoice_date", monthStart),
      supabase
        .from("payments")
        .select("amount")
        .eq("business_id", b.id)
        .gte("payment_date", monthStart),
      supabase
        .from("payments")
        .select("payment_method, amount")
        .eq("business_id", b.id)
        .gte("payment_date", monthStart),
    ]);

  const monthlySales = (monthInvoices || []).reduce(
    (s, i) => s + Number(i.grand_total),
    0,
  );
  const monthlyCollection = (monthPayments || []).reduce(
    (s, p) => s + Number(p.amount),
    0,
  );
  const outstanding = (monthInvoices || []).reduce(
    (s, i) => s + Number(i.amount_outstanding),
    0,
  );
  const paid = (monthInvoices || []).filter(
    (i) => i.payment_status === "paid",
  ).length;
  const partial = (monthInvoices || []).filter(
    (i) => i.payment_status === "partial",
  ).length;
  const pending = (monthInvoices || []).filter(
    (i) => i.payment_status === "pending",
  ).length;

  const methodMap = new Map<string, number>();
  for (const row of byMethod || []) {
    const key = row.payment_method as string;
    methodMap.set(key, (methodMap.get(key) || 0) + Number(row.amount));
  }

  return (
    <ReportsView
      business={b}
      monthlySales={monthlySales}
      monthlyCollection={monthlyCollection}
      outstanding={outstanding}
      paid={paid}
      partial={partial}
      pending={pending}
      methods={[...methodMap.entries()].map(([method, amount]) => ({
        method,
        amount,
      }))}
    />
  );
}

function ReportsView({
  business,
  monthlySales,
  monthlyCollection,
  outstanding,
  paid,
  partial,
  pending,
  methods,
}: {
  business: Business;
  monthlySales: number;
  monthlyCollection: number;
  outstanding: number;
  paid: number;
  partial: number;
  pending: number;
  methods: { method: string; amount: number }[];
}) {
  const isCar = business.business_type === "car";

  return (
    <div className="w-full max-w-full space-y-6 overflow-x-hidden">
      <div className="border-b border-slate-200 pb-5">
        <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-brand-ink">
          {isCar ? "Automobile desk" : "Clothing desk"}
        </p>
        <h2 className="mt-1 text-xl font-semibold tracking-tight text-slate-900">
          Month summary
        </h2>
        <p className="mt-1 text-sm text-slate-500">
          Sales, collection, and payment mix for {business.name}
        </p>
      </div>

      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
        <StatCard
          label="Monthly Sales"
          value={monthlySales}
          hint="Issued invoice totals"
          tone="info"
        />
        <StatCard
          label="Monthly Collection"
          value={monthlyCollection}
          hint="Payments received"
          tone="success"
        />
        <StatCard
          label="Outstanding"
          value={outstanding}
          hint="Still due"
          tone="warning"
        />
        <StatCard label="Paid invoices" value={String(paid)} />
        <StatCard
          label={`${paymentStatusFilterLabel(business.business_type)} invoices`}
          value={String(partial)}
        />
        <StatCard label="Pending invoices" value={String(pending)} />
      </div>

      <section className="overflow-hidden border border-slate-200 bg-white">
        <div className="border-b border-slate-200 px-4 py-3.5 sm:px-5">
          <h3 className="text-sm font-semibold text-slate-900">
            Collection by method
          </h3>
          <p className="text-xs text-slate-500">This month&apos;s payments</p>
        </div>
        {methods.length === 0 ? (
          <div className="px-5 py-12 text-center text-sm text-slate-500">
            No payments recorded this month.
          </div>
        ) : (
          <table className="w-full table-fixed border-collapse text-sm">
            <thead className="border-b border-slate-200 bg-slate-50/80 text-left text-[11px] font-semibold uppercase tracking-wider text-slate-500">
              <tr>
                <th className="px-4 py-2.5 sm:px-5">Method</th>
                <th className="px-4 py-2.5 text-right sm:px-5">Amount</th>
              </tr>
            </thead>
            <tbody>
              {methods.map(({ method, amount }) => (
                <tr
                  key={method}
                  className="border-b border-slate-100 last:border-0"
                >
                  <td className="px-4 py-2.5 capitalize text-slate-700 sm:px-5">
                    {method.replace("_", " ")}
                  </td>
                  <td className="px-4 py-2.5 text-right font-semibold tabular-nums text-slate-900 sm:px-5">
                    {new Intl.NumberFormat("en-IN", {
                      style: "currency",
                      currency: "INR",
                    }).format(amount)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>
    </div>
  );
}
