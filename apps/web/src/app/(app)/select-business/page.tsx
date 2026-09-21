import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { DEMO_BUSINESS_COOKIE } from "@/lib/demo/data";
import { isDemoLoggedIn } from "@/lib/demo/server";
import { DEMO_MODE } from "@/lib/demo/data";
import { createClient } from "@/lib/supabase/server";

/** Business is chosen at login — this page just redirects. */
export default async function SelectBusinessPage() {
  const cookieStore = await cookies();
  const locked = cookieStore.get(DEMO_BUSINESS_COOKIE)?.value;

  if (locked) {
    redirect(`/b/${locked}/dashboard`);
  }

  if (DEMO_MODE) {
    if (await isDemoLoggedIn()) redirect("/login");
    redirect("/login");
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) redirect("/login");
  redirect("/login");
}
