import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/app_provider.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  String? _unitId;
  int _year = DateTime.now().year;
  int _month = DateTime.now().month; // 1-indexed

  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _dateBlocks = [];
  List<Map<String, dynamic>> _feeds = [];
  bool _loading = false;
  String _msg = '';
  bool _busy = false;

  final Set<String> _selected = {};
  final List<bool> _dowFilter = List.filled(7, false); // Sun..Sat

  @override
  void initState() {
    super.initState();
    final prov = context.read<AppProvider>();
    if (prov.units.isEmpty) {
      prov.loadUnits().then((_) {
        if (prov.units.isNotEmpty) {
          setState(() => _unitId = prov.units.first['id']);
          _loadCalendar();
        }
      });
    } else {
      _unitId = prov.units.first['id'];
      _loadCalendar();
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadCalendar() async {
    if (_unitId == null) return;
    setState(() {
      _loading = true;
      _msg = '';
    });
    try {
      final from = _fmtDate(DateTime.utc(_year, _month, 1));
      final lastDay = DateTime.utc(_year, _month + 2, 0);
      final to = _fmtDate(lastDay);
      final prov = context.read<AppProvider>();
      final data = await prov.api.getCalendar(_unitId!, from, to);
      setState(() {
        _bookings = List<Map<String, dynamic>>.from(data['bookings'] ?? []);
        _dateBlocks = List<Map<String, dynamic>>.from(data['dateBlocks'] ?? []);
        _feeds = List<Map<String, dynamic>>.from(data['feeds'] ?? []);
      });
    } catch (e) {
      setState(() => _msg = 'Error: $e');
    }
    setState(() => _loading = false);
  }

  void _prevMonth() {
    setState(() {
      if (_month == 1) {
        _year--;
        _month = 12;
      } else {
        _month--;
      }
    });
    _selected.clear();
    _loadCalendar();
  }

  void _nextMonth() {
    setState(() {
      if (_month == 12) {
        _year++;
        _month = 1;
      } else {
        _month++;
      }
    });
    _selected.clear();
    _loadCalendar();
  }

  void _toggleDate(String dateStr) {
    setState(() {
      if (_selected.contains(dateStr)) {
        _selected.remove(dateStr);
      } else {
        _selected.add(dateStr);
      }
    });
  }

  void _toggleDow(int dow) {
    setState(() {
      _dowFilter[dow] = !_dowFilter[dow];
    });
    // Select/deselect all days of that weekday in both months
    final allDays = _getAllCurrentMonthDays();
    setState(() {
      for (final d in allDays) {
        if (d.weekday % 7 == dow) {
          final ds = _fmtDate(d);
          if (_dowFilter[dow]) {
            _selected.add(ds);
          } else {
            _selected.remove(ds);
          }
        }
      }
    });
  }

  List<DateTime> _getAllCurrentMonthDays() {
    final days = <DateTime>[];
    final daysInM1 = DateTime.utc(_year, _month + 1, 0).day;
    for (int d = 1; d <= daysInM1; d++) {
      days.add(DateTime.utc(_year, _month, d));
    }
    final m2y = _month == 12 ? _year + 1 : _year;
    final m2m = _month == 12 ? 1 : _month + 1;
    final daysInM2 = DateTime.utc(m2y, m2m + 1, 0).day;
    for (int d = 1; d <= daysInM2; d++) {
      days.add(DateTime.utc(m2y, m2m, d));
    }
    return days;
  }

  Future<void> _blockDates() async {
    if (_selected.isEmpty || _unitId == null) return;
    setState(() => _busy = true);
    try {
      final prov = context.read<AppProvider>();
      await prov.api.blockDates(_unitId!, _selected.toList());
      _selected.clear();
      _dowFilter.fillRange(0, 7, false);
      await _loadCalendar();
      setState(() => _msg = '✅');
    } catch (e) {
      setState(() => _msg = 'Error: $e');
    }
    setState(() => _busy = false);
  }

  Future<void> _unblockDates() async {
    if (_selected.isEmpty || _unitId == null) return;
    setState(() => _busy = true);
    try {
      final prov = context.read<AppProvider>();
      await prov.api.unblockDates(_unitId!, _selected.toList());
      _selected.clear();
      _dowFilter.fillRange(0, 7, false);
      await _loadCalendar();
      setState(() => _msg = '✅');
    } catch (e) {
      setState(() => _msg = 'Error: $e');
    }
    setState(() => _busy = false);
  }

  // Check if a day has a booking
  List<Map<String, dynamic>> _bookingsForDay(String dateStr) {
    final dayMs = DateTime.parse('${dateStr}T00:00:00Z').millisecondsSinceEpoch;
    return _bookings.where((b) {
      final s = DateTime.parse(b['startDate']).millisecondsSinceEpoch;
      final e = DateTime.parse(b['endDate']).millisecondsSinceEpoch;
      return s <= dayMs && dayMs < e;
    }).toList();
  }

  Map<String, dynamic>? _blockForDay(String dateStr) {
    for (final bl in _dateBlocks) {
      final blDate = (bl['date'] as String).substring(0, 10);
      if (blDate == dateStr) return bl;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final isRtl = prov.isRtl;
    final units = prov.units;

    final dayNamesEn = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final dayNamesAr = ['أحد', 'إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت'];
    final dayNames = isRtl ? dayNamesAr : dayNamesEn;

    final monthNamesEn = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final monthNamesAr = [
      '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    final monthNames = isRtl ? monthNamesAr : monthNamesEn;

    final m2y = _month == 12 ? _year + 1 : _year;
    final m2m = _month == 12 ? 1 : _month + 1;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Controls ──────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Unit + Month nav row
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Unit selector
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.border),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _unitId,
                            isDense: true,
                            style: const TextStyle(
                                fontSize: 13, color: AppTheme.textPrimary),
                            items: units
                                .map((u) => DropdownMenuItem(
                                      value: u['id'] as String,
                                      child: Text(u['name'] ?? ''),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              setState(() => _unitId = v);
                              _selected.clear();
                              _loadCalendar();
                            },
                          ),
                        ),
                      ),
                      // Month navigation
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              isRtl
                                  ? Icons.chevron_right_rounded
                                  : Icons.chevron_left_rounded,
                              color: AppTheme.textPrimary,
                            ),
                            onPressed: _prevMonth,
                          ),
                          Text(
                            '${monthNames[_month]} $_year',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          IconButton(
                            icon: Icon(
                              isRtl
                                  ? Icons.chevron_left_rounded
                                  : Icons.chevron_right_rounded,
                              color: AppTheme.textPrimary,
                            ),
                            onPressed: _nextMonth,
                          ),
                        ],
                      ),
                      // Block / Unblock buttons
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_selected.isNotEmpty)
                            Text('${_selected.length} ',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary)),
                          FilledButton.icon(
                            onPressed:
                                _busy || _selected.isEmpty ? null : _blockDates,
                            icon: const Icon(Icons.lock_rounded, size: 16),
                            label: Text(isRtl ? 'إغلاق' : 'Block',
                                style: const TextStyle(fontSize: 12)),
                            style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.danger),
                          ),
                          const SizedBox(width: 6),
                          FilledButton.icon(
                            onPressed: _busy || _selected.isEmpty
                                ? null
                                : _unblockDates,
                            icon:
                                const Icon(Icons.lock_open_rounded, size: 16),
                            label: Text(isRtl ? 'فتح' : 'Unblock',
                                style: const TextStyle(fontSize: 12)),
                            style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.success),
                          ),
                          if (_selected.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            OutlinedButton(
                              onPressed: () => setState(() {
                                _selected.clear();
                                _dowFilter.fillRange(0, 7, false);
                              }),
                              child: Text(isRtl ? 'إلغاء' : 'Clear',
                                  style: const TextStyle(fontSize: 12)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Day-of-week filter checkboxes
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(7, (i) {
                      return FilterChip(
                        selected: _dowFilter[i],
                        label: Text(
                          dayNames[i],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _dowFilter[i]
                                ? AppTheme.accent
                                : AppTheme.textPrimary,
                          ),
                        ),
                        onSelected: (_) => _toggleDow(i),
                        backgroundColor: AppTheme.cardBg,
                        selectedColor: AppTheme.accent.withValues(alpha: 0.15),
                        checkmarkColor: AppTheme.accent,
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: _dowFilter[i]
                                ? AppTheme.accent
                                : AppTheme.border,
                          ),
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      );
                    }),
                  ),

                  // Feeds info
                  if (_feeds.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _feeds.map((f) {
                        final ch = f['channel'] ?? '';
                        return Chip(
                          avatar: CircleAvatar(
                            radius: 6,
                            backgroundColor: AppTheme.channelColor(ch),
                          ),
                          label: Text(ch, style: const TextStyle(fontSize: 10)),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        );
                      }).toList(),
                    ),
                  ],

                  if (_msg.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_msg,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ─── Legend ─────────────────────────────────────────
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _legendItem(Colors.white, isRtl ? 'متاح' : 'Available', border: true),
              _legendItem(const Color(0xFFE0E7FF), 'Booking.com'),
              _legendItem(const Color(0xFFFEE2E2), 'Airbnb'),
              _legendItem(const Color(0xFFD1FAE5), 'Agoda'),
              _legendItem(const Color(0xFFFEF3C7), isRtl ? 'مغلق يدويًا' : 'Manual Block'),
              _legendItem(AppTheme.accent.withValues(alpha: 0.3),
                  isRtl ? 'محدد' : 'Selected', border: true),
            ],
          ),

          const SizedBox(height: 12),

          // ─── Calendar Grids ────────────────────────────────
          if (_loading)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator()))
          else
            LayoutBuilder(builder: (ctx, constraints) {
              final isWide = constraints.maxWidth > 700;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: _buildMonthGrid(
                            _year, _month, monthNames, dayNames)),
                    const SizedBox(width: 16),
                    Expanded(
                        child:
                            _buildMonthGrid(m2y, m2m, monthNames, dayNames)),
                  ],
                );
              }
              return Column(
                children: [
                  _buildMonthGrid(_year, _month, monthNames, dayNames),
                  const SizedBox(height: 16),
                  _buildMonthGrid(m2y, m2m, monthNames, dayNames),
                ],
              );
            }),

          const SizedBox(height: 16),

          // ─── Blocked dates list ────────────────────────────
          if (_dateBlocks.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isRtl ? 'التواريخ المغلقة' : 'Blocked Dates',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _dateBlocks.map((bl) {
                        final d = DateTime.parse(bl['date']);
                        final src = bl['source'] ?? 'MANUAL';
                        return Chip(
                          avatar: CircleAvatar(
                            radius: 6,
                            backgroundColor: AppTheme.channelColor(src),
                          ),
                          label: Text(
                            '${d.day}/${d.month} ($src)',
                            style: const TextStyle(fontSize: 10),
                          ),
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label, {bool border = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: border ? Border.all(color: AppTheme.border) : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildMonthGrid(
      int yr, int mo, List<String> monthNames, List<String> dayNames) {
    final daysInMonth = DateTime.utc(yr, mo + 1, 0).day;
    final firstDow = DateTime.utc(yr, mo, 1).weekday % 7; // 0=Sun
    final todayStr = _fmtDate(DateTime.now());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              '${monthNames[mo]} $yr',
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            // Day name headers
            Row(
              children: dayNames
                  .map((dn) => Expanded(
                        child: Center(
                          child: Text(dn,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 4),
            // Calendar grid
            ...List.generate(((firstDow + daysInMonth + 6) ~/ 7), (week) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: List.generate(7, (col) {
                    final dayNum = week * 7 + col - firstDow + 1;
                    if (dayNum < 1 || dayNum > daysInMonth) {
                      return Expanded(child: Container(height: 52));
                    }

                    final d = DateTime.utc(yr, mo, dayNum);
                    final dateStr = _fmtDate(d);
                    final isToday = dateStr == todayStr;
                    final isSelected = _selected.contains(dateStr);
                    final dayBookings = _bookingsForDay(dateStr);
                    final block = _blockForDay(dateStr);
                    final hasBooking = dayBookings.isNotEmpty;
                    final hasBlock = block != null;

                    // Background color
                    Color bgColor = Colors.white;
                    if (hasBooking) {
                      final ch = dayBookings.first['channel'] ?? '';
                      switch (ch.toString().toUpperCase()) {
                        case 'BOOKING':
                          bgColor = const Color(0xFFE0E7FF);
                          break;
                        case 'AIRBNB':
                          bgColor = const Color(0xFFFEE2E2);
                          break;
                        case 'AGODA':
                          bgColor = const Color(0xFFD1FAE5);
                          break;
                        default:
                          bgColor = const Color(0xFFF1F5F9);
                      }
                    } else if (hasBlock) {
                      bgColor = const Color(0xFFFEF3C7);
                    }

                    if (isSelected) {
                      bgColor = AppTheme.accent.withValues(alpha: 0.15);
                    }

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => _toggleDate(dateStr),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          height: 52,
                          margin: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.accent
                                  : isToday
                                      ? AppTheme.textSecondary
                                      : AppTheme.border.withValues(alpha: 0.5),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$dayNum',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isToday
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: isToday
                                      ? AppTheme.accent
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              if (hasBooking)
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 3, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppTheme.channelColor(
                                        dayBookings.first['channel'] ?? ''),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    (dayBookings.first['channel'] ?? '')
                                        .toString()
                                        .substring(
                                            0,
                                            (dayBookings.first['channel'] ?? '')
                                                        .toString()
                                                        .length >
                                                    3
                                                ? 3
                                                : (dayBookings.first[
                                                            'channel'] ??
                                                        '')
                                                    .toString()
                                                    .length),
                                    style: const TextStyle(
                                        fontSize: 7,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700),
                                  ),
                                )
                              else if (hasBlock)
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 3, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppTheme.warning,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    block['source'] == 'MANUAL' ? '🔒' : (block['source'] ?? '').toString().substring(0, 3.clamp(0, (block['source'] ?? '').toString().length)),
                                    style: const TextStyle(
                                        fontSize: 7,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
