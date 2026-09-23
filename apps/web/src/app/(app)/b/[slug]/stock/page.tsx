import { notFound, redirect } from "next/navigation";
import { getBusinessBySlug } from "@/lib/business/get-business";
import { StockPage } from "@/features/stock/stock-page";

export default async function StockRoute({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const business = await getBusinessBySlug(slug);
  if (!business) notFound();
  if (business.business_type !== "clothing") {
    redirect(`/b/${slug}/dashboard`);
  }
  return <StockPage business={business} />;
}
