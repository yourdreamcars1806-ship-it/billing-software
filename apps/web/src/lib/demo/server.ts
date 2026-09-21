import { cookies } from "next/headers";
import { DEMO_COOKIE, DEMO_MODE } from "@/lib/demo/data";

export function isDemoMode() {
  return DEMO_MODE;
}

export async function isDemoLoggedIn() {
  if (!DEMO_MODE) return false;
  const store = await cookies();
  return store.get(DEMO_COOKIE)?.value === "1";
}
