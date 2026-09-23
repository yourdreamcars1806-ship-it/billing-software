import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../models/product.dart';
import '../services/supabase_service.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(ref.watch(supabaseServiceProvider));
});

const _variantSelectCols =
    'id, business_id, product_id, size, color, fabric, cost_price, '
    'selling_price, tax_rate, offer_percent, barcode, barcode_format, '
    'is_active, stock_qty, stock_in_total, stock_out_total';

/// Clothing variant row for Products & Barcode list.
class ClothingProductItem {
  const ClothingProductItem({
    required this.id,
    required this.businessId,
    required this.name,
    required this.size,
    required this.color,
    required this.sellingPrice,
    required this.taxRate,
    required this.barcode,
    this.productId,
    this.brand,
    this.category,
    this.subCategory,
    this.fabric,
    this.barcodeFormat = 'CODE128',
    this.costPrice = 0,
    this.offerPercent = 0,
    this.stockQty = 0,
    this.stockInTotal = 0,
    this.stockOutTotal = 0,
    this.isActive = true,
  });

  final String id;
  final String businessId;
  final String? productId;
  final String name;
  final String? brand;
  final String? category;
  final String? subCategory;
  final String size;
  final String color;
  final String? fabric;
  final double costPrice;
  final double sellingPrice;
  final double taxRate;
  final double offerPercent;
  final String barcode;
  final String barcodeFormat;
  final double stockQty;
  final double stockInTotal;
  final double stockOutTotal;
  final bool isActive;

  ClothingProductItem copyWith({
    double? stockQty,
    double? stockInTotal,
    double? stockOutTotal,
    double? costPrice,
    double? sellingPrice,
    double? offerPercent,
    String? category,
  }) {
    return ClothingProductItem(
      id: id,
      businessId: businessId,
      productId: productId,
      name: name,
      brand: brand,
      category: category ?? this.category,
      subCategory: subCategory,
      size: size,
      color: color,
      fabric: fabric,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      taxRate: taxRate,
      offerPercent: offerPercent ?? this.offerPercent,
      barcode: barcode,
      barcodeFormat: barcodeFormat,
      stockQty: stockQty ?? this.stockQty,
      stockInTotal: stockInTotal ?? this.stockInTotal,
      stockOutTotal: stockOutTotal ?? this.stockOutTotal,
      isActive: isActive,
    );
  }
}

class ProductRepository {
  ProductRepository(this._supabase);

  final SupabaseService _supabase;

  ClothingProductItem _mapClothingRow(
    Map<String, dynamic> map, {
    String? fallbackName,
    String? fallbackBrand,
    String? fallbackCategory,
    String? fallbackSub,
  }) {
    final products = map['products'];
    Map<String, dynamic>? p;
    if (products is Map) {
      p = Map<String, dynamic>.from(products);
    } else if (products is List && products.isNotEmpty && products.first is Map) {
      p = Map<String, dynamic>.from(products.first as Map);
    }
    return ClothingProductItem(
      id: map['id'] as String,
      businessId: map['business_id'] as String,
      productId: map['product_id'] as String?,
      name: (p?['name'] as String?) ?? fallbackName ?? 'Product',
      brand: (p?['brand'] as String?) ?? fallbackBrand,
      category: (p?['category'] as String?) ?? fallbackCategory,
      subCategory: (p?['sub_category'] as String?) ?? fallbackSub,
      size: (map['size'] as String?) ?? '',
      color: (map['color'] as String?) ?? '',
      fabric: map['fabric'] as String?,
      costPrice: Product.parseDouble(map['cost_price']),
      sellingPrice: Product.parseDouble(map['selling_price']),
      taxRate: Product.parseDouble(map['tax_rate']),
      offerPercent: Product.parseDouble(map['offer_percent']),
      barcode: (map['barcode'] as String?) ?? '',
      barcodeFormat: (map['barcode_format'] as String?) ?? 'CODE128',
      stockQty: Product.parseDouble(map['stock_qty']),
      stockInTotal: Product.parseDouble(map['stock_in_total']),
      stockOutTotal: Product.parseDouble(map['stock_out_total']),
      isActive: map['is_active'] as bool? ?? true,
    );
  }

  Future<List<Product>> getProducts(String businessId) async {
    try {
      final response = await _supabase.client
          .from(AppConstants.tableProducts)
          .select()
          .eq('business_id', businessId)
          .eq('is_active', true)
          .order('name');

      return (response as List<dynamic>)
          .map((row) => Product.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw NetworkException('Failed to load products: $e');
    }
  }

  Future<List<ClothingProductItem>> getClothingVariants(
    String businessId,
  ) async {
    try {
      final response = await _supabase.client
          .from(AppConstants.tableProductVariants)
          .select(
            '$_variantSelectCols, '
            'products(name, brand, category, sub_category)',
          )
          .eq('business_id', businessId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map(
            (row) => _mapClothingRow(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
    } catch (e) {
      throw NetworkException('Failed to load clothing products: $e');
    }
  }

  Future<ClothingProductItem> createClothingVariant({
    required String businessId,
    required String name,
    required String size,
    required String color,
    required double sellingPrice,
    required double taxRate,
    required String category,
    String? brand,
    String? subCategory,
    String? fabric,
    double costPrice = 0,
    double offerPercent = 0,
    double stockQty = 0,
    String? barcode,
  }) async {
    try {
      final product = await _supabase.client
          .from(AppConstants.tableProducts)
          .insert({
            'business_id': businessId,
            'name': name,
            'brand': brand,
            'category': category,
            'sub_category': subCategory,
            'is_active': true,
          })
          .select('id')
          .single();

      final stock = stockQty > 0 ? stockQty : 0.0;
      final insert = <String, dynamic>{
        'business_id': businessId,
        'product_id': product['id'],
        'size': size,
        'color': color,
        'fabric': fabric,
        'cost_price': costPrice < 0 ? 0 : costPrice,
        'selling_price': sellingPrice,
        'tax_rate': taxRate,
        'offer_percent': offerPercent,
        'stock_qty': stock,
        'stock_in_total': stock,
        'stock_out_total': 0,
        'is_active': true,
      };
      final barcodeTrim = barcode?.trim();
      if (barcodeTrim != null && barcodeTrim.isNotEmpty) {
        insert['barcode'] = barcodeTrim;
      }

      final variant = await _supabase.client
          .from(AppConstants.tableProductVariants)
          .insert(insert)
          .select(_variantSelectCols)
          .single();

      if (stock > 0) {
        try {
          final userId = _supabase.client.auth.currentUser?.id;
          await _supabase.client.from(AppConstants.tableStockMovements).insert({
            'business_id': businessId,
            'product_variant_id': variant['id'],
            'movement_type': 'in',
            'quantity': stock,
            'note': 'Opening stock',
            'created_by': userId,
          });
        } catch (_) {}
      }

      return _mapClothingRow(
        Map<String, dynamic>.from(variant),
        fallbackName: name,
        fallbackBrand: brand,
        fallbackCategory: category,
        fallbackSub: subCategory,
      );
    } catch (e) {
      throw NetworkException('Failed to create product: $e');
    }
  }

  Future<ClothingProductItem> updateClothingVariant({
    required String businessId,
    required String variantId,
    required String productId,
    required String name,
    required String size,
    required String color,
    required double sellingPrice,
    required double taxRate,
    required String category,
    String? brand,
    String? subCategory,
    String? fabric,
    double costPrice = 0,
    double offerPercent = 0,
    required String barcode,
  }) async {
    try {
      await _supabase.client.from(AppConstants.tableProducts).update({
        'name': name,
        'brand': brand,
        'category': category,
        'sub_category': subCategory,
      }).eq('id', productId).eq('business_id', businessId);

      final variant = await _supabase.client
          .from(AppConstants.tableProductVariants)
          .update({
            'size': size,
            'color': color,
            'fabric': fabric,
            'cost_price': costPrice < 0 ? 0 : costPrice,
            'selling_price': sellingPrice,
            'tax_rate': taxRate,
            'offer_percent': offerPercent,
            'barcode': barcode.trim(),
          })
          .eq('id', variantId)
          .eq('business_id', businessId)
          .select(_variantSelectCols)
          .single();

      return _mapClothingRow(
        Map<String, dynamic>.from(variant),
        fallbackName: name,
        fallbackBrand: brand,
        fallbackCategory: category,
        fallbackSub: subCategory,
      );
    } catch (e) {
      throw NetworkException('Failed to update product: $e');
    }
  }

  Future<void> deactivateVariant(String businessId, String variantId) async {
    try {
      await _supabase.client
          .from(AppConstants.tableProductVariants)
          .update({'is_active': false})
          .eq('id', variantId)
          .eq('business_id', businessId);
    } catch (e) {
      throw NetworkException('Failed to delete barcode: $e');
    }
  }

  Future<ProductVariant?> findVariantByBarcode(
    String businessId,
    String barcode,
  ) async {
    try {
      final response = await _supabase.client
          .from(AppConstants.tableProductVariants)
          .select('*, products(*)')
          .eq('business_id', businessId)
          .eq('barcode', barcode)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) return null;
      return ProductVariant.fromJson(response);
    } catch (e) {
      throw NetworkException('Failed to lookup barcode: $e');
    }
  }
}
