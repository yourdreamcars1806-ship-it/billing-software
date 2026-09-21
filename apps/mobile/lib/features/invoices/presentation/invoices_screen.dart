import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/business.dart';
import '../../../models/invoice.dart';
import '../../../repositories/invoice_repository.dart';
import '../../../services/pdf_invoice_service.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../../../theme/app_colors.dart';
import '../../business_selection/providers/business_provider.dart';
import '../providers/invoices_provider.dart';

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  int _filter = 0;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoicesProvider);
    final business = ref.watch(activeBusinessProvider);
    final brand = AppColors.brand(business?.businessType);
    final soft = AppColors.brandSoft(business?.businessType);
    final partialLabel = business?.isCar == true ? 'Token' : 'Partial';

    return AppScaffold(
      title: 'Invoices',
      body: RefreshIndicator(
        color: brand,
        onRefresh: () async => ref.invalidate(invoicesProvider),
        child: invoicesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              SoftSurface(
                child: Column(
                  children: [
                    Icon(Icons.error_outline, size: 40, color: AppColors.error),
                    const SizedBox(height: 10),
                    const Text(
                      'Could not load invoices',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.slate500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () => ref.invalidate(invoicesProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          data: (invoices) {
            final query = _search.text.trim().toLowerCase();
            final filtered = invoices.where((inv) {
              final statusOk = switch (_filter) {
                1 => inv.paymentStatus == PaymentStatus.paid,
                2 => inv.paymentStatus == PaymentStatus.partial,
                3 => inv.paymentStatus == PaymentStatus.pending,
                _ => true,
              };
              if (!statusOk) return false;
              if (query.isEmpty) return true;
              final customer = (inv.customer?.name ?? '').toLowerCase();
              return inv.invoiceNumber.toLowerCase().contains(query) ||
                  customer.contains(query);
            }).toList();

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: invoices.isEmpty ? 1 : filtered.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BrandBanner(
                        title: 'Invoices',
                        subtitle: business == null
                            ? 'Issued bills ledger'
                            : '${business.name} · view, download, WhatsApp',
                        brand: brand,
                        soft: soft,
                        icon: Icons.description_rounded,
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: brand.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${invoices.length}',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppColors.brandDark(business?.businessType),
                            ),
                          ),
                        ),
                      ),
                      if (invoices.isEmpty) ...[
                        const SizedBox(height: 36),
                        const EmptyState(
                          icon: Icons.description_outlined,
                          title: 'No invoices yet',
                          message:
                              'Create a bill — it will show here like on web',
                        ),
                      ] else ...[
                        const SizedBox(height: 14),
                        SoftSurface(
                          elevated: true,
                          padding: EdgeInsets.zero,
                          child: TextField(
                            controller: _search,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText: 'Search invoice # or customer…',
                              prefixIcon: Icon(Icons.search_rounded),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilterChipBar(
                          labels: ['All', 'Paid', partialLabel, 'Pending'],
                          selectedIndex: _filter,
                          onSelected: (i) => setState(() => _filter = i),
                          brand: brand,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${filtered.length} rows',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.slate500,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (filtered.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 28),
                            child: EmptyState(
                              icon: Icons.filter_list_off,
                              title: 'No matches',
                              message: 'Try another filter or search',
                            ),
                          ),
                      ],
                    ],
                  );
                }

                final invoice = filtered[index - 1];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _InvoiceCard(
                    invoice: invoice,
                    businessType: business?.businessType,
                    brand: brand,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _InvoiceCard extends ConsumerStatefulWidget {
  const _InvoiceCard({
    required this.invoice,
    required this.brand,
    this.businessType,
  });

  final Invoice invoice;
  final Color brand;
  final BusinessType? businessType;

  @override
  ConsumerState<_InvoiceCard> createState() => _InvoiceCardState();
}

class _InvoiceCardState extends ConsumerState<_InvoiceCard> {
  bool _busy = false;

  Future<void> _download() async {
    final business = ref.read(activeBusinessProvider);
    if (business == null) return;
    setState(() => _busy = true);
    try {
      // Load full invoice (items) like web before download
      final full = await ref
          .read(invoiceRepositoryProvider)
          .getInvoice(business.id, widget.invoice.id);
      final inv = full ?? widget.invoice;
      await PdfInvoiceService().downloadInvoice(
        business: business,
        invoice: inv,
        customerName: inv.customer?.name ?? widget.invoice.customer?.name,
        customerMobile: inv.customer?.mobile ?? widget.invoice.customer?.mobile,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Receipt ready · ${inv.invoiceNumber}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoice = widget.invoice;
    final brand = widget.brand;
    final statusColor = switch (invoice.paymentStatus) {
      PaymentStatus.paid => AppColors.success,
      PaymentStatus.partial => AppColors.warning,
      PaymentStatus.pending => AppColors.error,
    };
    final label = paymentStatusLabel(
      invoice.paymentStatus.name,
      businessType: widget.businessType,
    );
    final customerName = invoice.customer?.name.trim();
    final carLine = [
      if (invoice.carMake != null) invoice.carMake,
      if (invoice.carModel != null) invoice.carModel,
    ].whereType<String>().join(' ');

    return SoftSurface(
      elevated: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => context.push('/invoices/${invoice.id}'),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          invoice.invoiceNumber,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: brand,
                          ),
                        ),
                      ),
                      StatusBadge(label: label, color: statusColor),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    (customerName != null && customerName.isNotEmpty)
                        ? customerName
                        : (carLine.isNotEmpty ? carLine : 'Walk-in'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slate800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.event_outlined,
                        size: 14,
                        color: AppColors.slate400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        AppDateUtils.formatDate(invoice.invoiceDate),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.slate500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        CurrencyUtils.format(invoice.grandTotal),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Paid ${CurrencyUtils.format(invoice.amountPaid)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.slate200),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                _ActionChip(
                  icon: Icons.visibility_outlined,
                  label: 'View',
                  color: brand,
                  onTap: () => context.push('/invoices/${invoice.id}'),
                ),
                _ActionChip(
                  icon: Icons.download_rounded,
                  label: 'Download',
                  color: brand,
                  busy: _busy,
                  onTap: _busy ? null : _download,
                ),
                _ActionChip(
                  icon: Icons.print_outlined,
                  label: 'Print',
                  color: brand,
                  onTap: () => context.push('/invoices/${invoice.id}?print=bt'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextButton.icon(
        onPressed: onTap,
        icon: busy
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            : Icon(icon, size: 16, color: color),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }
}
