import { notFound, redirect } from "next/navigation";
import { DEMO_MODE, getDemoBusiness } from "@/lib/demo/data";
import { createClient } from "@/lib/supabase/server";
import { ProductsManager } from "@/features/products/products-manager";
import type { Business } from "@/types";

export default async function ProductsPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;

  if (DEMO_MODE) {
    const business = getDemoBusiness(slug);
    if (!business) notFound();
    if (business.business_type !== "clothing") {
      redirect(`/b/${slug}/dashboard`);
    }
    return <ProductsManager business={business} />;
  }

  const supabase = await createClient();
  const { data } = await supabase
    .from("businesses")
    .select("*")
    .eq("slug", slug)
    .maybeSingle();
  if (!data) notFound();
  const business = data as Business;
  if (business.business_type !== "clothing") {
    redirect(`/b/${slug}/dashboard`);
  }
  return <ProductsManager business={business} />;
}
