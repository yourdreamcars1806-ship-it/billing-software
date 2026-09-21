import { getSettingsBusiness } from "../get-settings-business";
import { InvoiceTaxSettings } from "./invoice-tax-settings";

export default async function InvoiceTaxPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const business = await getSettingsBusiness(slug);
  return <InvoiceTaxSettings business={business} />;
}
