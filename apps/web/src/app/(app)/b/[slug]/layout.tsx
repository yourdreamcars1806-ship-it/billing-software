import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import {
  DEMO_BUSINESS_COOKIE,
  DEMO_MODE,
  getDemoBusiness,
} from "@/lib/demo/data";
import { isDemoLoggedIn } from "@/lib/demo/server";
import { createClient } from "@/lib/supabase/server";
import { AppShell } from "@/components/layout/app-shell";
import type { Business } from "@/types";

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

  if (DEMO_MODE) {
    if (!(await isDemoLoggedIn())) redirect("/login");
    const business = getDemoBusiness(lockedSlug || slug);
    if (!business) redirect("/login");
    return (
      <AppShell businesses={[business]} locked>
        {children}
      </AppShell>
    );
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) redirect("/login");

  const targetSlug = lockedSlug || slug;
  const { data } = await supabase
    .from("business_users")
    .select("businesses(*)")
    .eq("user_id", user.id)
    .eq("is_active", true);

  const all =
    (data
      ?.map((row) => row.businesses as unknown as Business)
      .filter(Boolean) as Business[]) || [];

  const locked = all.find((b) => b.slug === targetSlug);
  if (!locked) redirect("/login");

  return (
    <AppShell businesses={[locked]} locked>
      {children}
    </AppShell>
  );
}
