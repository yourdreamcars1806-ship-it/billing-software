import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/env.dart';
import '../../../../data/demo_clothing_products.dart';
import '../../../../models/product.dart';
import '../../../../repositories/product_repository.dart';
import '../../../business_selection/providers/business_provider.dart';
import '../models/scanned_product.dart';

final barcodeLookupProvider =
    FutureProvider.family<ProductVariant?, String>((ref, barcode) async {
  return ref.watch(barcodeServiceProvider).lookupBarcode(barcode);
});

class BarcodeService {
  BarcodeService(this._ref);

  final Ref _ref;

  Future<ScannedProduct?> lookupScannedProduct(String barcode) async {
    final business = _ref.read(activeBusinessProvider);
    if (business == null || !business.isClothing) return null;

    final code = barcode.trim().toUpperCase();
    if (code.isEmpty) return null;

    // Demo catalog (works without Supabase; also fallback)
    final demo = findDemoProductByBarcode(code);
    if (demo != null &&
        (!Env.isConfigured ||
            business.id == demoClothingBusinessId ||
            business.slug == 'drape-and-dream')) {
      return ScannedProduct(
        variantId: demo.id,
        barcode: demo.barcode,
        name: demo.name,
        brand: demo.brand,
        size: demo.size,
        color: demo.color,
        fabric: demo.fabric,
        sellingPrice: demo.sellingPrice,
        taxRate: demo.taxRate,
      );
    }

    if (!Env.isConfigured) {
      return demo == null
          ? null
          : ScannedProduct(
              variantId: demo.id,
              barcode: demo.barcode,
              name: demo.name,
              brand: demo.brand,
              size: demo.size,
              color: demo.color,
              fabric: demo.fabric,
              sellingPrice: demo.sellingPrice,
              taxRate: demo.taxRate,
            );
    }

    try {
      final variant = await _ref
          .read(productRepositoryProvider)
          .findVariantByBarcode(business.id, code);
      if (variant == null) {
        // Fallback to demo barcodes for testing
        if (demo != null) {
          return ScannedProduct(
            variantId: demo.id,
            barcode: demo.barcode,
            name: demo.name,
            brand: demo.brand,
            size: demo.size,
            color: demo.color,
            fabric: demo.fabric,
            sellingPrice: demo.sellingPrice,
            taxRate: demo.taxRate,
          );
        }
        return null;
      }

      return ScannedProduct(
        variantId: variant.id,
        barcode: variant.barcode ?? code,
        name: variant.productName ?? 'Item',
        brand: variant.productBrand,
        size: variant.size,
        color: variant.color,
        fabric: variant.fabric,
        sellingPrice: variant.sellingPrice,
        taxRate: variant.taxRate,
      );
    } catch (_) {
      if (demo != null) {
        return ScannedProduct(
          variantId: demo.id,
          barcode: demo.barcode,
          name: demo.name,
          brand: demo.brand,
          size: demo.size,
          color: demo.color,
          fabric: demo.fabric,
          sellingPrice: demo.sellingPrice,
          taxRate: demo.taxRate,
        );
      }
      return null;
    }
  }

  Future<ProductVariant?> lookupBarcode(String barcode) async {
    final scanned = await lookupScannedProduct(barcode);
    if (scanned == null) return null;
    return ProductVariant(
      id: scanned.variantId,
      businessId: _ref.read(activeBusinessProvider)?.id ?? '',
      productId: scanned.variantId,
      sellingPrice: scanned.sellingPrice,
      taxRate: scanned.taxRate,
      size: scanned.size,
      color: scanned.color,
      fabric: scanned.fabric,
      barcode: scanned.barcode,
      productName: scanned.name,
      productBrand: scanned.brand,
    );
  }
}

final barcodeServiceProvider = Provider<BarcodeService>((ref) {
  return BarcodeService(ref);
});
