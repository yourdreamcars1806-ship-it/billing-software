import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../theme/app_colors.dart';
import '../models/scanned_product.dart';
import '../services/barcode_service.dart';

class BarcodeScannerScreen extends ConsumerStatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  ConsumerState<BarcodeScannerScreen> createState() =>
      _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    formats: const [BarcodeFormat.code128],
  );
  final _money = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs.');
  bool _busy = false;
  String? _status;
  ScannedProduct? _found;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleCode(String raw) async {
    if (_busy || _found != null) return;
    final code = raw.trim();
    if (code.isEmpty) return;

    setState(() {
      _busy = true;
      _status = 'Looking up $code…';
      _found = null;
    });

    final product =
        await ref.read(barcodeServiceProvider).lookupScannedProduct(code);

    if (!mounted) return;

    if (product != null) {
      HapticFeedback.mediumImpact();
      setState(() {
        _busy = false;
        _found = product;
        _status = 'Product found';
      });
      return;
    }

    setState(() {
      _busy = false;
      _status = 'No product for $code';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Product not found for barcode: $code')),
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null) return;
    await _handleCode(barcode);
  }

  Future<void> _manualEntry() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter barcode'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'e.g. DD2603000001',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Find'),
          ),
        ],
      ),
    );
    if (code != null && code.isNotEmpty) {
      await _handleCode(code);
    }
  }

  void _confirmAdd() {
    final product = _found;
    if (product == null) return;
    context.pop(product.toMap());
  }

  void _scanAgain() {
    setState(() {
      _found = null;
      _busy = false;
      _status = 'Point camera at clothing barcode (Code 128)';
    });
  }

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;
    final found = _found;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        backgroundColor: AppColors.slate900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Torch',
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flash_on),
          ),
          IconButton(
            tooltip: 'Manual entry',
            onPressed: (_busy || found != null) ? null : _manualEntry,
            icon: const Icon(Icons.keyboard),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (found == null)
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            )
          else
            ColoredBox(color: Colors.black.withValues(alpha: 0.85)),
          if (found == null)
            Center(
              child: Container(
                width: 260,
                height: 140,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: found != null
                ? _ProductPreviewCard(
                    product: found,
                    money: _money,
                    brand: brand,
                    onAdd: _confirmAdd,
                    onScanAgain: _scanAgain,
                  )
                : Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_scanner, size: 32, color: brand),
                        const SizedBox(height: 8),
                        Text(
                          _status ??
                              'Point camera at clothing barcode (Code 128)',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.slate800,
                          ),
                        ),
                        if (_busy) ...[
                          const SizedBox(height: 12),
                          LinearProgressIndicator(color: brand),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => context.pop(),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton(
                                onPressed: _busy ? null : _manualEntry,
                                child: const Text('Type code'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProductPreviewCard extends StatelessWidget {
  const _ProductPreviewCard({
    required this.product,
    required this.money,
    required this.brand,
    required this.onAdd,
    required this.onScanAgain,
  });

  final ScannedProduct product;
  final NumberFormat money;
  final Color brand;
  final VoidCallback onAdd;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    final title = [
      if (product.brand != null && product.brand!.isNotEmpty) product.brand!,
      product.name,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: brand.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Product found',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: AppColors.slate900,
            ),
          ),
          if (product.barcode.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              product.barcode,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: AppColors.slate500,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (product.size != null && product.size!.isNotEmpty)
                _InfoChip(label: 'Size', value: product.size!),
              if (product.color != null && product.color!.isNotEmpty)
                _InfoChip(label: 'Color', value: product.color!),
              if (product.fabric != null && product.fabric!.isNotEmpty)
                _InfoChip(label: 'Fabric', value: product.fabric!),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.clothingSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.clothingBorder),
            ),
            child: Row(
              children: [
                const Text(
                  'Price',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate700,
                  ),
                ),
                const Spacer(),
                Text(
                  money.format(product.sellingPrice),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: brand,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tax ${product.taxRate.toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 12, color: AppColors.slate500),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Add to bill'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onScanAgain,
            child: const Text('Scan another'),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label  ',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.slate500,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.slate900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
