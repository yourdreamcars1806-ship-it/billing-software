import { notFound } from "next/navigation";
import { getBusinessBySlug } from "@/lib/business/get-business";
import { InvoicesManager } from "@/features/invoices/invoices-manager";

export default async function InvoicesPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const business = await getBusinessBySlug(slug);
  if (!business) notFound();
  return <InvoicesManager business={business} />;
}
