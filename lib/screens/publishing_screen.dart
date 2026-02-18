import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/app_provider.dart';
import '../widgets/channel_badge.dart';

class PublishingScreen extends StatefulWidget {
  const PublishingScreen({super.key});
  @override
  State<PublishingScreen> createState() => _PublishingScreenState();
}

class _PublishingScreenState extends State<PublishingScreen> {
  String? _unitId;
  List<Map<String, dynamic>> _channels = [];
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
      final data = await prov.api.getPublishingStatus(unitId: _unitId);
      setState(() => _channels = List<Map<String, dynamic>>.from(data['channels'] ?? []));
    } catch (e) {
      setState(() => _msg = 'Error: $e');
    }
    setState(() => _loading = false);
  }

  Future<void> _markPublished(String channel) async {
    final prov = context.read<AppProvider>();
    try {
      final body = {'unitId': _unitId, 'channel': channel};
      await prov.api.markPublished(body);
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
          Text(isRtl ? 'لوحة النشر' : 'Publishing Board',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            isRtl ? 'يعرض ما تغير منذ آخر نشر يدوي. عند الانتهاء من التحديث، اضغط "تم النشر".' : 'Shows changes since last manual publish. Click "Mark published" when done.',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
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
          else if (_channels.isEmpty)
            Center(child: Padding(padding: const EdgeInsets.all(40), child: Text(isRtl ? 'لا توجد قنوات. أضف محتوى أولاً.' : 'No channels yet. Add content first.', style: const TextStyle(color: AppTheme.textSecondary))))
          else
            ..._channels.map((ch) {
              final channel = ch['channel'] ?? '';
              final draft = ch['draft'] ?? '';
              final hasChanges = ch['hasChanges'] == true;
              final lastPublished = ch['lastPublishedAt'];
              final editUrl = ch['editUrl'];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ChannelBadge(channel: channel),
                          const SizedBox(width: 8),
                          if (hasChanges)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                              child: Text(isRtl ? 'تغييرات معلقة' : 'Changes pending', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.warning)),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                              child: Text(isRtl ? 'محدث' : 'Up to date', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.success)),
                            ),
                          const Spacer(),
                          if (lastPublished != null)
                            Text('${isRtl ? 'آخر نشر: ' : 'Last: '}${DateTime.tryParse(lastPublished)?.toLocal().toString().substring(0, 16) ?? ''}',
                                style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                        ],
                      ),
                      if (draft.toString().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Text(draft.toString(), style: const TextStyle(fontSize: 11, height: 1.5), maxLines: 10, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: draft.toString()));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied!'), duration: Duration(seconds: 1)));
                            },
                            icon: const Icon(Icons.copy_rounded, size: 14),
                            label: Text(isRtl ? 'نسخ المسودة' : 'Copy Draft', style: const TextStyle(fontSize: 11)),
                          ),
                          if (editUrl != null && editUrl.toString().isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: () {/* open URL */},
                              icon: const Icon(Icons.open_in_new_rounded, size: 14),
                              label: Text(isRtl ? 'فتح صفحة التعديل' : 'Open Edit Page', style: const TextStyle(fontSize: 11)),
                            ),
                          FilledButton.icon(
                            onPressed: () => _markPublished(channel),
                            icon: const Icon(Icons.check_circle_rounded, size: 14),
                            label: Text(isRtl ? 'تم النشر' : 'Mark Published', style: const TextStyle(fontSize: 11)),
                            style: FilledButton.styleFrom(backgroundColor: AppTheme.success),
                          ),
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
}
