import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import '../config/app_theme.dart';
import '../providers/app_provider.dart';

class ContentScreen extends StatefulWidget {
  const ContentScreen({super.key});
  @override
  State<ContentScreen> createState() => _ContentScreenState();
}

class _ContentScreenState extends State<ContentScreen> {
  String? _unitId;
  bool _loading = false;
  bool _saving = false;
  String _msg = '';

  final _titleC = TextEditingController();
  final _descC = TextEditingController();
  final _amenitiesC = TextEditingController();
  final _rulesC = TextEditingController();
  final _checkInC = TextEditingController();
  final _checkOutC = TextEditingController();
  final _locationC = TextEditingController();
  List<String> _images = [];
  int _primaryIndex = 0;
  final _addressC = TextEditingController();
  final _capacityC = TextEditingController();
  final _highlightsC = TextEditingController();
  final _depositC = TextEditingController();
  final _cancellationC = TextEditingController();
  final _nearbyC = TextEditingController();
  final _accTypeC = TextEditingController();
  final _propertyIdC = TextEditingController();
  final _currencyC = TextEditingController();
  final _roomSizeC = TextEditingController();
  final _bedroomCountC = TextEditingController();
  final _bathroomCountC = TextEditingController();
  final _coordinatesC = TextEditingController();
  final _quietHoursC = TextEditingController();
  final _minAgeC = TextEditingController();
  final _smokingC = TextEditingController();
  final _petsC = TextEditingController();
  final _partiesC = TextEditingController();
  final _childrenC = TextEditingController();
  final _paymentC = TextEditingController();
  final _hostNameC = TextEditingController();
  final _finePrintsC = TextEditingController();
  bool _scraping = false;

  @override
  void initState() {
    super.initState();
    final prov = context.read<AppProvider>();
    if (prov.units.isNotEmpty) {
      _unitId = prov.units.first['id'];
      _loadContent();
    }
  }

  Future<void> _loadContent() async {
    if (_unitId == null) return;
    setState(() {
      _loading = true;
      _msg = '';
    });
    try {
      final prov = context.read<AppProvider>();
      final data = await prov.api.getContent(_unitId!);
      final m = data['master'] ?? {};
      _titleC.text = m['title'] ?? '';
      _descC.text = m['description'] ?? '';
      _amenitiesC.text = (m['amenities'] as List?)?.join('\n') ?? '';
      _rulesC.text = m['houseRules'] ?? '';
      _checkInC.text = m['checkInInfo'] ?? '';
      _checkOutC.text = m['checkOutInfo'] ?? '';
      _locationC.text = m['locationNote'] ?? '';
      _images = List<String>.from((m['images'] as List?) ?? []);
      _primaryIndex = 0;
      _addressC.text = m['address'] ?? '';
      _capacityC.text = m['guestCapacity'] ?? '';
      _highlightsC.text = m['propertyHighlights'] ?? '';
      _depositC.text = m['damageDeposit'] ?? '';
      _cancellationC.text = m['cancellationPolicy'] ?? '';
      _nearbyC.text = m['nearbyPlaces'] ?? '';
      _accTypeC.text = m['accommodationType'] ?? '';
      _propertyIdC.text = m['propertyId'] ?? '';
      _currencyC.text = m['currency'] ?? '';
      _roomSizeC.text = m['roomSize'] ?? '';
      _bedroomCountC.text = m['bedroomCount']?.toString() ?? '';
      _bathroomCountC.text = m['bathroomCount']?.toString() ?? '';
      final coords = m['coordinates'];
      if (coords != null && coords is Map) {
        _coordinatesC.text = '${coords['lat']},${coords['lng']}';
      } else {
        _coordinatesC.text = '';
      }
      _quietHoursC.text = m['quietHours'] ?? '';
      _minAgeC.text = m['minCheckInAge']?.toString() ?? '';
      _smokingC.text = m['smokingPolicy'] ?? '';
      _petsC.text = m['petsPolicy'] ?? '';
      _partiesC.text = m['partiesPolicy'] ?? '';
      _childrenC.text = m['childrenPolicy'] ?? '';
      _paymentC.text = m['paymentMethods'] ?? '';
      _hostNameC.text = m['hostName'] ?? '';
      _finePrintsC.text = m['finePrints'] ?? '';
    } catch (e) {
      setState(() => _msg = 'Error: $e');
    }
    setState(() => _loading = false);
  }

  Future<void> _fetchFromUrl() async {
    final isRtl = context.read<AppProvider>().isRtl;
    final urlC = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isRtl ? 'جلب بيانات العقار' : 'Fetch Property Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isRtl
                  ? 'الصق رابط العقار من Booking.com أو Agoda \nسيتم جلب العنوان والوصف والصور والمرافق تلقائياً.'
                  : 'Paste your property URL from Booking.com or Agoda.\nTitle, description, images & amenities will be auto-filled.',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlC,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'https://www.booking.com/hotel/...',
                labelText: isRtl ? 'رابط العقار' : 'Property URL',
                prefixIcon: const Icon(Icons.link_rounded, size: 18),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isRtl ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, urlC.text.trim()),
            icon: const Icon(Icons.download_rounded, size: 16),
            label: Text(isRtl ? 'جلب' : 'Fetch'),
          ),
        ],
      ),
    );

    if (url == null || url.isEmpty) return;

    setState(() {
      _scraping = true;
      _msg = isRtl ? '⏳ جاري جلب البيانات من السيرفر...' : '⏳ Extracting data via server...';
    });

    try {
      final prov = context.read<AppProvider>();
      final response = await prov.api.extractFromUrl(url);
      
      if (response['ok'] != true || response['data'] == null) {
        throw Exception(response['error'] ?? 'Failed to extract content');
      }

      final data = response['data'] as Map<String, dynamic>;

      // Fill in the fields
      if ((data['title'] ?? '').toString().isNotEmpty) {
        _titleC.text = data['title'];
      }
      if ((data['description'] ?? '').toString().isNotEmpty) {
        _descC.text = data['description'];
      }
      if (data['amenities'] is List && (data['amenities'] as List).isNotEmpty) {
        _amenitiesC.text = (data['amenities'] as List).join('\n');
      }
      if ((data['houseRules'] ?? '').toString().isNotEmpty) {
        _rulesC.text = data['houseRules'];
      }
      if ((data['checkInInfo'] ?? '').toString().isNotEmpty) {
        _checkInC.text = data['checkInInfo'];
      }
      if ((data['checkOutInfo'] ?? '').toString().isNotEmpty) {
        _checkOutC.text = data['checkOutInfo'];
      }
      if ((data['locationNote'] ?? '').toString().isNotEmpty) {
        _locationC.text = data['locationNote'];
      }
      if (data['images'] is List && (data['images'] as List).isNotEmpty) {
        _images = List<String>.from(data['images'] as List);
        _primaryIndex = 0;
      }
      if ((data['address'] ?? '').toString().isNotEmpty) {
        _addressC.text = data['address'];
      }
      if ((data['guestCapacity'] ?? '').toString().isNotEmpty) {
        _capacityC.text = data['guestCapacity'];
      }
      if ((data['propertyHighlights'] ?? '').toString().isNotEmpty) {
        _highlightsC.text = data['propertyHighlights'];
      }
      if ((data['damageDeposit'] ?? '').toString().isNotEmpty) {
        _depositC.text = data['damageDeposit'];
      }
      if ((data['cancellationPolicy'] ?? '').toString().isNotEmpty) {
        _cancellationC.text = data['cancellationPolicy'];
      }
      if ((data['nearbyPlaces'] ?? '').toString().isNotEmpty) {
        _nearbyC.text = data['nearbyPlaces'];
      }
      if ((data['accommodationType'] ?? '').toString().isNotEmpty) {
        _accTypeC.text = data['accommodationType'];
      }
      if ((data['propertyId'] ?? '').toString().isNotEmpty) {
        _propertyIdC.text = data['propertyId'];
      }
      if ((data['currency'] ?? '').toString().isNotEmpty) {
        _currencyC.text = data['currency'];
      }
      if ((data['roomSize'] ?? '').toString().isNotEmpty) {
        _roomSizeC.text = data['roomSize'];
      }
      if (data['bedroomCount'] != null) {
        _bedroomCountC.text = data['bedroomCount'].toString();
      }
      if (data['bathroomCount'] != null) {
        _bathroomCountC.text = data['bathroomCount'].toString();
      }
      if (data['coordinates'] != null && data['coordinates'] is Map) {
        final c = data['coordinates'];
        _coordinatesC.text = '${c['lat']},${c['lng']}';
      }
      if ((data['quietHours'] ?? '').toString().isNotEmpty) {
        _quietHoursC.text = data['quietHours'];
      }
      if (data['minCheckInAge'] != null) {
        _minAgeC.text = data['minCheckInAge'].toString();
      }
      if ((data['smokingPolicy'] ?? '').toString().isNotEmpty) {
        _smokingC.text = data['smokingPolicy'];
      }
      if ((data['petsPolicy'] ?? '').toString().isNotEmpty) {
        _petsC.text = data['petsPolicy'];
      }
      if ((data['partiesPolicy'] ?? '').toString().isNotEmpty) {
        _partiesC.text = data['partiesPolicy'];
      }
      if ((data['childrenPolicy'] ?? '').toString().isNotEmpty) {
        _childrenC.text = data['childrenPolicy'];
      }
      if ((data['paymentMethods'] ?? '').toString().isNotEmpty) {
        _paymentC.text = data['paymentMethods'];
      }
      if ((data['hostName'] ?? '').toString().isNotEmpty) {
        _hostNameC.text = data['hostName'];
      }
      if ((data['finePrints'] ?? '').toString().isNotEmpty) {
        _finePrintsC.text = data['finePrints'];
      }

      final imgCount = data['images'] is List ? (data['images'] as List).length : 0;
      setState(() => _msg =
          '✅ ${isRtl ? 'تم جلب البيانات بنجاح' : 'Data extracted successfully'} | '
          '${isRtl ? 'صور' : 'Images'}: $imgCount | '
          '${isRtl ? 'اضغط حفظ للتطبيق' : 'Press Save to apply'}');
    } catch (e) {
      setState(() => _msg = '❌ ${isRtl ? 'خطأ في الجلب' : 'Extraction failed'}: $e');
    }
    setState(() => _scraping = false);
  }

  Future<void> _save() async {
    if (_unitId == null) return;
    setState(() {
      _saving = true;
      _msg = '';
    });
    try {
      final prov = context.read<AppProvider>();
      final body = {
        'title': _titleC.text,
        'description': _descC.text,
        'amenities': _amenitiesC.text
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        'houseRules': _rulesC.text,
        'checkInInfo': _checkInC.text,
        'checkOutInfo': _checkOutC.text,
        'locationNote': _locationC.text,
        'images': _images,
        'primaryImageIndex': _primaryIndex,
        'address': _addressC.text,
        'guestCapacity': _capacityC.text,
        'propertyHighlights': _highlightsC.text,
        'damageDeposit': _depositC.text,
        'cancellationPolicy': _cancellationC.text,
        'nearbyPlaces': _nearbyC.text,
      };
      await prov.api.saveContent(_unitId!, body);
      setState(() => _msg = '✅');
    } catch (e) {
      setState(() => _msg = 'Error: $e');
    }
    setState(() => _saving = false);
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
          Text(
            isRtl ? 'ستوديو المحتوى' : 'Content Studio',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: (_scraping || _unitId == null) ? null : _fetchFromUrl,
                icon: _scraping
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.language_rounded, size: 16),
                label: Text(
                  isRtl ? 'جلب من رابط' : 'Fetch URL',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _unitId == null ? null : _exportContent,
                icon: const Icon(Icons.file_download_outlined, size: 16),
                label: Text(
                  isRtl ? 'تصدير' : 'Export',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 16),
                label: Text(isRtl ? 'حفظ' : 'Save'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isRtl
                ? 'اكتب المحتوى مرة واحدة، انسخ/الصق لكل قناة.'
                : 'Write once, copy/paste for each channel.',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),

          // Unit selector
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Text(isRtl ? 'الوحدة:' : 'Unit:',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _unitId,
                      isDense: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      items: units
                          .map((u) => DropdownMenuItem(
                                value: u['id'] as String,
                                child: Text(u['name'] ?? '',
                                    style: const TextStyle(fontSize: 12)),
                              ))
                          .toList(),
                      onChanged: (v) {
                        setState(() => _unitId = v);
                        _loadContent();
                      },
                    ),
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
          else ...[
            LayoutBuilder(builder: (ctx, constraints) {
              final isWide = constraints.maxWidth > 700;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildMainFields(isRtl)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildPropertyFields(isRtl)),
                  ],
                );
              }
              return Column(
                children: [
                  _buildMainFields(isRtl),
                  const SizedBox(height: 16),
                  _buildPropertyFields(isRtl),
                ],
              );
            }),
            const SizedBox(height: 16),
            _buildImageSection(isRtl),
          ],
        ],
      ),
    );
  }

  // ─── Image Section ──────────────────────────────────────────────
  Widget _buildImageSection(bool isRtl) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.photo_library_rounded, size: 18, color: AppTheme.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isRtl
                        ? 'الصور (${_images.length})'
                        : 'Images (${_images.length})',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
                  tooltip: isRtl ? 'إضافة رابط صورة' : 'Add image URL',
                  onPressed: _addImageUrl,
                ),
              ],
            ),
            if (_images.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.image_not_supported_outlined,
                          size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 8),
                      Text(
                        isRtl ? 'لا توجد صور بعد' : 'No images yet',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[400]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isRtl
                            ? 'اجلب من رابط أو أضف يدوياً'
                            : 'Fetch from URL or add manually',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
              )
            else
              _buildImageGrid(isRtl),
            if (_images.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                isRtl
                    ? '⭐ = الصورة الرئيسية | اسحب لترتيب | اضغط للعرض الكامل'
                    : '⭐ = Primary | Drag to reorder | Tap to view',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid(bool isRtl) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final crossCount = constraints.maxWidth > 600
          ? 4
          : constraints.maxWidth > 400
              ? 3
              : 2;
      final spacing = 8.0;
      final itemWidth =
          (constraints.maxWidth - spacing * (crossCount - 1)) / crossCount;
      final itemHeight = itemWidth * 0.75;

      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: List.generate(_images.length, (index) {
          final url = _images[index];
          final isPrimary = index == _primaryIndex;

          return DragTarget<int>(
            onAcceptWithDetails: (details) {
              setState(() {
                final fromIdx = details.data;
                if (fromIdx == index) return;
                final item = _images.removeAt(fromIdx);
                _images.insert(index, item);
                if (_primaryIndex == fromIdx) {
                  _primaryIndex = index;
                } else if (fromIdx < _primaryIndex && index >= _primaryIndex) {
                  _primaryIndex--;
                } else if (fromIdx > _primaryIndex && index <= _primaryIndex) {
                  _primaryIndex++;
                }
              });
            },
            builder: (context, candidateData, rejectedData) {
              final isOver = candidateData.isNotEmpty;
              return LongPressDraggable<int>(
                data: index,
                feedback: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: url,
                      width: itemWidth * 0.8,
                      height: itemHeight * 0.8,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                childWhenDragging: Container(
                  width: itemWidth,
                  height: itemHeight,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.grey[400]!,
                        style: BorderStyle.solid,
                        width: 2),
                  ),
                  child: const Center(
                      child: Icon(Icons.image, color: Colors.grey)),
                ),
                child: GestureDetector(
                  onTap: () => _showFullImageViewer(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: itemWidth,
                    height: itemHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isOver
                            ? AppTheme.accent
                            : isPrimary
                                ? Colors.amber
                                : AppTheme.border,
                        width: isOver || isPrimary ? 2.5 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: Colors.grey[100],
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: Colors.grey[100],
                              child: const Icon(Icons.broken_image,
                                  color: Colors.grey),
                            ),
                          ),
                          // Index badge
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          // Star (primary) button
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _primaryIndex = index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: isPrimary
                                      ? Colors.amber
                                      : Colors.black38,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isPrimary
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          // Delete button
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _images.removeAt(index);
                                  if (_primaryIndex >= _images.length) {
                                    _primaryIndex =
                                        _images.isEmpty ? 0 : _images.length - 1;
                                  } else if (_primaryIndex > index) {
                                    _primaryIndex--;
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close_rounded,
                                    size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }),
      );
    });
  }

  void _addImageUrl() async {
    final isRtl = context.read<AppProvider>().isRtl;
    final ctrl = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isRtl ? 'إضافة رابط صورة' : 'Add Image URL'),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: 'https://...',
            labelText: isRtl ? 'رابط الصورة' : 'Image URL',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isRtl ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(isRtl ? 'إضافة' : 'Add'),
          ),
        ],
      ),
    );
    if (url != null && url.isNotEmpty) {
      setState(() => _images.add(url));
    }
  }

  void _showFullImageViewer(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullImageViewer(
          images: _images,
          initialIndex: initialIndex,
          primaryIndex: _primaryIndex,
          onPrimaryChanged: (i) => setState(() => _primaryIndex = i),
        ),
      ),
    );
  }

  // ─── Export ──────────────────────────────────────────────────────
  Map<String, dynamic> _collectData() {
    return {
      'title': _titleC.text,
      'description': _descC.text,
      'amenities': _amenitiesC.text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      'houseRules': _rulesC.text,
      'checkInInfo': _checkInC.text,
      'checkOutInfo': _checkOutC.text,
      'locationNote': _locationC.text,
      'images': _images,
      'primaryImageIndex': _primaryIndex,
      'address': _addressC.text,
      'guestCapacity': _capacityC.text,
      'propertyHighlights': _highlightsC.text,
      'damageDeposit': _depositC.text,
      'cancellationPolicy': _cancellationC.text,
      'nearbyPlaces': _nearbyC.text,
    };
  }

  Future<void> _exportContent() async {
    final isRtl = context.read<AppProvider>().isRtl;
    final format = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isRtl ? 'اختر صيغة التصدير' : 'Choose Export Format',
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.data_object, color: Colors.orange),
              title: const Text('JSON'),
              subtitle: Text(isRtl
                  ? 'بيانات منظمة مع الصور'
                  : 'Structured data with images'),
              onTap: () => Navigator.pop(ctx, 'json'),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: const Text('CSV'),
              subtitle: Text(isRtl
                  ? 'جدول بيانات متوافق مع Excel'
                  : 'Spreadsheet compatible'),
              onTap: () => Navigator.pop(ctx, 'csv'),
            ),
            ListTile(
              leading: const Icon(Icons.text_snippet, color: Colors.blue),
              title: const Text('TXT'),
              subtitle: Text(
                  isRtl ? 'نص عادي للنسخ واللصق' : 'Plain text for copy/paste'),
              onTap: () => Navigator.pop(ctx, 'txt'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('PDF'),
              subtitle:
                  Text(isRtl ? 'تقرير جاهز للطباعة' : 'Print-ready report'),
              onTap: () => Navigator.pop(ctx, 'pdf'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (format == null) return;

    try {
      final data = _collectData();
      final title = _titleC.text.isNotEmpty ? _titleC.text : 'property_content';
      final safeName = title.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');

      late String filePath;
      final dir = await getTemporaryDirectory();

      switch (format) {
        case 'json':
          final content = const JsonEncoder.withIndent('  ').convert(data);
          filePath = '${dir.path}/$safeName.json';
          await File(filePath).writeAsString(content);
          break;
        case 'csv':
          filePath = '${dir.path}/$safeName.csv';
          await File(filePath).writeAsString(_buildCsv(data));
          break;
        case 'txt':
          filePath = '${dir.path}/$safeName.txt';
          await File(filePath).writeAsString(_buildTxt(data));
          break;
        case 'pdf':
          filePath = '${dir.path}/$safeName.pdf';
          await _buildPdf(data, filePath);
          break;
      }

      await Share.shareXFiles([XFile(filePath)]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  String _buildCsv(Map<String, dynamic> data) {
    final rows = <List<String>>[
      ['Field', 'Value'],
      ['Title', data['title'] ?? ''],
      ['Description', data['description'] ?? ''],
      ['Amenities', (data['amenities'] as List?)?.join(', ') ?? ''],
      ['House Rules', data['houseRules'] ?? ''],
      ['Check-in Info', data['checkInInfo'] ?? ''],
      ['Check-out Info', data['checkOutInfo'] ?? ''],
      ['Location Note', data['locationNote'] ?? ''],
      ['Address', data['address'] ?? ''],
      ['Guest Capacity', data['guestCapacity'] ?? ''],
      ['Property Highlights', data['propertyHighlights'] ?? ''],
      ['Damage Deposit', data['damageDeposit'] ?? ''],
      ['Cancellation Policy', data['cancellationPolicy'] ?? ''],
      ['Nearby Places', data['nearbyPlaces'] ?? ''],
    ];
    for (int i = 0; i < _images.length; i++) {
      rows.add([
        i == _primaryIndex ? 'Image ${i + 1} (Primary)' : 'Image ${i + 1}',
        _images[i],
      ]);
    }
    return const ListToCsvConverter().convert(rows);
  }

  String _buildTxt(Map<String, dynamic> data) {
    final buf = StringBuffer();
    buf.writeln('═══════════════════════════════════════');
    buf.writeln('  ${data['title'] ?? 'Property Content'}');
    buf.writeln('═══════════════════════════════════════\n');

    void section(String label, String? value) {
      if (value != null && value.isNotEmpty) {
        buf.writeln('── $label ──');
        buf.writeln(value);
        buf.writeln();
      }
    }

    section('Description', data['description']);
    if (data['amenities'] is List && (data['amenities'] as List).isNotEmpty) {
      buf.writeln('── Amenities ──');
      for (final a in data['amenities']) {
        buf.writeln('  • $a');
      }
      buf.writeln();
    }
    section('House Rules', data['houseRules']);
    section('Check-in Info', data['checkInInfo']);
    section('Check-out Info', data['checkOutInfo']);
    section('Location Note', data['locationNote']);
    section('Address', data['address']);
    section('Guest Capacity', data['guestCapacity']);
    section('Property Highlights', data['propertyHighlights']);
    section('Damage Deposit', data['damageDeposit']);
    section('Cancellation Policy', data['cancellationPolicy']);
    section('Nearby Places', data['nearbyPlaces']);

    if (_images.isNotEmpty) {
      buf.writeln('── Images (${_images.length}) ──');
      for (int i = 0; i < _images.length; i++) {
        final tag = i == _primaryIndex ? ' ⭐ PRIMARY' : '';
        buf.writeln('  ${i + 1}. ${_images[i]}$tag');
      }
    }

    return buf.toString();
  }

  Future<void> _buildPdf(Map<String, dynamic> data, String path) async {
    final pdf = pw.Document();

    pw.Widget pdfSection(String label, String? value) {
      if (value == null || value.isEmpty) return pw.SizedBox();
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: 12)),
          pw.SizedBox(height: 2),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 10),
        ],
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => [
          pw.Text(data['title'] ?? 'Property Content',
              style: pw.TextStyle(
                  fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 16),
          pdfSection('Description', data['description']),
          if (data['amenities'] is List &&
              (data['amenities'] as List).isNotEmpty)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Amenities',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 12)),
                pw.SizedBox(height: 2),
                ...((data['amenities'] as List)
                    .map((a) => pw.Bullet(
                        text: a.toString(),
                        style: const pw.TextStyle(fontSize: 10)))
                    .toList()),
                pw.SizedBox(height: 10),
              ],
            ),
          pdfSection('House Rules', data['houseRules']),
          pdfSection('Check-in Info', data['checkInInfo']),
          pdfSection('Check-out Info', data['checkOutInfo']),
          pdfSection('Location Note', data['locationNote']),
          pdfSection('Address', data['address']),
          pdfSection('Guest Capacity', data['guestCapacity']),
          pdfSection('Property Highlights', data['propertyHighlights']),
          pdfSection('Damage Deposit', data['damageDeposit']),
          pdfSection('Cancellation Policy', data['cancellationPolicy']),
          pdfSection('Nearby Places', data['nearbyPlaces']),
          if (_images.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text('Images (${_images.length})',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.SizedBox(height: 4),
            ...List.generate(_images.length, (i) {
              final tag = i == _primaryIndex ? ' [PRIMARY]' : '';
              return pw.Text('${i + 1}. ${_images[i]}$tag',
                  style: const pw.TextStyle(fontSize: 9));
            }),
          ],
        ],
      ),
    );

    final file = File(path);
    await file.writeAsBytes(await pdf.save());
  }

  // ─── Main Fields ────────────────────────────────────────────────
  Widget _buildMainFields(bool isRtl) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isRtl ? 'المحتوى الأساسي' : 'Master Content',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 12),
            _field(isRtl ? 'العنوان' : 'Title', _titleC),
            _field(isRtl ? 'الوصف' : 'Description', _descC, maxLines: 5),
            _field(isRtl ? 'المرافق (سطر لكل مرفق)' : 'Amenities (one per line)',
                _amenitiesC,
                maxLines: 4),
            _field(isRtl ? 'قواعد المنزل' : 'House Rules', _rulesC,
                maxLines: 3),
            _field(isRtl ? 'معلومات تسجيل الدخول' : 'Check-in Info', _checkInC),
            _field(isRtl ? 'معلومات تسجيل الخروج' : 'Check-out Info',
                _checkOutC),
            _field(isRtl ? 'ملاحظة الموقع' : 'Location Note', _locationC),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _copyBtn(isRtl ? 'نسخ العنوان' : 'Copy Title', _titleC.text),
                _copyBtn(isRtl ? 'نسخ الوصف' : 'Copy Desc', _descC.text),
                _copyBtn(
                    isRtl ? 'نسخ المرافق' : 'Copy Amenities', _amenitiesC.text),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyFields(bool isRtl) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isRtl ? 'تفاصيل العقار' : 'Property Details',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 12),
                _field(isRtl ? 'العنوان' : 'Address', _addressC),
                _field(isRtl ? 'نوع العقار' : 'Property Type', _accTypeC),
                Row(
                  children: [
                    Expanded(child: _field(isRtl ? 'رقم العقار' : 'Property ID', _propertyIdC)),
                    const SizedBox(width: 8),
                    Expanded(child: _field(isRtl ? 'العملة' : 'Currency', _currencyC)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: _field(isRtl ? 'المساحة' : 'Room Size', _roomSizeC)),
                    const SizedBox(width: 8),
                    Expanded(child: _field(isRtl ? 'سعة الضيوف' : 'Capacity', _capacityC)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: _field(isRtl ? 'غرف نوم' : 'Bedrooms', _bedroomCountC)),
                    const SizedBox(width: 8),
                    Expanded(child: _field(isRtl ? 'حمامات' : 'Bathrooms', _bathroomCountC)),
                  ],
                ),
                _field(isRtl ? 'الإحداثيات (lat,lng)' : 'Coordinates (lat,lng)', _coordinatesC),
                _field(isRtl ? 'المضيف' : 'Host Name', _hostNameC),
                _field(
                    isRtl ? 'مميزات العقار' : 'Property Highlights', _highlightsC,
                    maxLines: 4),
                _field(
                    isRtl ? 'الأماكن القريبة' : 'Nearby Places', _nearbyC,
                    maxLines: 4),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isRtl ? 'السياسات والقوانين' : 'Policies & Rules',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 12),
                _field(isRtl ? 'مبلغ التأمين' : 'Damage Deposit', _depositC),
                _field(isRtl ? 'سياسة الإلغاء' : 'Cancellation Policy',
                    _cancellationC, maxLines: 2),
                Row(
                  children: [
                    Expanded(child: _field(isRtl ? 'ساعات الهدوء' : 'Quiet Hours', _quietHoursC)),
                    const SizedBox(width: 8),
                    Expanded(child: _field(isRtl ? 'أقل عمر' : 'Min Age', _minAgeC)),
                  ],
                ),
                _field(isRtl ? 'التدخين' : 'Smoking Policy', _smokingC),
                _field(isRtl ? 'الحيوانات الأليفة' : 'Pets Policy', _petsC),
                _field(isRtl ? 'الحفلات' : 'Parties Policy', _partiesC),
                _field(isRtl ? 'الأطفال' : 'Children Policy', _childrenC),
                _field(isRtl ? 'طرق الدفع' : 'Payment Methods', _paymentC),
                _field(isRtl ? 'معلومات مهمة' : 'Fine Prints', _finePrintsC,
                    maxLines: 3),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _field(String label, TextEditingController ctrl, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: maxLines > 1,
        ),
      ),
    );
  }

  Widget _copyBtn(String label, String text) {
    return OutlinedButton.icon(
      onPressed: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Copied!'),
              duration: const Duration(seconds: 1)),
        );
      },
      icon: const Icon(Icons.copy_rounded, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

// ─── Full-Screen Image Viewer ───────────────────────────────────────
class _FullImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final int primaryIndex;
  final ValueChanged<int> onPrimaryChanged;

  const _FullImageViewer({
    required this.images,
    required this.initialIndex,
    required this.primaryIndex,
    required this.onPrimaryChanged,
  });

  @override
  State<_FullImageViewer> createState() => _FullImageViewerState();
}

class _FullImageViewerState extends State<_FullImageViewer> {
  late PageController _pageCtrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '${_current + 1} / ${widget.images.length}',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _current == widget.primaryIndex
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              color: _current == widget.primaryIndex
                  ? Colors.amber
                  : Colors.white,
            ),
            tooltip: 'Set as primary',
            onPressed: () {
              widget.onPrimaryChanged(_current);
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 20),
            tooltip: 'Copy URL',
            onPressed: () {
              Clipboard.setData(
                  ClipboardData(text: widget.images[_current]));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('URL copied!'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageCtrl,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (ctx, i) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: widget.images[i],
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image,
                      color: Colors.white54, size: 64),
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: widget.images.length > 1
          ? SafeArea(
              child: Container(
                height: 70,
                color: Colors.black87,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.images.length,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 8),
                  itemBuilder: (ctx, i) {
                    final isActive = i == _current;
                    return GestureDetector(
                      onTap: () {
                        _pageCtrl.animateToPage(i,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut);
                      },
                      child: Container(
                        width: 54,
                        height: 54,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isActive
                                ? Colors.white
                                : Colors.white24,
                            width: isActive ? 2 : 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: CachedNetworkImage(
                            imageUrl: widget.images[i],
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Icon(
                                Icons.broken_image,
                                color: Colors.white30,
                                size: 20),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            )
          : null,
    );
  }
}
