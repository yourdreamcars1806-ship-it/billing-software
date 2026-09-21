import { notFound } from "next/navigation";
import { DEMO_MODE, getDemoBusiness } from "@/lib/demo/data";
import { createClient } from "@/lib/supabase/server";
import { BillingForm } from "@/features/billing/billing-form";
import type { Business } from "@/types";

export default async function BillingPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;

  if (DEMO_MODE) {
    const business = getDemoBusiness(slug);
    if (!business) notFound();
    return <BillingForm business={business} />;
  }

  const supabase = await createClient();
  const { data } = await supabase
    .from("businesses")
    .select("*")
    .eq("slug", slug)
    .maybeSingle();
  if (!data) notFound();
  return <BillingForm business={data as Business} />;
}
