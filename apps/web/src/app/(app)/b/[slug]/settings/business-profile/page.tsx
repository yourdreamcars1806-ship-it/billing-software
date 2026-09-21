import { getSettingsBusiness } from "../get-settings-business";
import { BusinessProfileSettings } from "./business-profile-settings";

export default async function BusinessProfilePage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const business = await getSettingsBusiness(slug);
  return <BusinessProfileSettings business={business} />;
}
