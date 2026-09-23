import { cache } from "react";
import { DEMO_MODE, getDemoBusiness } from "@/lib/demo/data";
import { createClient } from "@/lib/supabase/server";
import type { Business } from "@/types";

/** Columns needed by AppShell / pages — avoid select("*"). */
export const BUSINESS_COLS =
  "id, slug, name, business_type, description, logo_url, address, phone, email, gstin, pan, is_active" as const;

/**
 * One auth round-trip per request (shared by layout + page via React cache).
 */
export const getAuthedUser = cache(async () => {
  if (DEMO_MODE) return null;
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  return user;
});

/**
 * Resolve business by slug for the current user.
 * Deduped within a single RSC request so layout + page don't double-hit Supabase.
 */
export const getBusinessBySlug = cache(async (slug: string): Promise<Business | null> => {
  if (DEMO_MODE) {
    return (getDemoBusiness(slug) as Business | undefined) || null;
  }

  const user = await getAuthedUser();
  if (!user) return null;

  const supabase = await createClient();

  // Single query: business + membership check (no fetch-all-businesses)
  const { data, error } = await supabase
    .from("businesses")
    .select(`${BUSINESS_COLS}, business_users!inner(user_id, is_active)`)
    .eq("slug", slug)
    .eq("business_users.user_id", user.id)
    .eq("business_users.is_active", true)
    .maybeSingle();

  if (error || !data) return null;

  const { business_users: _membership, ...business } = data as Business & {
    business_users?: unknown;
  };
  return business as Business;
});
