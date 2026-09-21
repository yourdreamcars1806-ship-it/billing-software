import { NextResponse, type NextRequest } from "next/server";
import { createServerClient } from "@supabase/ssr";
import { applyLegacyCookieCleanup } from "@/lib/auth/session-cookies";
import {
  DEMO_BUSINESS_COOKIE,
  DEMO_COOKIE,
  DEMO_MODE,
} from "@/lib/demo/data";

function lockedDashboard(slug: string) {
  return `/b/${slug}/dashboard`;
}

export async function updateSession(request: NextRequest) {
  const path = request.nextUrl.pathname;
  const isAuthRoute =
    path.startsWith("/login") ||
    path.startsWith("/forgot-password") ||
    path.startsWith("/update-password") ||
    path.startsWith("/auth");

  // ---------- Demo mode (no database) ----------
  if (DEMO_MODE) {
    const demoOk = request.cookies.get(DEMO_COOKIE)?.value === "1";
    const lockedSlug = request.cookies.get(DEMO_BUSINESS_COOKIE)?.value;

    // Old sessions without locked business → force re-login
    if (demoOk && !lockedSlug && !isAuthRoute) {
      const res = NextResponse.redirect(new URL("/login", request.url));
      res.cookies.set(DEMO_COOKIE, "", { path: "/", maxAge: 0 });
      return res;
    }

    if (!demoOk && !isAuthRoute && path !== "/") {
      const url = request.nextUrl.clone();
      url.pathname = "/login";
      return NextResponse.redirect(url);
    }

    if (demoOk && lockedSlug) {
      if (
        path === "/login" ||
        path === "/" ||
        path === "/select-business"
      ) {
        const url = request.nextUrl.clone();
        url.pathname = lockedDashboard(lockedSlug);
        return NextResponse.redirect(url);
      }

      if (path.startsWith("/b/") && !path.startsWith(`/b/${lockedSlug}`)) {
        const url = request.nextUrl.clone();
        url.pathname = lockedDashboard(lockedSlug);
        return NextResponse.redirect(url);
      }
    }

    if (path === "/" && !demoOk) {
      const url = request.nextUrl.clone();
      url.pathname = "/login";
      return NextResponse.redirect(url);
    }

    return NextResponse.next();
  }

  // ---------- Real Supabase mode ----------
  let supabaseResponse = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) =>
            request.cookies.set(name, value),
          );
          supabaseResponse = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options),
          );
        },
      },
    },
  );

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const lockedSlug = request.cookies.get(DEMO_BUSINESS_COOKIE)?.value;

  if (!user && !isAuthRoute && path !== "/") {
    const url = request.nextUrl.clone();
    url.pathname = "/login";
    return NextResponse.redirect(url);
  }

  if (user && lockedSlug) {
    if (path === "/login" || path === "/" || path === "/select-business") {
      const url = request.nextUrl.clone();
      url.pathname = lockedDashboard(lockedSlug);
      return NextResponse.redirect(url);
    }

    if (path.startsWith("/b/") && !path.startsWith(`/b/${lockedSlug}`)) {
      const url = request.nextUrl.clone();
      url.pathname = lockedDashboard(lockedSlug);
      return NextResponse.redirect(url);
    }
  }

  if (user && !lockedSlug && (path === "/login" || path === "/")) {
    const url = request.nextUrl.clone();
    url.pathname = "/select-business";
    const redirect = NextResponse.redirect(url);
    applyLegacyCookieCleanup(request, redirect);
    return redirect;
  }

  applyLegacyCookieCleanup(request, supabaseResponse);
  return supabaseResponse;
}
