import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { publicSiteUrl } from "@/lib/site-url";

export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);
  const live = publicSiteUrl();
  const code = searchParams.get("code");
  const next = searchParams.get("next");
  const safeNext =
    next && next.startsWith("/") && !next.startsWith("//")
      ? next
      : "/update-password";

  if (searchParams.get("error") || searchParams.get("error_code")) {
    return NextResponse.redirect(new URL("/login?reset=expired", live));
  }

  if (code && !origin.includes("yourdreamcars.co.in")) {
    const dest = new URL("/auth/callback", live);
    dest.searchParams.set("code", code);
    dest.searchParams.set("next", safeNext);
    return NextResponse.redirect(dest);
  }

  if (code) {
    const supabase = await createClient();
    await supabase.auth.exchangeCodeForSession(code);
  }

  return NextResponse.redirect(`${live}${safeNext}`);
}
