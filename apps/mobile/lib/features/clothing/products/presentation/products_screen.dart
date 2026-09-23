import 'dart:io';
import 'dart:ui' as ui;

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/clothing_categories.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../repositories/product_repository.dart';
import '../../../../services/stock_service.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../../../theme/app_colors.dart';
import '../../../business_selection/providers/business_provider.dart';
import '../../stock/presentation/stock_screen.dart';

final clothingProductsProvider =
    FutureProvider.autoDispose<List<ClothingProductItem>>((ref) async {
  final business = ref.watch(activeBusinessProvider);
  if (business == null || !business.isClothing) return [];
  return ref.read(productRepositoryProvider).getClothingVariants(business.id);
});

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _search = TextEditingController();
  final _money = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs.');
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openGenerate() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => const _GenerateProductSheet(),
    );
    if (created == true) {
      ref.invalidate(clothingProductsProvider);
    }
  }

  Future<void> _showBarcode(ClothingProductItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _BarcodePreviewSheet(item: item),
    );
  }

  Future<void> _adjustStock(ClothingProductItem item, StockMovementType type) async {
    final business = ref.read(activeBusinessProvider);
    if (business == null) return;
    final label = type == StockMovementType.in_ ? 'Stock In' : 'Stock Out';
    final controller = TextEditingController(text: '1');
    final qty = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Quantity'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim()) ?? 0;
              Navigator.pop(ctx, v);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (qty == null || !(qty > 0)) return;

    final result = await ref.read(stockServiceProvider).adjustVariantStock(
          businessId: business.id,
          variantId: item.id,
          type: type,
          quantity: qty,
          note: label,
        );
    if (!mounted) return;
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Stock update failed')),
      );
      return;
    }
    ref.invalidate(clothingProductsProvider);
    ref.invalidate(stockOverviewProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$label · ${qty.toStringAsFixed(0)} · now ${result.stockQty?.toStringAsFixed(0) ?? '-'}',
        ),
      ),
    );
  }

  Future<void> _delete(ClothingProductItem item) async {
    final business = ref.read(activeBusinessProvider);
    if (business == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete barcode?'),
        content: Text(
          'Delete ${item.barcode} (${item.name} · ${item.color})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(productRepositoryProvider)
          .deactivateVariant(business.id, item.id);
      ref.invalidate(clothingProductsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted · ${item.barcode}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final business = ref.watch(activeBusinessProvider);
    final brand = AppColors.brand(business?.businessType);
    final async = ref.watch(clothingProductsProvider);

    if (business != null && !business.isClothing) {
      return AppScaffold(
        title: 'Products',
        showBusinessSwitcher: false,
        body: const Center(child: Text('Products are for clothing desk only')),
      );
    }

    return AppScaffold(
      title: 'Products',
      showBusinessSwitcher: false,
      fallbackRoute: '/more',
      floatingActionButton: business?.isClothing == true
          ? FloatingActionButton.extended(
              onPressed: _openGenerate,
              icon: const Icon(Icons.add),
              label: const Text('Generate'),
            )
          : null,
      actions: [
        if (business?.isClothing == true)
          IconButton(
            tooltip: 'Stock by category',
            onPressed: () => context.push('/stock'),
            icon: const Icon(Icons.inventory_2_outlined),
          ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DeskHeader(
                  title: 'Products & Barcode',
                  subtitle: 'Compact barcode labels · Code 128',
                ),
                const SizedBox(height: 12),
                SoftSurface(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v.trim()),
                    decoration: const InputDecoration(
                      hintText: 'Search products or barcode…',
                      prefixIcon: Icon(Icons.search),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (items) {
                final q = _query.toLowerCase();
                final filtered = q.isEmpty
                    ? items
                    : items.where((p) {
                        return [
                          p.name,
                          p.brand,
                          p.category,
                          p.size,
                          p.color,
                          p.barcode,
                        ]
                            .whereType<String>()
                            .any((s) => s.toLowerCase().contains(q));
                      }).toList();

                if (filtered.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      SoftSurface(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        child: Column(
                          children: [
                            IconBadge(
                              icon: Icons.qr_code_2,
                              color: brand,
                              size: 52,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              items.isEmpty
                                  ? 'No barcodes yet'
                                  : 'No matches',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              items.isEmpty
                                  ? 'Tap Generate to create the first product barcode'
                                  : 'Try a different search',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.slate500,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                  itemCount: filtered.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          '${filtered.length} rows · Code 128',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.slate500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }
                    final item = filtered[i - 1];
                    final meta = [
                      if (item.category != null && item.category!.isNotEmpty)
                        item.category!,
                      if (item.size.isNotEmpty) 'Sz ${item.size}',
                      if (item.color.isNotEmpty) item.color,
                    ].join(' · ');
                    final hasStock = item.stockQty > 0;

                    return SoftSurface(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                      onTap: () => _showBarcode(item),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: AppColors.slate900,
                                      ),
                                    ),
                                    if (meta.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        meta,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.slate500,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.only(top: 2, right: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: hasStock
                                      ? AppColors.success.withValues(alpha: 0.1)
                                      : AppColors.error.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${item.stockQty.toStringAsFixed(0)} pcs',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: hasStock
                                        ? AppColors.success
                                        : AppColors.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _PriceCell(
                                  label: 'Cost',
                                  value: _money.format(item.costPrice),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _PriceCell(
                                  label: 'Sell',
                                  value: _money.format(item.sellingPrice),
                                  accent: brand,
                                ),
                              ),
                              if (item.offerPercent > 0) ...[
                                const SizedBox(width: 8),
                                _PriceCell(
                                  label: 'Offer',
                                  value:
                                      '${item.offerPercent.toStringAsFixed(0)}%',
                                  accent: AppColors.warning,
                                  compact: true,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.barcode.isEmpty ? '—' : item.barcode,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: brand,
                                  ),
                                ),
                              ),
                              _StockChipBtn(
                                label: 'In',
                                color: AppColors.success,
                                onTap: () => _adjustStock(
                                  item,
                                  StockMovementType.in_,
                                ),
                              ),
                              const SizedBox(width: 6),
                              _StockChipBtn(
                                label: 'Out',
                                color: AppColors.warning,
                                onTap: () => _adjustStock(
                                  item,
                                  StockMovementType.out,
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Delete',
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: AppColors.error,
                                ),
                                onPressed: () => _delete(item),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GenerateProductSheet extends ConsumerStatefulWidget {
  const _GenerateProductSheet();

  @override
  ConsumerState<_GenerateProductSheet> createState() =>
      _GenerateProductSheetState();
}

class _PriceCell extends StatelessWidget {
  const _PriceCell({
    required this.label,
    required this.value,
    this.accent,
    this.compact = false,
  });

  final String label;
  final String value;
  final Color? accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: accent != null
            ? accent!.withValues(alpha: 0.1)
            : AppColors.slate50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: accent ?? AppColors.slate500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: accent ?? AppColors.slate900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StockChipBtn extends StatelessWidget {
  const _StockChipBtn({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _GenerateProductSheetState extends ConsumerState<_GenerateProductSheet> {
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _size = TextEditingController();
  final _color = TextEditingController();
  final _cost = TextEditingController();
  final _price = TextEditingController();
  final _tax = TextEditingController(text: '12');
  final _offer = TextEditingController(text: '0');
  final _stock = TextEditingController(text: '0');
  String? _category;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _size.dispose();
    _color.dispose();
    _cost.dispose();
    _price.dispose();
    _tax.dispose();
    _offer.dispose();
    _stock.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final business = ref.read(activeBusinessProvider);
    if (business == null) return;
    final name = _name.text.trim();
    final size = _size.text.trim();
    final color = _color.text.trim();
    final category = _category?.trim() ?? '';
    final cost = double.tryParse(_cost.text.trim()) ?? 0;
    final price = double.tryParse(_price.text.trim()) ?? 0;
    final tax = double.tryParse(_tax.text.trim()) ?? 0;
    final offer = double.tryParse(_offer.text.trim()) ?? 0;
    final stock = double.tryParse(_stock.text.trim()) ?? 0;
    if (name.isEmpty ||
        size.isEmpty ||
        color.isEmpty ||
        !(price > 0) ||
        !isValidClothingCategory(category)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Name, category, size, color, and sell price are required',
          ),
        ),
      );
      return;
    }
    if (offer < 0 || offer > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offer % must be 0–100')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final item = await ref.read(productRepositoryProvider).createClothingVariant(
            businessId: business.id,
            name: name,
            brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
            category: category,
            size: size,
            color: color,
            costPrice: cost < 0 ? 0 : cost,
            sellingPrice: price,
            taxRate: tax,
            offerPercent: offer,
            stockQty: stock < 0 ? 0 : stock,
          );
      ref.invalidate(stockOverviewProvider);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Barcode generated · ${item.barcode}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'New clothing barcode',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            const SizedBox(height: 4),
            const Text(
              'Category · cost · sell · stock · Code 128',
              style: TextStyle(color: AppColors.slate500, fontSize: 13),
            ),
            const SizedBox(height: 16),
            const _SheetSection('Product'),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Product name *'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _category,
              decoration: const InputDecoration(labelText: 'Category *'),
              items: clothingCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _brand,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Brand'),
            ),
            const SizedBox(height: 14),
            const _SheetSection('Variant'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _size,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Size *'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _color,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Color *'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _SheetSection('Pricing & stock'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cost,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Cost price (₹)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Sell price *'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tax,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Tax %'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _offer,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Offer %'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _stock,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Opening stock',
                helperText: 'Baad me Stock In / Out se badlo',
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Generate barcode'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetSection extends StatelessWidget {
  const _SheetSection(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.0,
        color: AppColors.slate400,
      ),
    );
  }
}

class _BarcodePreviewSheet extends StatefulWidget {
  const _BarcodePreviewSheet({required this.item});

  final ClothingProductItem item;

  @override
  State<_BarcodePreviewSheet> createState() => _BarcodePreviewSheetState();
}

class _BarcodePreviewSheetState extends State<_BarcodePreviewSheet> {
  final _boundaryKey = GlobalKey();
  bool _sharing = false;

  Future<void> _sharePng() async {
    final code = widget.item.barcode;
    if (code.isEmpty) return;
    setState(() => _sharing = true);
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/barcode-$code.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '${widget.item.name} · $code',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.barcode.isEmpty ? 'No barcode' : item.barcode,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            [
              item.name,
              if (item.size.isNotEmpty) 'Size ${item.size}',
              if (item.color.isNotEmpty) item.color,
              CurrencyUtils.format(item.sellingPrice),
            ].join(' · '),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.slate500, fontSize: 13),
          ),
          const SizedBox(height: 16),
          if (item.barcode.isNotEmpty)
            RepaintBoundary(
              key: _boundaryKey,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (item.brand != null && item.brand!.isNotEmpty)
                      Text(
                        item.brand!,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    const SizedBox(height: 8),
                    BarcodeWidget(
                      barcode: Barcode.code128(),
                      data: item.barcode,
                      width: 260,
                      height: 80,
                      drawText: true,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      [
                        item.name,
                        if (item.size.isNotEmpty) item.size,
                        if (item.color.isNotEmpty) item.color,
                      ].join(' · '),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _sharing || item.barcode.isEmpty ? null : _sharePng,
            icon: _sharing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share_outlined),
            label: const Text('Share barcode PNG'),
          ),
        ],
      ),
    );
  }
}
