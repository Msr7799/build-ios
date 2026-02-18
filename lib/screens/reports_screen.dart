import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/app_provider.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String? _unitId;
  List<Map<String, dynamic>> _rows = [];
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
      final data = await prov.api.getReports(unitId: _unitId);
      setState(() => _rows = List<Map<String, dynamic>>.from(data['months'] ?? []));
    } catch (e) {
      setState(() => _msg = 'Error: $e');
    }
    setState(() => _loading = false);
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
          Text(isRtl ? 'التقارير' : 'Reports',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(isRtl ? 'ملخص شهري: الربح = صافي الحجوزات - المصروفات' : 'Monthly: profit = net bookings - expenses',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),

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
                      items: [
                        DropdownMenuItem<String>(value: null, child: Text(isRtl ? 'الكل' : 'All', style: const TextStyle(fontSize: 12))),
                        ...prov.units.map((u) => DropdownMenuItem(value: u['id'] as String, child: Text(u['name'] ?? '', style: const TextStyle(fontSize: 12)))),
                      ],
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
          else if (_rows.isEmpty)
            Center(child: Padding(padding: const EdgeInsets.all(40), child: Text(isRtl ? 'لا توجد بيانات' : 'No data yet.', style: const TextStyle(color: AppTheme.textSecondary))))
          else
            ..._rows.map((r) {
              final month = r['month'] ?? '';
              final bookingNet = r['bookingNet'] ?? 0;
              final expenseTotal = r['expenseTotal'] ?? 0;
              final profit = (bookingNet is num ? bookingNet : 0) - (expenseTotal is num ? expenseTotal : 0);
              final currency = r['currency'] ?? 'BHD';

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(month, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _statBox(isRtl ? 'صافي الحجوزات' : 'Booking Net', '$bookingNet $currency', AppTheme.success)),
                          const SizedBox(width: 8),
                          Expanded(child: _statBox(isRtl ? 'المصروفات' : 'Expenses', '$expenseTotal $currency', AppTheme.danger)),
                          const SizedBox(width: 8),
                          Expanded(child: _statBox(isRtl ? 'الربح' : 'Profit', '${profit.toStringAsFixed(3)} $currency', profit >= 0 ? AppTheme.success : AppTheme.danger)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
