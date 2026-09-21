import { notFound } from "next/navigation";
import { DEMO_MODE, getDemoBusiness } from "@/lib/demo/data";
import { createClient } from "@/lib/supabase/server";
import { InvoicesManager } from "@/features/invoices/invoices-manager";
import type { Business } from "@/types";

export default async function InvoicesPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;

  if (DEMO_MODE) {
    const business = getDemoBusiness(slug);
    if (!business) notFound();
    return <InvoicesManager business={business} />;
  }

  const supabase = await createClient();
  const { data } = await supabase
    .from("businesses")
    .select("*")
    .eq("slug", slug)
    .maybeSingle();
  if (!data) notFound();
  return <InvoicesManager business={data as Business} />;
}
