import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/app_provider.dart';
import '../widgets/channel_badge.dart';

class RatesScreen extends StatefulWidget {
  const RatesScreen({super.key});
  @override
  State<RatesScreen> createState() => _RatesScreenState();
}

class _RatesScreenState extends State<RatesScreen> {
  String? _unitId;
  List<Map<String, dynamic>> _rules = [];
  List<Map<String, dynamic>> _preview = [];
  bool _loading = false;
  String _msg = '';

  @override
  void initState() {
    super.initState();
    final prov = context.read<AppProvider>();
    if (prov.units.isNotEmpty) {
      _unitId = prov.units.first['id'];
      _load();
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _msg = ''; });
    try {
      final prov = context.read<AppProvider>();
      final data = await prov.api.getRates(unitId: _unitId);
      setState(() => _rules = List<Map<String, dynamic>>.from(data['rules'] ?? []));
      final prev = await prov.api.getRatesPreview(unitId: _unitId);
      setState(() => _preview = List<Map<String, dynamic>>.from(prev['days'] ?? []));
    } catch (e) {
      setState(() => _msg = 'Error: $e');
    }
    setState(() => _loading = false);
  }

  Future<void> _deleteRule(String id) async {
    final prov = context.read<AppProvider>();
    try {
      await prov.api.deleteRate(id);
      await _load();
    } catch (e) {
      setState(() => _msg = 'Error: $e');
    }
  }

  Future<void> _addRule(Map<String, dynamic> data) async {
    final prov = context.read<AppProvider>();
    try {
      final body = {...data, 'unitId': _unitId};
      await prov.api.createRate(body);
      await _load();
      setState(() => _msg = '✅');
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
                child: Text(isRtl ? 'الأسعار والقواعد' : 'Rates & Rules',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              ),
              FilledButton.icon(
                onPressed: () => _showAddDialog(isRtl),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(isRtl ? 'إضافة قاعدة' : 'Add Rule'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(isRtl ? 'حدد قواعد الأسعار والإغلاق.' : 'Define rate/closure rules.',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),

          // Unit selector
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Text(isRtl ? 'الوحدة:' : 'Unit:', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _unitId,
                      isDense: true,
                      decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                      items: prov.units.map((u) => DropdownMenuItem(value: u['id'] as String, child: Text(u['name'] ?? '', style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (v) { setState(() => _unitId = v); _load(); },
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_msg, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
          const SizedBox(height: 12),

          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else ...[
            // Rules list
            Text(isRtl ? 'القواعد' : 'Rules', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            if (_rules.isEmpty)
              Text(isRtl ? 'لا توجد قواعد' : 'No rules yet.', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))
            else
              ..._rules.map((r) {
                final name = r['name'] ?? '';
                final base = r['baseRate'] ?? '';
                final weekend = r['weekendRate'];
                final start = (r['startDate'] ?? '').toString().substring(0, 10);
                final end = (r['endDate'] ?? '').toString().substring(0, 10);
                final channel = r['channel'];
                final stopSell = r['stopSell'] == true;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: stopSell ? AppTheme.danger.withValues(alpha: 0.1) : AppTheme.accent.withValues(alpha: 0.1),
                      child: Icon(stopSell ? Icons.block_rounded : Icons.price_change_rounded, size: 18, color: stopSell ? AppTheme.danger : AppTheme.accent),
                    ),
                    title: Row(
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        if (channel != null) ...[const SizedBox(width: 6), ChannelBadge(channel: channel, fontSize: 8)],
                        if (stopSell) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(color: AppTheme.danger, borderRadius: BorderRadius.circular(4)),
                            child: const Text('STOP', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text('$start → $end  |  $base${weekend != null ? ' / $weekend wknd' : ''}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    trailing: IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger), onPressed: () => _deleteRule(r['id'])),
                  ),
                );
              }),

            const SizedBox(height: 16),

            // Preview
            Text(isRtl ? 'معاينة (60 يوم)' : 'Preview (next 60 days)', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            if (_preview.isEmpty)
              Text(isRtl ? 'لا توجد معاينة' : 'No preview.', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))
            else
              Card(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(12),
                  child: DataTable(
                    columnSpacing: 14,
                    headingRowHeight: 32,
                    dataRowMinHeight: 28,
                    dataRowMaxHeight: 32,
                    columns: [
                      DataColumn(label: Text(isRtl ? 'التاريخ' : 'Date', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                      DataColumn(label: Text(isRtl ? 'السعر' : 'Rate', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                      DataColumn(label: Text(isRtl ? 'الحد الأدنى' : 'Min', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                      DataColumn(label: Text(isRtl ? 'إغلاق' : 'Close', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                      DataColumn(label: Text(isRtl ? 'القاعدة' : 'Rule', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                    ],
                    rows: _preview.take(30).map((d) {
                      final date = (d['date'] ?? '').toString().substring(0, 10);
                      final rate = d['rate'] ?? '—';
                      final minN = d['minNights'] ?? 1;
                      final closed = d['stopSell'] == true;
                      final rule = d['ruleName'] ?? '';
                      return DataRow(cells: [
                        DataCell(Text(date, style: const TextStyle(fontSize: 10))),
                        DataCell(Text('$rate', style: const TextStyle(fontSize: 10))),
                        DataCell(Text('$minN', style: const TextStyle(fontSize: 10))),
                        DataCell(closed ? const Icon(Icons.block, size: 14, color: AppTheme.danger) : const SizedBox()),
                        DataCell(Text(rule, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary))),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _showAddDialog(bool isRtl) {
    final nameC = TextEditingController();
    final baseC = TextEditingController();
    final weekendC = TextEditingController();
    final startC = TextEditingController();
    final endC = TextEditingController();
    final minC = TextEditingController(text: '1');
    bool stopSell = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(isRtl ? 'إضافة قاعدة' : 'Add Rule'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameC, decoration: InputDecoration(labelText: isRtl ? 'الاسم' : 'Name', hintText: 'Ramadan promo...')),
                const SizedBox(height: 8),
                TextField(controller: baseC, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: isRtl ? 'السعر الأساسي' : 'Base Rate')),
                const SizedBox(height: 8),
                TextField(controller: weekendC, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: isRtl ? 'سعر نهاية الأسبوع' : 'Weekend Rate (optional)')),
                const SizedBox(height: 8),
                TextField(controller: startC, decoration: InputDecoration(labelText: isRtl ? 'البداية' : 'Start', hintText: 'YYYY-MM-DD')),
                const SizedBox(height: 8),
                TextField(controller: endC, decoration: InputDecoration(labelText: isRtl ? 'النهاية' : 'End (exclusive)', hintText: 'YYYY-MM-DD')),
                const SizedBox(height: 8),
                TextField(controller: minC, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: isRtl ? 'الحد الأدنى للليالي' : 'Min Nights')),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: stopSell,
                  onChanged: (v) => setD(() => stopSell = v!),
                  title: Text(isRtl ? 'إغلاق (Stop-sell)' : 'Stop-sell (close)', style: const TextStyle(fontSize: 13)),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isRtl ? 'إلغاء' : 'Cancel')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _addRule({
                  'name': nameC.text,
                  'baseRate': double.tryParse(baseC.text) ?? 0,
                  'weekendRate': double.tryParse(weekendC.text),
                  'startDate': startC.text,
                  'endDate': endC.text,
                  'minNights': int.tryParse(minC.text) ?? 1,
                  'stopSell': stopSell,
                });
              },
              child: Text(isRtl ? 'إضافة' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }
}
