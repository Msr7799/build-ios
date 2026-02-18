import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../config/app_theme.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<dynamic> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<AppProvider>().api;
      final data = await api.getNotes();
      if (mounted) setState(() => _notes = data);
    } catch (e) {
      debugPrint('getNotes error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleResolved(String id, bool current) async {
    try {
      final api = context.read<AppProvider>().api;
      await api.updateNote(id, {'isResolved': !current});
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('فشل التحديث: $e')));
      }
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذه الملاحظة؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      try {
        final api = context.read<AppProvider>().api;
        await api.deleteNote(id);
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('فشل الحذف: $e')));
        }
      }
    }
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _AddNoteSheet(
        units: context.read<AppProvider>().units,
        api: context.read<AppProvider>().api,
      ),
    ).then((ok) {
      if (ok == true) _load();
    });
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'URGENT':
        return Colors.red;
      case 'HIGH':
        return Colors.orange;
      case 'NORMAL':
        return AppTheme.accent;
      default:
        return Colors.grey;
    }
  }

  String _priorityLabel(String p) {
    switch (p) {
      case 'URGENT':
        return 'عاجلة';
      case 'HIGH':
        return 'عالية';
      case 'NORMAL':
        return 'عادية';
      default:
        return 'منخفضة';
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSheet,
        icon: const Icon(Icons.add),
        label: Text(prov.isRtl ? 'ملاحظة جديدة' : 'New Note'),
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none_rounded,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text(prov.isRtl ? 'لا توجد ملاحظات' : 'No notes yet',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 15)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    itemCount: _notes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final n = _notes[i];
                      final resolved = n['isResolved'] == true;
                      final priority = n['priority'] ?? 'NORMAL';
                      return Opacity(
                        opacity: resolved ? 0.55 : 1,
                        child: Card(
                          elevation: resolved ? 0 : 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: _priorityColor(priority).withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        n['title'] ?? '',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          decoration: resolved
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _priorityColor(priority)
                                            .withValues(alpha: 0.15),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        _priorityLabel(priority),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: _priorityColor(priority),
                                        ),
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      padding: EdgeInsets.zero,
                                      onSelected: (v) {
                                        if (v == 'toggle') {
                                          _toggleResolved(
                                              n['id'], resolved);
                                        } else if (v == 'delete') {
                                          _delete(n['id']);
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        PopupMenuItem(
                                          value: 'toggle',
                                          child: Row(children: [
                                            Icon(
                                                resolved
                                                    ? Icons.undo
                                                    : Icons.check,
                                                size: 18),
                                            const SizedBox(width: 8),
                                            Text(resolved
                                                ? 'إلغاء الإنجاز'
                                                : 'تعليم كمنجز'),
                                          ]),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(children: [
                                            Icon(Icons.delete,
                                                size: 18,
                                                color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('حذف',
                                                style: TextStyle(
                                                    color: Colors.red)),
                                          ]),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(n['content'] ?? '',
                                    style: const TextStyle(fontSize: 13)),
                                if (n['unit'] != null) ...[
                                  const SizedBox(height: 6),
                                  Chip(
                                    avatar: const Icon(
                                        Icons.apartment_rounded,
                                        size: 14),
                                    label: Text(n['unit']['name'] ?? ''),
                                    labelStyle:
                                        const TextStyle(fontSize: 11),
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ],
                                if (n['attachments'] != null &&
                                    (n['attachments'] as List)
                                        .isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    children: [
                                      for (var f in n['attachments'])
                                        Chip(
                                          avatar: const Icon(
                                              Icons.attach_file,
                                              size: 14),
                                          label: Text(
                                            f['filename'] ?? 'file',
                                            style: const TextStyle(
                                                fontSize: 10),
                                          ),
                                          visualDensity:
                                              VisualDensity.compact,
                                          materialTapTargetSize:
                                              MaterialTapTargetSize
                                                  .shrinkWrap,
                                        ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Text(
                                  _fmtDate(n['createdAt']),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

class _AddNoteSheet extends StatefulWidget {
  final List<Map<String, dynamic>> units;
  final ApiService api;
  const _AddNoteSheet({required this.units, required this.api});
  @override
  State<_AddNoteSheet> createState() => _AddNoteSheetState();
}

class _AddNoteSheetState extends State<_AddNoteSheet> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _content = TextEditingController();
  String _priority = 'NORMAL';
  String? _unitId;
  List<Map<String, dynamic>> _attachments = [];
  bool _uploading = false;
  bool _saving = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
    );
    if (result == null || result.files.single.path == null) return;

    setState(() => _uploading = true);
    try {
      final uploaded = await widget.api.uploadFile(result.files.single.path!);
      setState(() => _attachments.add(uploaded));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('فشل الرفع: $e')));
      }
    }
    setState(() => _uploading = false);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.api.createNote({
        'title': _title.text,
        'content': _content.text,
        'priority': _priority,
        'unitId': _unitId,
        'attachments': _attachments.isNotEmpty ? _attachments : null,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('فشل الحفظ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('إضافة ملاحظة جديدة',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                    labelText: 'العنوان *', border: OutlineInputBorder()),
                validator: (v) => v?.isEmpty == true ? 'مطلوب' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _content,
                decoration: const InputDecoration(
                    labelText: 'المحتوى *', border: OutlineInputBorder()),
                maxLines: 4,
                validator: (v) => v?.isEmpty == true ? 'مطلوب' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _priority,
                      decoration: const InputDecoration(
                          labelText: 'الأولوية',
                          border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(
                            value: 'LOW', child: Text('منخفضة')),
                        DropdownMenuItem(
                            value: 'NORMAL', child: Text('عادية')),
                        DropdownMenuItem(
                            value: 'HIGH', child: Text('عالية')),
                        DropdownMenuItem(
                            value: 'URGENT', child: Text('عاجلة')),
                      ],
                      onChanged: (v) => setState(() => _priority = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _unitId,
                      decoration: const InputDecoration(
                          labelText: 'العقار',
                          border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('-- بدون --')),
                        ...widget.units.map((u) => DropdownMenuItem(
                              value: u['id'] as String,
                              child: Text(u['name'] ?? ''),
                            )),
                      ],
                      onChanged: (v) => setState(() => _unitId = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_attachments.isNotEmpty)
                Wrap(
                  spacing: 8,
                  children: _attachments
                      .map((f) => Chip(
                            label: Text(f['filename'] ?? 'file'),
                            deleteIcon:
                                const Icon(Icons.close, size: 16),
                            onDeleted: () => setState(
                                () => _attachments.remove(f)),
                          ))
                      .toList(),
                ),
              OutlinedButton.icon(
                onPressed: _uploading ? null : _pickFile,
                icon: _uploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child:
                            CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.attach_file),
                label: Text(_uploading ? 'جاري الرفع...' : 'رفع ملف'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('إلغاء')),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('حفظ'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }
}
