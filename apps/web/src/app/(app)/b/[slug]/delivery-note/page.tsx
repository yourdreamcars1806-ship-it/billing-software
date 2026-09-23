import { notFound, redirect } from "next/navigation";
import { getBusinessBySlug } from "@/lib/business/get-business";
import { DeliveryNoteForm } from "@/features/delivery-note/delivery-note-form";

export default async function DeliveryNotePage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const business = await getBusinessBySlug(slug);
  if (!business) notFound();
  if (business.business_type !== "car") {
    redirect(`/b/${slug}/invoices`);
  }
  return <DeliveryNoteForm business={business} />;
}
