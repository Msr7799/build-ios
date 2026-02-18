import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/app_provider.dart';
import '../widgets/channel_badge.dart';

class PayoutsScreen extends StatefulWidget {
  const PayoutsScreen({super.key});
  @override
  State<PayoutsScreen> createState() => _PayoutsScreenState();
}

class _PayoutsScreenState extends State<PayoutsScreen> {
  List<Map<String, dynamic>> _payouts = [];
  bool _loading = false;
  String _msg = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _msg = ''; });
    try {
      final prov = context.read<AppProvider>();
      final data = await prov.api.getPayouts();
      setState(() => _payouts = List<Map<String, dynamic>>.from(data['payouts'] ?? []));
    } catch (e) {
      setState(() => _msg = 'Error: $e');
    }
    setState(() => _loading = false);
  }

  Future<void> _addPayout(String channel, String amount, String date, String ref, String note) async {
    final prov = context.read<AppProvider>();
    try {
      final body = {
        'channel': channel,
        'amount': double.tryParse(amount) ?? 0,
        'payoutDate': date.isNotEmpty ? date : DateTime.now().toIso8601String(),
        'providerRef': ref.isNotEmpty ? ref : null,
        'note': note.isNotEmpty ? note : null,
      };
      await prov.api.createPayout(body);
      await _load();
      setState(() => _msg = '✅');
    } catch (e) {
      setState(() => _msg = 'Error: $e');
    }
  }

  Future<void> _deletePayout(String id) async {
    final prov = context.read<AppProvider>();
    try {
      await prov.api.deletePayout(id);
      await _load();
    } catch (e) {
      setState(() => _msg = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final isRtl = prov.isRtl;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(isRtl ? 'المدفوعات' : 'Payouts',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              ),
              FilledButton.icon(
                onPressed: () => _showAddDialog(isRtl),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(isRtl ? 'إضافة' : 'Add Payout'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isRtl ? 'المنصات تدفع لك. هنا نطابق المدفوعات مع الحجوزات.' : 'Platforms pay you. Reconcile payments with bookings.',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          if (_msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_msg, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
          const SizedBox(height: 12),

          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (_payouts.isEmpty)
            Center(child: Padding(padding: const EdgeInsets.all(40), child: Text(isRtl ? 'لا توجد مدفوعات' : 'No payouts yet.', style: const TextStyle(color: AppTheme.textSecondary))))
          else
            ..._payouts.map((p) {
              final channel = p['channel'] ?? '';
              final amount = p['amount'] ?? '';
              final currency = p['currency'] ?? 'BHD';
              final date = (p['payoutDate'] ?? '').toString().substring(0, 10);
              final status = p['status'] ?? 'RECEIVED';
              final ref = p['providerRef'] ?? '';
              final note = p['note'] ?? '';
              final lines = List<Map<String, dynamic>>.from(p['lines'] ?? []);

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.channelColor(channel).withValues(alpha: 0.1),
                    child: Icon(Icons.account_balance_wallet_rounded, size: 18, color: AppTheme.channelColor(channel)),
                  ),
                  title: Row(
                    children: [
                      ChannelBadge(channel: channel, fontSize: 9),
                      const SizedBox(width: 8),
                      Text('$amount $currency', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    ],
                  ),
                  subtitle: Text('$date  ${status == 'RECEIVED' ? '✅' : '⏳'}${ref.isNotEmpty ? '  ref: $ref' : ''}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger), onPressed: () => _deletePayout(p['id'])),
                  children: [
                    if (note.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('📝 $note', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary))),
                    if (lines.isEmpty)
                      Padding(padding: const EdgeInsets.all(16), child: Text(isRtl ? 'لا توجد سطور' : 'No lines yet.', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)))
                    else
                      ...lines.map((l) => ListTile(
                        dense: true,
                        title: Text('${l['amount'] ?? ''} $currency', style: const TextStyle(fontSize: 12)),
                        subtitle: Text(l['note'] ?? '', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                      )),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showAddDialog(bool isRtl) {
    String channel = 'BOOKING';
    final amtC = TextEditingController();
    final dateC = TextEditingController(text: DateTime.now().toString().substring(0, 10));
    final refC = TextEditingController();
    final noteC = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(isRtl ? 'إضافة مدفوعات' : 'Add Payout'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: channel,
                  decoration: InputDecoration(labelText: isRtl ? 'القناة' : 'Channel'),
                  items: const [
                    DropdownMenuItem(value: 'BOOKING', child: Text('BOOKING')),
                    DropdownMenuItem(value: 'AIRBNB', child: Text('AIRBNB')),
                    DropdownMenuItem(value: 'AGODA', child: Text('AGODA')),
                  ],
                  onChanged: (v) => setD(() => channel = v!),
                ),
                const SizedBox(height: 8),
                TextField(controller: amtC, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: isRtl ? 'المبلغ' : 'Amount')),
                const SizedBox(height: 8),
                TextField(controller: dateC, decoration: InputDecoration(labelText: isRtl ? 'التاريخ' : 'Date', hintText: 'YYYY-MM-DD')),
                const SizedBox(height: 8),
                TextField(controller: refC, decoration: InputDecoration(labelText: isRtl ? 'المرجع' : 'Provider Ref (optional)')),
                const SizedBox(height: 8),
                TextField(controller: noteC, decoration: InputDecoration(labelText: isRtl ? 'ملاحظة' : 'Note')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isRtl ? 'إلغاء' : 'Cancel')),
            FilledButton(
              onPressed: () { Navigator.pop(ctx); _addPayout(channel, amtC.text, dateC.text, refC.text, noteC.text); },
              child: Text(isRtl ? 'إضافة' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }
}
