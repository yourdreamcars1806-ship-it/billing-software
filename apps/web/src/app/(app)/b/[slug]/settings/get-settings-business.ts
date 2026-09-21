import { notFound } from "next/navigation";
import { DEMO_MODE, getDemoBusiness } from "@/lib/demo/data";
import { createClient } from "@/lib/supabase/server";
import type { Business } from "@/types";

export async function getSettingsBusiness(slug: string): Promise<Business> {
  if (DEMO_MODE) {
    const business = getDemoBusiness(slug);
    if (!business) notFound();
    return business;
  }

  const supabase = await createClient();
  const { data } = await supabase
    .from("businesses")
    .select("*")
    .eq("slug", slug)
    .maybeSingle();
  if (!data) notFound();
  return data as Business;
}
