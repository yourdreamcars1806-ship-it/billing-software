const PRODUCTION_SITE_URL = "https://billing.yourdreamcars.co.in";

/** Live site URL for auth emails. Do not use localhost — reset mail is opened on the phone/PC, not this machine. */
export function publicSiteUrl() {
  const fromEnv = process.env.NEXT_PUBLIC_SITE_URL?.trim().replace(/\/$/, "");
  if (fromEnv && !fromEnv.includes("localhost")) return fromEnv;
  return PRODUCTION_SITE_URL;
}
