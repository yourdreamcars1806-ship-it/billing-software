import { notFound } from "next/navigation";
import {
  DEMO_MODE,
  getDemoBusiness,
  getDemoPayments,
} from "@/lib/demo/data";
import { createClient } from "@/lib/supabase/server";
import { formatDate, formatMoney } from "@/lib/utils";
import type { Business, Payment } from "@/types";

export default async function PaymentsPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;

  if (DEMO_MODE) {
    const business = getDemoBusiness(slug);
    if (!business) notFound();
    const rows = getDemoPayments(business.id).map((p) => ({
      ...p,
      invoices: {
        invoice_number:
          p.invoice_id === "inv1"
            ? business.business_type === "clothing"
              ? "DD-00042"
              : "YDC-00018"
            : business.business_type === "clothing"
              ? "DD-00041"
              : "YDC-00017",
      },
    }));

    return <PaymentsView business={business} rows={rows} />;
  }

  const supabase = await createClient();
  const { data: business } = await supabase
    .from("businesses")
    .select("*")
    .eq("slug", slug)
    .maybeSingle();
  if (!business) notFound();

  const { data: payments } = await supabase
    .from("payments")
    .select("*, invoices(invoice_number)")
    .eq("business_id", (business as Business).id)
    .order("payment_date", { ascending: false })
    .limit(100);

  const rows = (payments || []) as (Payment & {
    invoices?: { invoice_number: string } | null;
  })[];

  return <PaymentsView business={business as Business} rows={rows} />;
}

function PaymentsView({
  business,
  rows,
}: {
  business: Business;
  rows: (Payment & { invoices?: { invoice_number: string } | null })[];
}) {
  return (
    <div className="space-y-5">
      <div className="border-b border-slate-200 pb-4">
        <h1 className="text-xl font-semibold tracking-tight text-slate-900">
          {business.business_type === "car" ? "Tokens & payments" : "Payments"}
        </h1>
        <p className="mt-0.5 text-sm text-slate-500">
          {business.business_type === "car"
            ? `Token / collection history for ${business.name}`
            : `Collection history for ${business.name}`}
        </p>
      </div>

      {rows.length === 0 ? (
        <div className="border border-dashed border-slate-300 py-16 text-center text-sm text-slate-500">
          No payments recorded yet.
        </div>
      ) : (
        <div className="overflow-x-auto border border-slate-200 bg-white">
          <table className="min-w-full border-collapse text-left text-sm">
            <thead>
              <tr className="border-b border-slate-200 bg-slate-50/80">
                <th className="px-3 py-2.5 text-[11px] font-semibold uppercase tracking-wider text-slate-500">
                  Date
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold uppercase tracking-wider text-slate-500">
                  Invoice
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold uppercase tracking-wider text-slate-500">
                  Method
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold uppercase tracking-wider text-slate-500">
                  Reference
                </th>
                <th className="px-3 py-2.5 text-right text-[11px] font-semibold uppercase tracking-wider text-slate-500">
                  Amount
                </th>
              </tr>
            </thead>
            <tbody>
              {rows.map((p) => (
                <tr
                  key={p.id}
                  className="border-b border-slate-100 last:border-0 hover:bg-slate-50/70"
                >
                  <td className="px-3 py-2.5 text-slate-700">
                    {formatDate(p.payment_date)}
                  </td>
                  <td className="px-3 py-2.5 font-medium text-slate-900">
                    {p.invoices?.invoice_number || "-"}
                  </td>
                  <td className="px-3 py-2.5 capitalize text-slate-700">
                    {p.payment_method.replace("_", " ")}
                  </td>
                  <td className="px-3 py-2.5 text-slate-600">
                    {p.reference_number || "-"}
                  </td>
                  <td className="px-3 py-2.5 text-right font-medium tabular-nums text-slate-900">
                    {formatMoney(p.amount)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      <p className="text-xs tabular-nums text-slate-500">{rows.length} rows</p>
    </div>
  );
}
