/// Demo clothing catalog for phone barcode scan (matches web demo barcodes).
class DemoClothingProduct {
  const DemoClothingProduct({
    required this.id,
    required this.businessId,
    required this.name,
    required this.size,
    required this.color,
    required this.sellingPrice,
    required this.taxRate,
    required this.barcode,
    this.brand,
    this.fabric,
    this.category,
    this.costPrice = 0,
    this.offerPercent = 0,
    this.stockQty = 0,
  });

  final String id;
  final String businessId;
  final String name;
  final String? brand;
  final String? category;
  final String size;
  final String color;
  final String? fabric;
  final double costPrice;
  final double sellingPrice;
  final double taxRate;
  final double offerPercent;
  final double stockQty;
  final String barcode;
}

/// Same business id as web demo clothing business.
const demoClothingBusinessId = 'a1000000-0000-4000-8000-000000000001';

const demoClothingProducts = <DemoClothingProduct>[
  DemoClothingProduct(
    id: 'pv1',
    businessId: demoClothingBusinessId,
    name: 'Oxford Cotton Shirt',
    brand: 'Drape',
    category: 'Kurti',
    size: 'M',
    color: 'Black',
    fabric: 'Cotton',
    costPrice: 900,
    sellingPrice: 1499,
    taxRate: 12,
    offerPercent: 10,
    stockQty: 12,
    barcode: 'DD2603000001',
  ),
  DemoClothingProduct(
    id: 'pv2',
    businessId: demoClothingBusinessId,
    name: 'Oxford Cotton Shirt',
    brand: 'Drape',
    category: 'Kurti',
    size: 'L',
    color: 'Black',
    fabric: 'Cotton',
    costPrice: 900,
    sellingPrice: 1499,
    taxRate: 12,
    offerPercent: 10,
    stockQty: 8,
    barcode: 'DD2603000002',
  ),
  DemoClothingProduct(
    id: 'pv3',
    businessId: demoClothingBusinessId,
    name: 'Oxford Cotton Shirt',
    brand: 'Drape',
    category: 'Kurti',
    size: 'M',
    color: 'White',
    fabric: 'Cotton',
    costPrice: 900,
    sellingPrice: 1499,
    taxRate: 12,
    offerPercent: 10,
    stockQty: 0,
    barcode: 'DD2603000003',
  ),
  DemoClothingProduct(
    id: 'pv4',
    businessId: demoClothingBusinessId,
    name: 'Slim Fit Chinos',
    brand: 'Dreamwear',
    category: '2 piece',
    size: '32',
    color: 'Navy',
    fabric: 'Cotton blend',
    costPrice: 1200,
    sellingPrice: 2199,
    taxRate: 12,
    offerPercent: 10,
    stockQty: 15,
    barcode: 'DD2603000004',
  ),
  DemoClothingProduct(
    id: 'pv5',
    businessId: demoClothingBusinessId,
    name: 'Linen Kurta',
    brand: 'Drape',
    category: 'Kurti',
    size: 'XL',
    color: 'Beige',
    fabric: 'Linen',
    costPrice: 1100,
    sellingPrice: 1899,
    taxRate: 5,
    offerPercent: 0,
    stockQty: 6,
    barcode: 'DD2603000005',
  ),
];

DemoClothingProduct? findDemoProductByBarcode(String barcode) {
  final code = barcode.trim().toUpperCase();
  for (final p in demoClothingProducts) {
    if (p.barcode.toUpperCase() == code) return p;
  }
  return null;
}
