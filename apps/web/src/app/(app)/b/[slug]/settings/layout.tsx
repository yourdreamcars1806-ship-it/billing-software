import { SettingsTabs } from "./settings-tabs";

export default async function SettingsLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;

  return (
    <div className="min-w-0">
      <SettingsTabs slug={slug} />
      {children}
    </div>
  );
}
