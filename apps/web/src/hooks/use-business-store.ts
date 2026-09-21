"use client";

import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { Business } from "@/types";

interface BusinessState {
  activeBusiness: Business | null;
  setActiveBusiness: (business: Business | null) => void;
  clear: () => void;
}

export const useBusinessStore = create<BusinessState>()(
  persist(
    (set) => ({
      activeBusiness: null,
      setActiveBusiness: (business) => set({ activeBusiness: business }),
      clear: () => set({ activeBusiness: null }),
    }),
    { name: "billing-active-business" },
  ),
);
