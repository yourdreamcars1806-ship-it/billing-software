import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../models/product.dart';
import 'supabase_service.dart';

final stockServiceProvider = Provider<StockService>((ref) {
  return StockService(ref.watch(supabaseServiceProvider));
});

enum StockMovementType { in_, out, adjust }

extension StockMovementTypeApi on StockMovementType {
  String get api {
    switch (this) {
      case StockMovementType.in_:
        return 'in';
      case StockMovementType.out:
        return 'out';
      case StockMovementType.adjust:
        return 'adjust';
    }
  }
}

class StockAdjustResult {
  const StockAdjustResult({
    required this.success,
    this.stockQty,
    this.error,
  });

  final bool success;
  final double? stockQty;
  final String? error;
}

class CategoryStockRow {
  const CategoryStockRow({
    required this.category,
    required this.inStockPcs,
    required this.inStockItems,
    required this.outOfStockItems,
    required this.buyValue,
    required this.sellValue,
    required this.soldPcs,
    required this.soldValue,
  });

  final String category;
  final double inStockPcs;
  final int inStockItems;
  final int outOfStockItems;
  final double buyValue;
  final double sellValue;
  final double soldPcs;
  final double soldValue;
}

class StockOverview {
  const StockOverview({
    required this.totals,
    required this.categories,
  });

  final CategoryStockRow totals;
  final List<CategoryStockRow> categories;
}

class StockService {
  StockService(this._supabase);

  final SupabaseService _supabase;

  Future<StockAdjustResult> adjustVariantStock({
    required String businessId,
    required String variantId,
    required StockMovementType type,
    required double quantity,
    String? note,
    String? invoiceId,
  }) async {
    final qty = quantity;
    if (!(qty > 0)) {
      return const StockAdjustResult(
        success: false,
        error: 'Quantity must be greater than 0',
      );
    }

    try {
      final client = _supabase.client;
      final variant = await client
          .from(AppConstants.tableProductVariants)
          .select('id, stock_qty, stock_in_total, stock_out_total')
          .eq('id', variantId)
          .eq('business_id', businessId)
          .maybeSingle();

      if (variant == null) {
        return const StockAdjustResult(
          success: false,
          error: 'Product not found',
        );
      }

      final current = Product.parseDouble(variant['stock_qty']);
      var stockIn = Product.parseDouble(variant['stock_in_total']);
      var stockOut = Product.parseDouble(variant['stock_out_total']);
      double nextQty = current;
      var moveQty = qty;

      if (type == StockMovementType.in_) {
        nextQty = current + qty;
        stockIn += qty;
      } else if (type == StockMovementType.out) {
        if (qty > current) {
          return StockAdjustResult(
            success: false,
            error: 'Only ${current.toStringAsFixed(0)} in stock',
          );
        }
        nextQty = current - qty;
        stockOut += qty;
      } else {
        final delta = qty - current;
        nextQty = qty;
        moveQty = delta.abs();
        if (delta > 0) {
          stockIn += delta;
        } else if (delta < 0) {
          stockOut += delta.abs();
        }
      }

      await client.from(AppConstants.tableProductVariants).update({
        'stock_qty': nextQty,
        'stock_in_total': stockIn,
        'stock_out_total': stockOut,
      }).eq('id', variantId).eq('business_id', businessId);

      if (moveQty > 0) {
        final userId = client.auth.currentUser?.id;
        try {
          await client.from(AppConstants.tableStockMovements).insert({
            'business_id': businessId,
            'product_variant_id': variantId,
            'movement_type': type.api,
            'quantity': moveQty,
            'note': note,
            'invoice_id': invoiceId,
            'created_by': userId,
          });
        } catch (_) {
          // Movement log optional if migration not applied
        }
      }

      return StockAdjustResult(success: true, stockQty: nextQty);
    } catch (e) {
      return StockAdjustResult(success: false, error: '$e');
    }
  }

  Future<void> stockOutForInvoiceLines({
    required String businessId,
    required String invoiceId,
    required List<({String? productVariantId, double quantity})> lines,
  }) async {
    final byVariant = <String, double>{};
    for (final line in lines) {
      final id = line.productVariantId?.trim();
      if (id == null || id.isEmpty || !(line.quantity > 0)) continue;
      byVariant[id] = (byVariant[id] ?? 0) + line.quantity;
    }

    for (final entry in byVariant.entries) {
      await adjustVariantStock(
        businessId: businessId,
        variantId: entry.key,
        type: StockMovementType.out,
        quantity: entry.value,
        note: 'Sold on invoice',
        invoiceId: invoiceId,
      );
    }
  }

  Future<StockOverview> loadStockOverview(String businessId) async {
    try {
      final rpc = await _supabase.client.rpc(
        'clothing_stock_by_category',
        params: {'p_business_id': businessId},
      );
      final parsed = _parseRpc(rpc);
      if (parsed != null) return parsed;
    } catch (_) {
      // Fallback below
    }

    try {
      final response = await _supabase.client
          .from(AppConstants.tableProductVariants)
          .select(
            'stock_qty, cost_price, selling_price, stock_out_total, '
            'products(category)',
          )
          .eq('business_id', businessId)
          .eq('is_active', true);

      return _summarizeRows(
        (response as List<dynamic>).map((row) {
          final map = Map<String, dynamic>.from(row as Map);
          final products = map['products'];
          Map<String, dynamic>? p;
          if (products is Map) {
            p = Map<String, dynamic>.from(products);
          } else if (products is List &&
              products.isNotEmpty &&
              products.first is Map) {
            p = Map<String, dynamic>.from(products.first as Map);
          }
          return (
            category: p?['category'] as String?,
            stockQty: Product.parseDouble(map['stock_qty']),
            costPrice: Product.parseDouble(map['cost_price']),
            sellingPrice: Product.parseDouble(map['selling_price']),
            stockOutTotal: Product.parseDouble(map['stock_out_total']),
          );
        }).toList(),
      );
    } catch (e) {
      throw NetworkException('Failed to load stock: $e');
    }
  }

  StockOverview? _parseRpc(dynamic payload) {
    if (payload is! Map) return null;
    final data = Map<String, dynamic>.from(payload);
    final t = Map<String, dynamic>.from(
      (data['totals'] as Map?) ?? const {},
    );
    final cats = (data['categories'] as List?) ?? const [];
    final categories = cats.map((c) {
      final m = Map<String, dynamic>.from(c as Map);
      return CategoryStockRow(
        category: (m['category'] as String?) ?? 'Other',
        inStockPcs: Product.parseDouble(m['in_stock_pcs']),
        inStockItems: Product.parseDouble(m['in_stock_items']).round(),
        outOfStockItems: Product.parseDouble(m['out_of_stock_items']).round(),
        buyValue: Product.parseDouble(m['buy_value']),
        sellValue: Product.parseDouble(m['sell_value']),
        soldPcs: Product.parseDouble(m['sold_pcs']),
        soldValue: Product.parseDouble(m['sold_value']),
      );
    }).toList();

    return StockOverview(
      totals: CategoryStockRow(
        category: 'Total',
        inStockPcs: Product.parseDouble(t['in_stock_pcs']),
        inStockItems: Product.parseDouble(t['in_stock_items']).round(),
        outOfStockItems: Product.parseDouble(t['out_of_stock_items']).round(),
        buyValue: Product.parseDouble(t['buy_value']),
        sellValue: Product.parseDouble(t['sell_value']),
        soldPcs: Product.parseDouble(t['sold_pcs']),
        soldValue: Product.parseDouble(t['sold_value']),
      ),
      categories: categories,
    );
  }

  StockOverview _summarizeRows(
    List<
            ({
              String? category,
              double stockQty,
              double costPrice,
              double sellingPrice,
              double stockOutTotal
            })>
        rows,
  ) {
    final map = <String, CategoryStockRow>{};
    for (final row in rows) {
      final cat = (row.category?.trim().isNotEmpty == true)
          ? row.category!.trim()
          : 'Other';
      final prev = map[cat] ??
          CategoryStockRow(
            category: cat,
            inStockPcs: 0,
            inStockItems: 0,
            outOfStockItems: 0,
            buyValue: 0,
            sellValue: 0,
            soldPcs: 0,
            soldValue: 0,
          );
      final qty = row.stockQty;
      final sold = row.stockOutTotal;
      map[cat] = CategoryStockRow(
        category: cat,
        inStockPcs: prev.inStockPcs + (qty > 0 ? qty : 0),
        inStockItems: prev.inStockItems + (qty > 0 ? 1 : 0),
        outOfStockItems: prev.outOfStockItems + (qty <= 0 ? 1 : 0),
        buyValue: prev.buyValue + (qty > 0 ? qty * row.costPrice : 0),
        sellValue: prev.sellValue + (qty > 0 ? qty * row.sellingPrice : 0),
        soldPcs: prev.soldPcs + sold,
        soldValue: prev.soldValue + sold * row.sellingPrice,
      );
    }

    final categories = map.values.toList()
      ..sort((a, b) => a.category.compareTo(b.category));
    var totals = const CategoryStockRow(
      category: 'Total',
      inStockPcs: 0,
      inStockItems: 0,
      outOfStockItems: 0,
      buyValue: 0,
      sellValue: 0,
      soldPcs: 0,
      soldValue: 0,
    );
    for (final c in categories) {
      totals = CategoryStockRow(
        category: 'Total',
        inStockPcs: totals.inStockPcs + c.inStockPcs,
        inStockItems: totals.inStockItems + c.inStockItems,
        outOfStockItems: totals.outOfStockItems + c.outOfStockItems,
        buyValue: totals.buyValue + c.buyValue,
        sellValue: totals.sellValue + c.sellValue,
        soldPcs: totals.soldPcs + c.soldPcs,
        soldValue: totals.soldValue + c.soldValue,
      );
    }
    return StockOverview(totals: totals, categories: categories);
  }
}
