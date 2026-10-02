import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../models/delivery_note.dart';
import '../../../repositories/delivery_note_repository.dart';
import '../../../services/pdf_delivery_note_service.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../../../theme/app_colors.dart';
import '../../business_selection/providers/business_provider.dart';

class DeliveryNotesScreen extends ConsumerStatefulWidget {
  const DeliveryNotesScreen({super.key});

  @override
  ConsumerState<DeliveryNotesScreen> createState() =>
      _DeliveryNotesScreenState();
}

class _DeliveryNotesScreenState extends ConsumerState<DeliveryNotesScreen> {
  List<DeliveryNote> _notes = [];
  bool _loading = true;
  String? _error;
  String? _message;
  String _filter = 'all'; // all | draft | confirmed | cancelled
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final business = ref.read(activeBusinessProvider);
    if (business == null || !business.isCar) {
      setState(() {
        _loading = false;
        _error = 'Delivery notes are only available for car businesses';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ref
          .read(deliveryNoteRepositoryProvider)
          .listDeliveryNotes(business.id);
      if (!mounted) return;
      setState(() {
        _notes = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().contains('delivery_notes') ||
                e.toString().contains('PGRST')
            ? 'Run Supabase migrations 00009→00011 (delivery_notes), then refresh.'
            : e.toString();
      });
    }
  }

  List<DeliveryNote> get _filtered {
    if (_filter == 'all') return _notes;
    return _notes.where((n) => (n.deliveryStatus) == _filter).toList();
  }

  Future<void> _open(DeliveryNote note) async {
    await context.push<bool>('/delivery-notes/${note.id}');
    await _load();
  }

  Future<void> _startNew() async {
    final business = ref.read(activeBusinessProvider);
    if (business == null) return;
    setState(() => _busy = true);
    try {
      final no = await ref
          .read(deliveryNoteRepositoryProvider)
          .allocateDeliveryNoteNumber(business.id);
      if (!mounted) return;
      await context.push<bool>(
        '/delivery-notes/new',
        extra: {'noteNo': no},
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      final fallback =
          'YDC-DN-${DateTime.now().millisecondsSinceEpoch % 100000}';
      await context.push<bool>(
        '/delivery-notes/new',
        extra: {'noteNo': fallback, 'allocError': e.toString()},
      );
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(DeliveryNote note) async {
    final business = ref.read(activeBusinessProvider);
    if (business == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete delivery note?'),
        content: Text(
          'Permanently delete ${note.deliveryNoteNumber} from database? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final result = await ref
        .read(deliveryNoteRepositoryProvider)
        .deleteDeliveryNote(business.id, note.id);
    if (!mounted) return;
    if (!result.success) {
      setState(() => _error = result.error);
      return;
    }
    setState(() => _message = 'Deleted from database · ${note.deliveryNoteNumber}');
    await _load();
  }

  Future<void> _previewPdf(DeliveryNote note) async {
    final business = ref.read(activeBusinessProvider);
    if (business == null) return;
    setState(() => _busy = true);
    try {
      await PdfDeliveryNoteService().sharePdf(
        business: business,
        data: note.toForm(businessName: business.name),
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'PDF failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final business = ref.watch(activeBusinessProvider);
    final brand = AppColors.brand(business?.businessType);
    final soft = AppColors.brandSoft(business?.businessType);
    final stats = DeliveryNoteSummary.fromRows(_notes);

    return AppScaffold(
      title: 'Delivery notes',
      showBusinessSwitcher: false,
      showBack: true,
      fallbackRoute: '/more',
      floatingActionButton: business?.isCar == true
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : _startNew,
              backgroundColor: brand,
              icon: const Icon(Icons.note_add_rounded),
              label: const Text('New note'),
            )
          : null,
      body: RefreshIndicator(
        color: brand,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0B1F4D),
                    Color(0xFF123A8C),
                    Color(0xFF1D4ED8),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: brand.withValues(alpha: 0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YOUR DREAM CARS · OPERATIONS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Vehicle Delivery Desk',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Create, confirm or cancel delivery notes — same as web, with A4 PDF.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Total',
                    value: stats.total,
                    hint: 'All saved',
                    color: AppColors.slate800,
                    soft: AppColors.slate100,
                    selected: _filter == 'all',
                    onTap: () => setState(() => _filter = 'all'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    label: 'Confirmed',
                    value: stats.confirmed,
                    hint: 'Handed over',
                    color: AppColors.success,
                    soft: const Color(0xFFECFDF5),
                    selected: _filter == 'confirmed',
                    onTap: () => setState(() => _filter = 'confirmed'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    label: 'Cancelled',
                    value: stats.cancelled,
                    hint: 'Deal cancelled',
                    color: AppColors.error,
                    soft: const Color(0xFFFEF2F2),
                    selected: _filter == 'cancelled',
                    onTap: () => setState(() => _filter = 'cancelled'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_message != null)
              _Banner(
                text: _message!,
                color: AppColors.success,
                onClose: () => setState(() => _message = null),
              ),
            if (_error != null)
              _Banner(
                text: _error!,
                color: AppColors.error,
                onClose: () => setState(() => _error = null),
              ),
            SoftSurface(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                    child: Row(
                      children: [
                        Icon(Icons.description_rounded, size: 18, color: brand),
                        const SizedBox(width: 8),
                        const Text(
                          'Delivery notes',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: soft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${_filtered.length}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: brand,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Row(
                      children: [
                        for (final e in const [
                          ('all', 'All'),
                          ('draft', 'Draft'),
                          ('confirmed', 'Confirmed'),
                          ('cancelled', 'Cancelled'),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(e.$2),
                              selected: _filter == e.$1,
                              onSelected: (_) =>
                                  setState(() => _filter = e.$1),
                              selectedColor: brand,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _filter == e.$1
                                    ? Colors.white
                                    : AppColors.slate600,
                              ),
                              side: BorderSide(
                                color: _filter == e.$1
                                    ? brand
                                    : AppColors.slate200,
                              ),
                              backgroundColor: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    )
                  else if (_filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 36, 20, 40),
                      child: Column(
                        children: [
                          Icon(
                            Icons.note_alt_outlined,
                            size: 40,
                            color: AppColors.slate300,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'No notes in this filter',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.slate600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tap New note to create one',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.slate400,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._filtered.map((note) {
                      return _NoteTile(
                        note: note,
                        brand: brand,
                        onOpen: () => _open(note),
                        onPdf: () => _previewPdf(note),
                        onDelete: () => _delete(note),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SoftSurface(
              color: soft,
              borderColor: brand.withValues(alpha: 0.25),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Workflow',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Save → draft · Confirm → delivered · Cancel → deal cancelled (GST + fees clause still on print).',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.slate600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.hint,
    required this.color,
    required this.soft,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int value;
  final String hint;
  final Color color;
  final Color soft;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: soft,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : AppColors.slate200,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: AppColors.slate500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              Text(
                hint,
                style: const TextStyle(fontSize: 10, color: AppColors.slate400),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.text,
    required this.color,
    required this.onClose,
  });
  final String text;
  final Color color;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close, size: 18, color: color),
          ),
        ],
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.note,
    required this.brand,
    required this.onOpen,
    required this.onPdf,
    required this.onDelete,
  });

  final DeliveryNote note;
  final Color brand;
  final VoidCallback onOpen;
  final VoidCallback onPdf;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final vehicle = [note.carMake, note.carModelVariant]
        .whereType<String>()
        .where((x) => x.trim().isNotEmpty)
        .map((x) => x.trim())
        .join(' ');
    final meta = _statusMeta(note.deliveryStatus);
    String dateLabel = note.deliveryDate;
    final parsed = DateTime.tryParse(note.deliveryDate);
    if (parsed != null) {
      dateLabel = DateFormat('dd MMM yyyy').format(parsed);
    }

    return InkWell(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.slate100)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          note.deliveryNoteNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: meta.$2,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: meta.$3),
                        ),
                        child: Text(
                          meta.$1,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: meta.$4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    note.customerName.isEmpty ? '—' : note.customerName,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.slate700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (vehicle.isNotEmpty) vehicle,
                      if (note.carRegistrationNumber?.trim().isNotEmpty == true)
                        note.carRegistrationNumber!.trim(),
                      dateLabel,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.slate400,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'PDF',
              onPressed: onPdf,
              icon: Icon(Icons.picture_as_pdf_outlined, color: brand, size: 20),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  (String, Color, Color, Color) _statusMeta(String status) {
    if (status == 'confirmed') {
      return (
        'Confirmed',
        const Color(0xFFD1FAE5),
        const Color(0xFFA7F3D0),
        const Color(0xFF065F46),
      );
    }
    if (status == 'cancelled') {
      return (
        'Cancelled',
        const Color(0xFFFEE2E2),
        const Color(0xFFFECACA),
        const Color(0xFF991B1B),
      );
    }
    return (
      'Draft',
      AppColors.slate100,
      AppColors.slate200,
      AppColors.slate700,
    );
  }
}
