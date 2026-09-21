import 'package:equatable/equatable.dart';

class Product extends Equatable {
  const Product({
    required this.id,
    required this.businessId,
    required this.name,
    required this.basePrice,
    required this.taxRate,
    this.brand,
    this.category,
    this.subCategory,
    this.description,
    this.imageUrl,
    this.isActive = true,
  });

  final String id;
  final String businessId;
  final String name;
  final String? brand;
  final String? category;
  final String? subCategory;
  final String? description;
  final String? imageUrl;
  final double basePrice;
  final double taxRate;
  final bool isActive;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String?,
      category: json['category'] as String?,
      subCategory: json['sub_category'] as String?,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      basePrice: _toDouble(json['base_price']),
      taxRate: _toDouble(json['tax_rate']),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'business_id': businessId,
        'name': name,
        'brand': brand,
        'category': category,
        'sub_category': subCategory,
        'description': description,
        'image_url': imageUrl,
        'base_price': basePrice,
        'tax_rate': taxRate,
        'is_active': isActive,
      };

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  /// Public helper for repositories parsing nested price fields.
  static double parseDouble(dynamic value) => _toDouble(value);

  @override
  List<Object?> get props => [id, businessId, name, basePrice];
}

class ProductVariant extends Equatable {
  const ProductVariant({
    required this.id,
    required this.businessId,
    required this.productId,
    required this.sellingPrice,
    required this.taxRate,
    this.sku,
    this.size,
    this.color,
    this.fabric,
    this.barcode,
    this.barcodeFormat = 'CODE128',
    this.imageUrl,
    this.isActive = true,
    this.productName,
    this.productBrand,
  });

  final String id;
  final String businessId;
  final String productId;
  final String? sku;
  final String? size;
  final String? color;
  final String? fabric;
  final double sellingPrice;
  final double taxRate;
  final String? barcode;
  final String barcodeFormat;
  final String? imageUrl;
  final bool isActive;
  final String? productName;
  final String? productBrand;

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    final products = json['products'];
    Map<String, dynamic>? productMap;
    if (products is Map<String, dynamic>) {
      productMap = products;
    } else if (products is List && products.isNotEmpty && products.first is Map) {
      productMap = Map<String, dynamic>.from(products.first as Map);
    }

    return ProductVariant(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      productId: json['product_id'] as String,
      sku: json['sku'] as String?,
      size: json['size'] as String?,
      color: json['color'] as String?,
      fabric: json['fabric'] as String?,
      sellingPrice: Product._toDouble(json['selling_price']),
      taxRate: Product._toDouble(json['tax_rate']),
      barcode: json['barcode'] as String?,
      barcodeFormat: json['barcode_format'] as String? ?? 'CODE128',
      imageUrl: json['image_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      productName: productMap?['name'] as String?,
      productBrand: productMap?['brand'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, businessId, productId, barcode];
}
