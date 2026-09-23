import { redirect } from "next/navigation";
import {
  DEMO_BUSINESS_COOKIE,
  DEMO_MODE,
  getDemoBusiness,
} from "@/lib/demo/data";
import { isDemoLoggedIn } from "@/lib/demo/server";
import { cookies } from "next/headers";
import { AppShell } from "@/components/layout/app-shell";
import {
  getAuthedUser,
  getBusinessBySlug,
} from "@/lib/business/get-business";

export default async function AppLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const cookieStore = await cookies();
  const lockedSlug = cookieStore.get(DEMO_BUSINESS_COOKIE)?.value;

  if (lockedSlug && slug !== lockedSlug) {
    redirect(`/b/${lockedSlug}/dashboard`);
  }

  const targetSlug = lockedSlug || slug;

  if (DEMO_MODE) {
    if (!(await isDemoLoggedIn())) redirect("/login");
    const business = getDemoBusiness(targetSlug);
    if (!business) redirect("/login");
    return (
      <AppShell businesses={[business]} locked>
        {children}
      </AppShell>
    );
  }

  const user = await getAuthedUser();
  if (!user) redirect("/login");

  const locked = await getBusinessBySlug(targetSlug);
  if (!locked) redirect("/login");

  return (
    <AppShell businesses={[locked]} locked>
      {children}
    </AppShell>
  );
}
