import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/app_provider.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String? _unitId;
  List<Map<String, dynamic>> _rows = [];
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
      final data = await prov.api.getExpenses(unitId: _unitId);
      setState(() => _rows = List<Map<String, dynamic>>.from(data['expenses'] ?? []));
    } catch (e) {
      setState(() => _msg = 'Error: $e');
    }
    setState(() => _loading = false);
  }

  Future<void> _add(String category, String amount, String note, String date) async {
    final prov = context.read<AppProvider>();
    try {
      final body = {
        'unitId': _unitId,
        'category': category,
        'amount': double.tryParse(amount) ?? 0,
        'spentAt': date.isNotEmpty ? date : DateTime.now().toIso8601String(),
        'note': note.isNotEmpty ? note : null,
      };
      await prov.api.createExpense(body);
      await _load();
      setState(() => _msg = '✅');
    } catch (e) {
      setState(() => _msg = 'Error: $e');
    }
  }

  Future<void> _delete(String id) async {
    final prov = context.read<AppProvider>();
    try {
      await prov.api.deleteExpense(id);
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
                child: Text(isRtl ? 'المصروفات' : 'Expenses',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              ),
              FilledButton.icon(
                onPressed: () => _showAddDialog(isRtl),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(isRtl ? 'إضافة' : 'Add'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(isRtl ? 'تتبع المصروفات مثل التنظيف والصيانة.' : 'Track cleaning, maintenance, utilities.',
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
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(isRtl ? 'تحديث' : 'Refresh', style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),

          if (_msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_msg, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
          const SizedBox(height: 12),

          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (_rows.isEmpty)
            Center(child: Padding(padding: const EdgeInsets.all(40), child: Text(isRtl ? 'لا توجد مصروفات' : 'No expenses yet.', style: const TextStyle(color: AppTheme.textSecondary))))
          else
            ..._rows.map((e) {
              final cat = e['category'] ?? '';
              final amt = e['amount'] ?? '';
              final cur = e['currency'] ?? 'BHD';
              final note = e['note'] ?? '';
              final date = e['spentAt'] != null ? DateTime.tryParse(e['spentAt'])?.toLocal().toString().substring(0, 10) ?? '' : '';
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.accent.withValues(alpha: 0.1),
                    child: const Icon(Icons.receipt_long_rounded, size: 18, color: AppTheme.accent),
                  ),
                  title: Text('$amt $cur', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text('$cat${note.isNotEmpty ? ' • $note' : ''} • $date', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                    onPressed: () => _delete(e['id']),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showAddDialog(bool isRtl) {
    String cat = 'CLEANING';
    final amtC = TextEditingController();
    final noteC = TextEditingController();
    final dateC = TextEditingController(text: DateTime.now().toString().substring(0, 10));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(isRtl ? 'إضافة مصروف' : 'Add Expense'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: cat,
                decoration: InputDecoration(labelText: isRtl ? 'الفئة' : 'Category'),
                items: const [
                  DropdownMenuItem(value: 'CLEANING', child: Text('CLEANING')),
                  DropdownMenuItem(value: 'MAINTENANCE', child: Text('MAINTENANCE')),
                  DropdownMenuItem(value: 'UTILITIES', child: Text('UTILITIES')),
                  DropdownMenuItem(value: 'SUPPLIES', child: Text('SUPPLIES')),
                  DropdownMenuItem(value: 'STAFF', child: Text('STAFF')),
                  DropdownMenuItem(value: 'OTHER', child: Text('OTHER')),
                ],
                onChanged: (v) => setD(() => cat = v!),
              ),
              const SizedBox(height: 8),
              TextField(controller: amtC, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: isRtl ? 'المبلغ' : 'Amount')),
              const SizedBox(height: 8),
              TextField(controller: dateC, decoration: InputDecoration(labelText: isRtl ? 'التاريخ' : 'Date', hintText: 'YYYY-MM-DD')),
              const SizedBox(height: 8),
              TextField(controller: noteC, decoration: InputDecoration(labelText: isRtl ? 'ملاحظة' : 'Note')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isRtl ? 'إلغاء' : 'Cancel')),
            FilledButton(
              onPressed: () { Navigator.pop(ctx); _add(cat, amtC.text, noteC.text, dateC.text); },
              child: Text(isRtl ? 'إضافة' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }
}
