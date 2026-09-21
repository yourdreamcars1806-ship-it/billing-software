"use client";

import { useEffect } from "react";
import { useParams } from "next/navigation";
import { useBusinessStore } from "@/hooks/use-business-store";
import type { Business } from "@/types";

/** Keeps zustand active business aligned with the URL slug. */
export function BusinessSync({ businesses }: { businesses: Business[] }) {
  const params = useParams<{ slug?: string }>();
  const { activeBusiness, setActiveBusiness } = useBusinessStore();

  useEffect(() => {
    const slug = params?.slug;
    if (!slug) return;
    const match = businesses.find((b) => b.slug === slug);
    if (match && match.id !== activeBusiness?.id) {
      setActiveBusiness(match);
    }
  }, [params?.slug, businesses, activeBusiness?.id, setActiveBusiness]);

  return null;
}
