import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { DEMO_BUSINESS_COOKIE, DEMO_MODE } from "@/lib/demo/data";
import { isDemoLoggedIn } from "@/lib/demo/server";
import { createClient } from "@/lib/supabase/server";

export default async function HomePage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; error_code?: string }>;
}) {
  const params = await searchParams;
  const resetExpired =
    params.error_code === "otp_expired" || params.error === "access_denied";
  const cookieStore = await cookies();
  const locked = cookieStore.get(DEMO_BUSINESS_COOKIE)?.value;

  if (DEMO_MODE) {
    if ((await isDemoLoggedIn()) && locked) {
      redirect(`/b/${locked}/dashboard`);
    }
    redirect("/login");
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (user && locked) redirect(`/b/${locked}/dashboard`);
  redirect(resetExpired ? "/login?reset=expired" : "/login");
}
