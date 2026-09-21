import { getSettingsBusiness } from "../get-settings-business";
import { WhatsappSettings } from "./whatsapp-settings";

export default async function WhatsappPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const business = await getSettingsBusiness(slug);
  return <WhatsappSettings business={business} />;
}
