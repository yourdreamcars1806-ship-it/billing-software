import {
  DEMO_BUSINESS_COOKIE,
  DEMO_COOKIE,
} from "@/lib/demo/data";

export function getSupabaseProjectRef() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL ?? "";
  const match = url.match(/https:\/\/([^.]+)\.supabase\.co/);
  return match?.[1] ?? null;
}

/** Client-side: drop billing + stale Supabase auth cookies. */
export function clearClientSessionCookies(options?: {
  keepBusinessLock?: boolean;
}) {
  if (typeof document === "undefined") return;

  document.cookie = `${DEMO_COOKIE}=; path=/; max-age=0; SameSite=Lax`;

  if (!options?.keepBusinessLock) {
    document.cookie = `${DEMO_BUSINESS_COOKIE}=; path=/; max-age=0; SameSite=Lax`;
    localStorage.removeItem("billing_locked_business");
  }

  const ref = getSupabaseProjectRef();
  for (const part of document.cookie.split(";")) {
    const name = part.split("=")[0]?.trim();
    if (!name?.startsWith("sb-")) continue;
    if (ref && name.startsWith(`sb-${ref}-`)) continue;
    document.cookie = `${name}=; path=/; max-age=0; SameSite=Lax`;
  }
}

/** Server/middleware: drop legacy demo cookies and stale Supabase project cookies. */
export function applyLegacyCookieCleanup(
  request: { cookies: { get: (name: string) => { value: string } | undefined; getAll: () => { name: string }[] } },
  response: { cookies: { set: (name: string, value: string, options?: { path?: string; maxAge?: number }) => void } },
) {
  if (request.cookies.get(DEMO_COOKIE)) {
    response.cookies.set(DEMO_COOKIE, "", { path: "/", maxAge: 0 });
  }

  const ref = getSupabaseProjectRef();
  if (!ref) return;

  for (const cookie of request.cookies.getAll()) {
    if (
      cookie.name.startsWith("sb-") &&
      !cookie.name.startsWith(`sb-${ref}-`)
    ) {
      response.cookies.set(cookie.name, "", { path: "/", maxAge: 0 });
    }
  }
}
