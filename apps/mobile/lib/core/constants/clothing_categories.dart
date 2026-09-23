/// Fixed clothing categories — same as web `CLOTHING_CATEGORIES`.
const clothingCategories = <String>[
  'Saree',
  'Kurti',
  'One piece',
  '2 piece',
  '3 piece',
  'Bags',
  'Jewellery',
];

bool isValidClothingCategory(String? value) {
  final v = value?.trim() ?? '';
  return clothingCategories.contains(v);
}

/// Sell price after offer % (web parity).
double effectiveSellPrice(double sellingPrice, double offerPercent) {
  if (!(sellingPrice > 0)) return 0;
  if (!(offerPercent > 0)) return sellingPrice;
  final capped = offerPercent > 100 ? 100.0 : offerPercent;
  return sellingPrice * (1 - capped / 100);
}
