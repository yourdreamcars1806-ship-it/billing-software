import 'dart:io';
import 'dart:ui' as ui;

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/utils/currency_utils.dart';
import '../../../../repositories/product_repository.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../../../theme/app_colors.dart';
import '../../../business_selection/providers/business_provider.dart';

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
                    return SoftSurface(
                      margin: const EdgeInsets.only(bottom: 10),
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
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (item.brand != null &&
                                        item.brand!.isNotEmpty)
                                      Text(
                                        item.brand!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.slate500,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Share PNG',
                                icon: Icon(Icons.download_outlined, color: brand),
                                onPressed: () => _showBarcode(item),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Delete',
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.error,
                                ),
                                onPressed: () => _delete(item),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (item.size.isNotEmpty)
                                _Pill(label: 'Size', value: item.size),
                              if (item.color.isNotEmpty)
                                _Pill(label: 'Color', value: item.color),
                              _Pill(
                                label: 'Price',
                                value: _money.format(item.sellingPrice),
                                strong: true,
                                color: brand,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.barcode.isEmpty ? '—' : item.barcode,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: brand,
                            ),
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

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.value,
    this.strong = false,
    this.color,
  });

  final String label;
  final String value;
  final bool strong;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.slate700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: strong ? accent.withValues(alpha: 0.1) : AppColors.slate100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: strong ? accent.withValues(alpha: 0.28) : AppColors.slate200,
        ),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: strong ? accent : AppColors.slate500,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: strong ? accent : AppColors.slate900,
              ),
            ),
          ],
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
  final _price = TextEditingController();
  final _tax = TextEditingController(text: '12');
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _size.dispose();
    _color.dispose();
    _price.dispose();
    _tax.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final business = ref.read(activeBusinessProvider);
    if (business == null) return;
    final name = _name.text.trim();
    final size = _size.text.trim();
    final color = _color.text.trim();
    final price = double.tryParse(_price.text.trim()) ?? 0;
    final tax = double.tryParse(_tax.text.trim()) ?? 0;
    if (name.isEmpty || size.isEmpty || color.isEmpty || !(price > 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name, size, color, and price are required'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final item = await ref.read(productRepositoryProvider).createClothingVariant(
            businessId: business.id,
            name: name,
            brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
            size: size,
            color: color,
            sellingPrice: price,
            taxRate: tax,
          );
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
              'Code 128 auto-creates on save',
              style: TextStyle(color: AppColors.slate500, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Product name *'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _brand,
              decoration: const InputDecoration(labelText: 'Brand'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _size,
                    decoration: const InputDecoration(labelText: 'Size *'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _color,
                    decoration: const InputDecoration(labelText: 'Color *'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Price *'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _tax,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Tax %'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
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
