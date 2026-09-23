import '../../../../core/constants/clothing_categories.dart';

class ScannedProduct {
  const ScannedProduct({
    required this.variantId,
    required this.barcode,
    required this.name,
    required this.sellingPrice,
    required this.taxRate,
    this.brand,
    this.size,
    this.color,
    this.fabric,
    this.offerPercent = 0,
    this.stockQty = 0,
  });

  final String variantId;
  final String barcode;
  final String name;
  final String? brand;
  final String? size;
  final String? color;
  final String? fabric;
  final double sellingPrice;
  final double taxRate;
  final double offerPercent;
  final double stockQty;

  /// Price after offer % (used on billing).
  double get billPrice => effectiveSellPrice(sellingPrice, offerPercent);

  String get description {
    final parts = <String>[
      if (brand != null && brand!.isNotEmpty) brand!,
      name,
      if (color != null && color!.isNotEmpty) color!,
      if (size != null && size!.isNotEmpty) size!,
    ];
    return parts.join(' / ');
  }

  Map<String, dynamic> toMap() => {
        'variantId': variantId,
        'barcode': barcode,
        'name': name,
        'brand': brand,
        'size': size,
        'color': color,
        'fabric': fabric,
        'sellingPrice': sellingPrice,
        'taxRate': taxRate,
        'offerPercent': offerPercent,
        'stockQty': stockQty,
      };

  factory ScannedProduct.fromMap(Map<String, dynamic> map) {
    return ScannedProduct(
      variantId: map['variantId'] as String,
      barcode: map['barcode'] as String,
      name: map['name'] as String,
      brand: map['brand'] as String?,
      size: map['size'] as String?,
      color: map['color'] as String?,
      fabric: map['fabric'] as String?,
      sellingPrice: (map['sellingPrice'] as num).toDouble(),
      taxRate: (map['taxRate'] as num).toDouble(),
      offerPercent: (map['offerPercent'] as num?)?.toDouble() ?? 0,
      stockQty: (map['stockQty'] as num?)?.toDouble() ?? 0,
    );
  }
}
