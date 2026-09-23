import { notFound } from "next/navigation";
import { DEMO_MODE, getDemoBusiness } from "@/lib/demo/data";
import { getBusinessBySlug } from "@/lib/business/get-business";

export async function getSettingsBusiness(slug: string) {
  const business = DEMO_MODE
    ? getDemoBusiness(slug)
    : await getBusinessBySlug(slug);
  if (!business) notFound();
  return business;
}
