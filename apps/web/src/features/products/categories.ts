/** Fixed clothing categories for Drape & Dream */
export const CLOTHING_CATEGORIES = [
  "Saree",
  "Kurti",
  "One piece",
  "2 piece",
  "3 piece",
  "Bags",
  "Jewellery",
] as const;

export type ClothingCategory = (typeof CLOTHING_CATEGORIES)[number];
