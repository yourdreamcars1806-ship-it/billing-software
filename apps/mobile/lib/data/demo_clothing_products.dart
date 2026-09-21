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
  });

  final String id;
  final String businessId;
  final String name;
  final String? brand;
  final String size;
  final String color;
  final String? fabric;
  final double sellingPrice;
  final double taxRate;
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
    size: 'M',
    color: 'Black',
    fabric: 'Cotton',
    sellingPrice: 1499,
    taxRate: 12,
    barcode: 'DD2603000001',
  ),
  DemoClothingProduct(
    id: 'pv2',
    businessId: demoClothingBusinessId,
    name: 'Oxford Cotton Shirt',
    brand: 'Drape',
    size: 'L',
    color: 'Black',
    fabric: 'Cotton',
    sellingPrice: 1499,
    taxRate: 12,
    barcode: 'DD2603000002',
  ),
  DemoClothingProduct(
    id: 'pv3',
    businessId: demoClothingBusinessId,
    name: 'Oxford Cotton Shirt',
    brand: 'Drape',
    size: 'M',
    color: 'White',
    fabric: 'Cotton',
    sellingPrice: 1499,
    taxRate: 12,
    barcode: 'DD2603000003',
  ),
  DemoClothingProduct(
    id: 'pv4',
    businessId: demoClothingBusinessId,
    name: 'Slim Fit Chinos',
    brand: 'Dreamwear',
    size: '32',
    color: 'Navy',
    fabric: 'Cotton blend',
    sellingPrice: 2199,
    taxRate: 12,
    barcode: 'DD2603000004',
  ),
  DemoClothingProduct(
    id: 'pv5',
    businessId: demoClothingBusinessId,
    name: 'Linen Kurta',
    brand: 'Drape',
    size: 'XL',
    color: 'Beige',
    fabric: 'Linen',
    sellingPrice: 1899,
    taxRate: 5,
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
