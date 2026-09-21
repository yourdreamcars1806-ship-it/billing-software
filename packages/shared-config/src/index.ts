/** Shared configuration constants */

export const APP_NAME = "Billing Software";

export const BUSINESSES = [
  {
    slug: "drape-and-dream",
    name: "Drape & Dream",
    description: "Clothing Billing",
    type: "clothing" as const,
    features: {
      barcode: true,
      products: true,
      carFields: false,
    },
  },
  {
    slug: "your-dream-cars",
    name: "Your Dream Cars",
    description: "Car Billing",
    type: "car" as const,
    features: {
      barcode: false,
      products: false,
      carFields: true,
    },
  },
] as const;

export function getBusinessFeatures(slug: string) {
  return BUSINESSES.find((b) => b.slug === slug)?.features ?? {
    barcode: false,
    products: false,
    carFields: false,
  };
}

export const CURRENCY = {
  code: "INR",
  symbol: "₹",
  locale: "en-IN",
} as const;

export function formatMoney(amount: number, locale = CURRENCY.locale): string {
  return new Intl.NumberFormat(locale, {
    style: "currency",
    currency: CURRENCY.code,
    maximumFractionDigits: 2,
  }).format(amount);
}
