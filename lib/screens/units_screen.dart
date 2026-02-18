import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/app_provider.dart';
import '../services/import_service.dart';
import '../widgets/channel_badge.dart';

class UnitsScreen extends StatefulWidget {
  const UnitsScreen({super.key});
  @override
  State<UnitsScreen> createState() => _UnitsScreenState();
}

class _UnitsScreenState extends State<UnitsScreen> {
  String? _expandedId;
  String _msg = '';

  @override
  void initState() {
    super.initState();
    final prov = context.read<AppProvider>();
    if (prov.units.isEmpty) prov.loadUnits();
  }

  Future<void> _addUnit(String name, String code, String rate) async {
    final prov = context.read<AppProvider>();
    try {
      final body = {
        'name': name,
        'code': code.isEmpty ? null : code,
        'defaultRate': rate.isEmpty ? null : double.tryParse(rate),
      };
      await prov.api.createUnit(body);
      await prov.loadUnits();
      setState(() => _msg = '✅');
    } catch (e) {
      setState(() => _msg = 'Error: $e');
    }
  }

  Future<void> _importUnits() async {
    final prov = context.read<AppProvider>();
    final isRtl = prov.isRtl;
    try {
      setState(() => _msg = isRtl ? '⏳ جاري قراءة الملف...' : '⏳ Reading file...');
      final rows = await ImportService.pickAndParseUnits();
      if (rows == null) {
        setState(() => _msg = '');
        return;
      }
      if (rows.isEmpty) {
        setState(() => _msg = isRtl ? '⚠️ الملف فارغ أو لا يحتوي بيانات صالحة' : '⚠️ File empty or no valid data');
        return;
      }

      // Show preview dialog
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(isRtl ? 'معاينة الاستيراد' : 'Import Preview'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRtl
                      ? 'تم العثور على ${rows.length} وحدة:'
                      : 'Found ${rows.length} units:',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (_, i) {
                      final r = rows[i];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          child: Text('${i + 1}', style: const TextStyle(fontSize: 11)),
                        ),
                        title: Text(r['name'] ?? '', style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                          '${r['code'] ?? '-'} | ${r['defaultRate'] ?? '-'} ${r['currency'] ?? 'BHD'}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(isRtl ? 'إلغاء' : 'Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.upload_rounded, size: 16),
              label: Text(isRtl ? 'استيراد ${rows.length} وحدة' : 'Import ${rows.length} units'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        setState(() => _msg = '');
        return;
      }

      setState(() => _msg = isRtl ? '⏳ جاري الاستيراد...' : '⏳ Importing...');

      int ok = 0;
      for (final r in rows) {
        try {
          await prov.api.createUnit(r);
          ok++;
        } catch (_) {}
      }
      await prov.loadUnits();
      setState(() => _msg = '✅ ${isRtl ? 'تم استيراد' : 'Imported'} $ok/${rows.length}');
    } catch (e) {
      setState(() => _msg = '❌ Error: $e');
    }
  }

  Future<void> _deleteUnit(String id) async {
    final prov = context.read<AppProvider>();
    try {
      await prov.api.deleteUnit(id);
      await prov.loadUnits();
    } catch (e) {
      setState(() => _msg = 'Error: $e');
    }
  }

  Future<void> _addFeed(String unitId, String channel, String url) async {
    final prov = context.read<AppProvider>();
    try {
      final body = {
        'unitId': unitId,
        'channel': channel,
        'type': 'URL',
        'url': url,
      };
      await prov.api.addFeed(body);
      await prov.loadUnits();
      setState(() => _msg = '✅');
    } catch (e) {
      setState(() => _msg = 'Error: $e');
    }
  }

  Future<void> _deleteFeed(String feedId) async {
    final prov = context.read<AppProvider>();
    try {
      await prov.api.deleteFeed(feedId);
      await prov.loadUnits();
    } catch (e) {
      setState(() => _msg = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final isRtl = prov.isRtl;
    final units = prov.units;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: RefreshIndicator(
        onRefresh: () => prov.loadUnits(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    isRtl ? 'الوحدات' : 'Units',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _importUnits,
                  icon: const Icon(Icons.file_upload_rounded, size: 16),
                  label: Text(isRtl ? 'استيراد' : 'Import',
                      style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _showAddUnitDialog(isRtl),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(isRtl ? 'إضافة وحدة' : 'Add Unit'),
                ),
              ],
            ),
            if (_msg.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_msg,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ),
            const SizedBox(height: 16),

            if (prov.unitsLoading)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator()))
            else if (units.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text(isRtl ? 'لا توجد وحدات' : 'No units yet',
                      style: const TextStyle(color: AppTheme.textSecondary)),
                ),
              )
            else
              ...units.map((u) => _buildUnitCard(u, isRtl)),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitCard(Map<String, dynamic> u, bool isRtl) {
    final id = u['id'] as String;
    final name = u['name'] ?? '';
    final rate = u['defaultRate'];
    final currency = u['currency'] ?? 'BHD';
    final feeds = List<Map<String, dynamic>>.from(u['feeds'] ?? []);
    final isExpanded = _expandedId == id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(
                () => _expandedId = isExpanded ? null : id),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.apartment_rounded,
                        color: AppTheme.accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (rate != null)
                              Text('💰 $rate $currency',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary)),
                            const SizedBox(width: 8),
                            ...feeds.take(3).map((f) => Padding(
                                  padding:
                                      const EdgeInsetsDirectional.only(end: 4),
                                  child: ChannelBadge(
                                      channel: f['channel'] ?? '', fontSize: 8),
                                )),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isRtl ? '📡 الخلاصات' : '📡 Feeds',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  if (feeds.isEmpty)
                    Text(isRtl ? 'لا توجد خلاصات' : 'No feeds yet',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ...feeds.map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            ChannelBadge(
                                channel: f['channel'] ?? '', fontSize: 9),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                f['url'] ?? f['name'] ?? f['type'] ?? '',
                                style: const TextStyle(fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 18, color: AppTheme.danger),
                              onPressed: () => _deleteFeed(f['id']),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 8),
                  _AddFeedRow(
                    isRtl: isRtl,
                    onAdd: (ch, url) => _addFeed(id, ch, url),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          setState(() => _msg = isRtl ? '⏳ جاري المزامنة...' : '⏳ Syncing iCal...');
                          try {
                            final prov = context.read<AppProvider>();
                            final result = await prov.api.syncAll(unitId: id);
                            await prov.loadUnits();
                            setState(() => _msg =
                                '✅ ${isRtl ? 'تمت المزامنة' : 'Synced'}: '
                                '${result['synced'] ?? 0} ${isRtl ? 'حجز' : 'bookings'} | '
                                '${result['errors'] ?? 0} ${isRtl ? 'أخطاء' : 'errors'}');
                          } catch (e) {
                            setState(() => _msg = '❌ Sync error: $e');
                          }
                        },
                        icon: const Icon(Icons.sync_rounded, size: 16),
                        label: Text(isRtl ? 'مزامنة iCal' : 'Sync iCal',
                            style: const TextStyle(fontSize: 12)),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _confirmDelete(id, name, isRtl),
                        icon: const Icon(Icons.delete_outline,
                            size: 16, color: AppTheme.danger),
                        label: Text(isRtl ? 'حذف' : 'Delete',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.danger)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddUnitDialog(bool isRtl) {
    final nameC = TextEditingController();
    final codeC = TextEditingController();
    final rateC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isRtl ? 'إضافة وحدة' : 'Add Unit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameC,
              decoration: InputDecoration(
                  labelText: isRtl ? 'اسم الوحدة' : 'Unit name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: codeC,
              decoration: InputDecoration(
                  labelText: isRtl ? 'الرمز (اختياري)' : 'Code (optional)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: rateC,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: isRtl ? 'السعر الافتراضي' : 'Default rate'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isRtl ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _addUnit(nameC.text, codeC.text, rateC.text);
            },
            child: Text(isRtl ? 'إضافة' : 'Add'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String id, String name, bool isRtl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isRtl ? 'حذف الوحدة' : 'Delete Unit'),
        content: Text(
            isRtl ? 'هل أنت متأكد من حذف "$name"?' : 'Delete "$name"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isRtl ? 'إلغاء' : 'Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteUnit(id);
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            child: Text(isRtl ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );
  }
}

class _AddFeedRow extends StatefulWidget {
  final bool isRtl;
  final Future<void> Function(String channel, String url) onAdd;
  const _AddFeedRow({required this.isRtl, required this.onAdd});

  @override
  State<_AddFeedRow> createState() => _AddFeedRowState();
}

class _AddFeedRowState extends State<_AddFeedRow> {
  String _channel = 'BOOKING';
  final _urlC = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _channel,
                  isDense: true,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                  items: const [
                    DropdownMenuItem(value: 'BOOKING', child: Text('BOOKING')),
                    DropdownMenuItem(value: 'AIRBNB', child: Text('AIRBNB')),
                    DropdownMenuItem(value: 'AGODA', child: Text('AGODA')),
                    DropdownMenuItem(value: 'OTHER', child: Text('OTHER')),
                  ],
                  onChanged: (v) => setState(() => _channel = v!),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _urlC,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: widget.isRtl ? 'رابط iCal...' : 'iCal URL...',
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              if (_urlC.text.trim().isEmpty) return;
              widget.onAdd(_channel, _urlC.text.trim());
              _urlC.clear();
            },
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text(widget.isRtl ? 'إضافة خلاصة' : 'Add Feed',
                style: const TextStyle(fontSize: 12)),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.success),
          ),
        ),
      ],
    );
  }
}
