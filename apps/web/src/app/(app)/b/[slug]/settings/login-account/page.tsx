import { getSettingsBusiness } from "../get-settings-business";
import { LoginAccountSettings } from "./login-account-settings";

export default async function LoginAccountPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const business = await getSettingsBusiness(slug);
  return <LoginAccountSettings business={business} />;
}
