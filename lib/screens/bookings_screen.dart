import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/app_provider.dart';
import '../widgets/channel_badge.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});
  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  String? _unitId;
  String _from = '';
  String _to = '';
  List<Map<String, dynamic>> _rows = [];
  bool _loading = false;
  String _msg = '';

  @override
  void initState() {
    super.initState();
    final prov = context.read<AppProvider>();
    if (prov.units.isNotEmpty) {
      _unitId = prov.units.first['id'];
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _msg = '';
    });
    try {
      final prov = context.read<AppProvider>();
      final uid = _unitId;
      final f = _from.isNotEmpty ? _from : null;
      final t = _to.isNotEmpty ? _to : null;
      final data = await prov.api.getBookings(unitId: uid, from: f, to: t);
      setState(() =>
          _rows = List<Map<String, dynamic>>.from(data['bookings'] ?? []));
    } catch (e) {
      setState(() => _msg = 'Error: $e');
    }
    setState(() => _loading = false);
  }

  Future<void> _save(Map<String, dynamic> b, Map<String, dynamic> patch) async {
    try {
      final prov = context.read<AppProvider>();
      await prov.api.updateBooking(b['id'], patch);
      await _load();
      setState(() => _msg = '✅');
    } catch (e) {
      setState(() => _msg = 'Error: $e');
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final isRtl = prov.isRtl;
    final units = prov.units;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(isRtl ? 'الحجوزات' : 'Bookings',
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            isRtl
                ? 'أضف المبالغ لكل حجز (إجمالي، عمولة، ضرائب، رسوم).'
                : 'Add financials for each booking (gross, commission, taxes, fees).',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),

          // Filters
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      value: _unitId,
                      isDense: true,
                      decoration: InputDecoration(
                        labelText: isRtl ? 'الوحدة' : 'Unit',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                      ),
                      items: units
                          .map((u) => DropdownMenuItem(
                                value: u['id'] as String,
                                child: Text(u['name'] ?? '',
                                    style: const TextStyle(fontSize: 12)),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _unitId = v),
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: isRtl ? 'من' : 'From',
                        hintText: 'YYYY-MM-DD',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                      ),
                      style: const TextStyle(fontSize: 12),
                      onChanged: (v) => _from = v,
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: isRtl ? 'إلى' : 'To',
                        hintText: 'YYYY-MM-DD',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                      ),
                      style: const TextStyle(fontSize: 12),
                      onChanged: (v) => _to = v,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.search_rounded, size: 16),
                    label: Text(isRtl ? 'تحميل' : 'Load',
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),

          if (_msg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_msg,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
            ),

          const SizedBox(height: 12),

          if (_loading)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator()))
          else if (_rows.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text(
                    isRtl
                        ? 'لا توجد حجوزات. جرب المزامنة أولاً.'
                        : 'No bookings. Try Sync first.',
                    style: const TextStyle(color: AppTheme.textSecondary)),
              ),
            )
          else
            ..._rows.map((b) => _BookingCard(
                  booking: b,
                  isRtl: isRtl,
                  onSave: (patch) => _save(b, patch),
                  formatDate: _formatDate,
                )),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool isRtl;
  final Function(Map<String, dynamic>) onSave;
  final String Function(String?) formatDate;

  const _BookingCard({
    required this.booking,
    required this.isRtl,
    required this.onSave,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final channel = booking['channel'] ?? '';
    final start = formatDate(booking['startDate']);
    final end = formatDate(booking['endDate']);
    final gross = booking['grossAmount'];
    final net = booking['netAmount'];
    final currency = booking['currency'] ?? 'BHD';
    final status = booking['paymentStatus'] ?? 'UNPAID';
    final notes = booking['notes'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ChannelBadge(channel: channel),
                const SizedBox(width: 8),
                Text('$start → $end',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: status == 'PAID'
                        ? AppTheme.success.withValues(alpha: 0.1)
                        : status == 'PARTIAL'
                            ? AppTheme.warning.withValues(alpha: 0.1)
                            : AppTheme.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: status == 'PAID'
                          ? AppTheme.success
                          : status == 'PARTIAL'
                              ? AppTheme.warning
                              : AppTheme.danger,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _field(isRtl ? 'إجمالي' : 'Gross', gross, currency),
                _field(isRtl ? 'صافي' : 'Net', net, currency),
                if (notes.isNotEmpty)
                  Text('📝 $notes',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _showEditDialog(context),
                  child: Text(isRtl ? 'تعديل' : 'Edit',
                      style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, dynamic value, String currency) {
    return Text(
      '$label: ${value ?? '—'} $currency',
      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
    );
  }

  void _showEditDialog(BuildContext context) {
    final grossC =
        TextEditingController(text: booking['grossAmount']?.toString() ?? '');
    final commC = TextEditingController(
        text: booking['commissionAmount']?.toString() ?? '');
    final taxC =
        TextEditingController(text: booking['taxAmount']?.toString() ?? '');
    final feesC = TextEditingController(
        text: booking['otherFeesAmount']?.toString() ?? '');
    final notesC =
        TextEditingController(text: booking['notes']?.toString() ?? '');
    String payStatus = booking['paymentStatus'] ?? 'UNPAID';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isRtl ? 'تعديل الحجز' : 'Edit Booking'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: grossC,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: isRtl ? 'إجمالي' : 'Gross'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: commC,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: isRtl ? 'عمولة' : 'Commission'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: taxC,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: isRtl ? 'ضرائب' : 'Taxes'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: feesC,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: isRtl ? 'رسوم' : 'Fees'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: payStatus,
                  decoration: InputDecoration(
                      labelText: isRtl ? 'حالة الدفع' : 'Payment Status'),
                  items: const [
                    DropdownMenuItem(value: 'UNPAID', child: Text('UNPAID')),
                    DropdownMenuItem(value: 'PARTIAL', child: Text('PARTIAL')),
                    DropdownMenuItem(value: 'PAID', child: Text('PAID')),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => payStatus = v ?? payStatus),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesC,
                  decoration: InputDecoration(
                      labelText: isRtl ? 'ملاحظات' : 'Notes'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isRtl ? 'إلغاء' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                onSave({
                  'grossAmount': double.tryParse(grossC.text),
                  'commissionAmount': double.tryParse(commC.text),
                  'taxAmount': double.tryParse(taxC.text),
                  'otherFeesAmount': double.tryParse(feesC.text),
                  'paymentStatus': payStatus,
                  'notes': notesC.text,
                });
              },
              child: Text(isRtl ? 'حفظ' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
