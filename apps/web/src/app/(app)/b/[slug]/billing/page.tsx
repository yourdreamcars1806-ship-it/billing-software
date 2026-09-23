import { notFound } from "next/navigation";
import { getBusinessBySlug } from "@/lib/business/get-business";
import { BillingForm } from "@/features/billing/billing-form";

export default async function BillingPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const business = await getBusinessBySlug(slug);
  if (!business) notFound();
  return <BillingForm business={business} />;
}
