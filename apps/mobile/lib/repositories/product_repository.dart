import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../models/product.dart';
import '../services/supabase_service.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(ref.watch(supabaseServiceProvider));
});

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
    this.brand,
    this.category,
    this.subCategory,
    this.fabric,
    this.barcodeFormat = 'CODE128',
    this.isActive = true,
  });

  final String id;
  final String businessId;
  final String name;
  final String? brand;
  final String? category;
  final String? subCategory;
  final String size;
  final String color;
  final String? fabric;
  final double sellingPrice;
  final double taxRate;
  final String barcode;
  final String barcodeFormat;
  final bool isActive;
}

class ProductRepository {
  ProductRepository(this._supabase);

  final SupabaseService _supabase;

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
            'id, business_id, size, color, fabric, selling_price, tax_rate, '
            'barcode, barcode_format, is_active, '
            'products(name, brand, category, sub_category)',
          )
          .eq('business_id', businessId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return (response as List<dynamic>).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
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
          name: (p?['name'] as String?) ?? 'Product',
          brand: p?['brand'] as String?,
          category: p?['category'] as String?,
          subCategory: p?['sub_category'] as String?,
          size: (map['size'] as String?) ?? '',
          color: (map['color'] as String?) ?? '',
          fabric: map['fabric'] as String?,
          sellingPrice: Product.parseDouble(map['selling_price']),
          taxRate: Product.parseDouble(map['tax_rate']),
          barcode: (map['barcode'] as String?) ?? '',
          barcodeFormat: (map['barcode_format'] as String?) ?? 'CODE128',
          isActive: map['is_active'] as bool? ?? true,
        );
      }).toList();
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
    String? brand,
    String? category,
    String? subCategory,
    String? fabric,
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

      final variant = await _supabase.client
          .from(AppConstants.tableProductVariants)
          .insert({
            'business_id': businessId,
            'product_id': product['id'],
            'size': size,
            'color': color,
            'fabric': fabric,
            'selling_price': sellingPrice,
            'tax_rate': taxRate,
            'is_active': true,
          })
          .select(
            'id, business_id, size, color, fabric, selling_price, tax_rate, '
            'barcode, barcode_format, is_active',
          )
          .single();

      return ClothingProductItem(
        id: variant['id'] as String,
        businessId: variant['business_id'] as String,
        name: name,
        brand: brand,
        category: category,
        subCategory: subCategory,
        size: (variant['size'] as String?) ?? size,
        color: (variant['color'] as String?) ?? color,
        fabric: variant['fabric'] as String?,
        sellingPrice: Product.parseDouble(variant['selling_price']),
        taxRate: Product.parseDouble(variant['tax_rate']),
        barcode: (variant['barcode'] as String?) ?? '',
        barcodeFormat: (variant['barcode_format'] as String?) ?? 'CODE128',
        isActive: variant['is_active'] as bool? ?? true,
      );
    } catch (e) {
      throw NetworkException('Failed to create product: $e');
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
