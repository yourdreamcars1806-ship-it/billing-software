export function roundMoney(n: number) {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}

/** Discount amount from offer % on list price × qty */
export function discountFromOffer(
  quantity: number,
  unitPrice: number,
  offerPercent: number,
) {
  if (!(offerPercent > 0) || !(quantity > 0) || !(unitPrice > 0)) return 0;
  return roundMoney((quantity * unitPrice * offerPercent) / 100);
}
