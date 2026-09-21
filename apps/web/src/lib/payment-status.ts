import type { BusinessType, PaymentStatus } from "@/types";

/**
 * DB keeps "partial".
 * Cars → "Token amount"
 * Clothing → "Partial"
 */
export function paymentStatusLabel(
  status: PaymentStatus | string | null | undefined,
  businessType?: BusinessType | string | null,
): string {
  const s = (status || "pending").toLowerCase();
  if (s === "partial") {
    return businessType === "car" ? "Token amount" : "Partial";
  }
  if (s === "paid") return "Paid";
  if (s === "pending") return "Pending";
  return status || "Pending";
}

export function paymentStatusFilterLabel(
  businessType?: BusinessType | string | null,
): string {
  return businessType === "car" ? "Token amount" : "Partial";
}

export function paymentStatusClass(
  status: PaymentStatus | string | null | undefined,
): string {
  return (status || "pending").toLowerCase();
}
