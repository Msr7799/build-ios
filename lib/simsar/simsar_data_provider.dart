import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

/// Provides real property data to Simsar AI assistant
class SimsarDataProvider {
  final ApiService _api = ApiService();
  
  // Cached data
  List<Map<String, dynamic>> _units = [];
  Map<String, List<Map<String, dynamic>>> _cachedCalendars = {};
  Map<String, Map<String, dynamic>> _cachedContent = {};
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _rates = [];
  List<Map<String, dynamic>> _reportMonths = [];
  Map<String, dynamic>? _dashboard;
  DateTime? _lastFetchTime;
  bool _isLoading = false;
  
  static const Duration _cacheTimeout = Duration(minutes: 5);
  
  /// Check if cache is valid
  bool get _isCacheValid => 
      _lastFetchTime != null && 
      DateTime.now().difference(_lastFetchTime!) < _cacheTimeout;

  /// Helper: safely extract list from API response
  List<Map<String, dynamic>> _extractList(Map<String, dynamic> response, List<String> keys) {
    for (final key in keys) {
      final val = response[key];
      if (val is List) {
        return val.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    }
    // If response itself is a list-like structure at root
    if (response.containsKey('data')) {
      final val = response['data'];
      if (val is List) {
        return val.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    }
    return [];
  }
  
  /// Refresh all data from API
  Future<void> refreshData() async {
    if (_isLoading) return;
    _isLoading = true;
    
    try {
      debugPrint('[SimsarDataProvider] Starting data refresh...');
      
      // Fetch core data in parallel
      final results = await Future.wait([
        _api.getDashboard().catchError((e) { debugPrint('[SimsarDP] dashboard error: $e'); return <String,dynamic>{}; }),
        _api.getUnits().catchError((e) { debugPrint('[SimsarDP] units error: $e'); return <String,dynamic>{}; }),
        _api.getBookings().catchError((e) { debugPrint('[SimsarDP] bookings error: $e'); return <String,dynamic>{}; }),
        _api.getRates().catchError((e) { debugPrint('[SimsarDP] rates error: $e'); return <String,dynamic>{}; }),
        _api.getReports().catchError((e) { debugPrint('[SimsarDP] reports error: $e'); return <String,dynamic>{}; }),
      ]);
      
      _dashboard = results[0];
      
      // Parse units - API returns { units: [...] } or { data: [...] } or [...]
      final unitsResp = results[1];
      _units = _extractList(unitsResp, ['units', 'data', 'items']);
      debugPrint('[SimsarDP] Loaded ${_units.length} units. Keys: ${unitsResp.keys.toList()}');
      
      // Parse bookings
      final bookingsResp = results[2];
      _bookings = _extractList(bookingsResp, ['bookings', 'data', 'items']);
      debugPrint('[SimsarDP] Loaded ${_bookings.length} bookings');
      
      // Parse rates
      final ratesResp = results[3];
      _rates = _extractList(ratesResp, ['rules', 'rates', 'data', 'items']);
      debugPrint('[SimsarDP] Loaded ${_rates.length} rate rules');
      
      // Parse reports
      final reportsResp = results[4];
      _reportMonths = _extractList(reportsResp, ['months', 'data', 'items']);
      debugPrint('[SimsarDP] Loaded ${_reportMonths.length} report months');
      
      // Fetch content and calendar for each unit
      for (final unit in _units) {
        final unitId = unit['id'] as String?;
        if (unitId == null) continue;
        
        try {
          final content = await _api.getContent(unitId)
              .catchError((e) { debugPrint('[SimsarDP] content error for $unitId: $e'); return <String,dynamic>{}; });
          if (content.isNotEmpty) {
            _cachedContent[unitId] = content;
          }
          
          // Get calendar for next 3 months
          final now = DateTime.now();
          final from = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
          final futureDate = now.add(const Duration(days: 90));
          final to = '${futureDate.year}-${futureDate.month.toString().padLeft(2, '0')}-${futureDate.day.toString().padLeft(2, '0')}';
          
          final calendar = await _api.getCalendar(unitId, from, to)
              .catchError((e) { debugPrint('[SimsarDP] calendar error for $unitId: $e'); return <String,dynamic>{}; });
          
          final calBookings = (calendar['bookings'] as List? ?? [])
              .whereType<Map>().map((b) => Map<String, dynamic>.from(b)).toList();
          final calBlocks = (calendar['dateBlocks'] as List? ?? [])
              .whereType<Map>().map((b) => Map<String, dynamic>.from(b)).toList();
          
          _cachedCalendars[unitId] = [...calBookings, ...calBlocks];
          debugPrint('[SimsarDP] Unit $unitId: ${calBookings.length} bookings, ${calBlocks.length} blocks in calendar');
        } catch (e) {
          debugPrint('[SimsarDP] Error fetching data for unit $unitId: $e');
        }
      }
      
      _lastFetchTime = DateTime.now();
      debugPrint('[SimsarDP] Data refresh complete. Units: ${_units.length}, Bookings: ${_bookings.length}');
    } catch (e) {
      debugPrint('[SimsarDP] Error refreshing data: $e');
    } finally {
      _isLoading = false;
    }
  }

  
  /// Ensure data is loaded
  Future<void> ensureDataLoaded() async {
    if (!_isCacheValid) {
      await refreshData();
    }
  }
  
  /// Get comprehensive context for AI
  Future<String> getFullContext() async {
    await ensureDataLoaded();
    
    final buffer = StringBuffer();
    buffer.writeln('=== بيانات العقارات الحالية ===');
    buffer.writeln('تاريخ التحديث: ${DateTime.now().toString().substring(0, 16)}');
    buffer.writeln();
    
    // Units summary
    buffer.writeln(_getUnitsSummary());
    buffer.writeln();
    
    // Bookings summary
    buffer.writeln(_getBookingsSummary());
    buffer.writeln();
    
    // Calendar/Availability
    buffer.writeln(_getAvailabilitySummary());
    buffer.writeln();
    
    // Rates
    buffer.writeln(_getRatesSummary());
    buffer.writeln();
    
    // Financial summary
    buffer.writeln(_getFinancialSummary());
    buffer.writeln();
    
    // Content details
    buffer.writeln(_getContentSummary());
    
    return buffer.toString();
  }
  
  String _getUnitsSummary() {
    final units = _units;
    if (units.isEmpty) return '📊 الوحدات: لا توجد وحدات مسجلة في النظام';
    
    final buffer = StringBuffer();
    buffer.writeln('📊 الوحدات العقارية (${units.length} وحدة):');
    
    for (final unit in units) {
      final name = unit['name'] ?? 'بدون اسم';
      final code = unit['code'] ?? '';
      final rate = unit['defaultRate'] ?? 0;
      final currency = unit['currency'] ?? 'BHD';
      final feeds = (unit['feeds'] as List?) ?? [];
      
      buffer.writeln('  • $name ${code.isNotEmpty ? "($code)" : ""}');
      buffer.writeln('    - السعر الافتراضي: $rate $currency/ليلة');
      buffer.writeln('    - التزامنات: ${feeds.length} تقويم');
      
      for (final feed in feeds) {
        final channel = feed['channel'] ?? 'غير محدد';
        final feedName = feed['name'] ?? '';
        final lastSync = feed['lastSyncAt'];
        final lastError = feed['lastError'];
        
        String syncStatus = lastSync != null 
            ? 'آخر مزامنة: ${_formatDate(lastSync)}'
            : 'لم تتم المزامنة';
        if (lastError != null && lastError.toString().isNotEmpty) {
          syncStatus += ' ⚠️ خطأ';
        }
        
        buffer.writeln('      - $channel ${feedName.isNotEmpty ? "($feedName)" : ""}: $syncStatus');
      }
    }
    
    return buffer.toString();
  }
  
  String _getBookingsSummary() {
    final bookings = _bookings;
    if (bookings.isEmpty) return '📅 الحجوزات: لا توجد حجوزات مسجلة';
    
    final buffer = StringBuffer();
    final now = DateTime.now();
    
    // Categorize bookings
    final upcoming = <Map<String, dynamic>>[];
    final current = <Map<String, dynamic>>[];
    final past = <Map<String, dynamic>>[];
    
    for (final booking in bookings) {
      if (booking['isCancelled'] == true) continue;
      
      final startStr = booking['startDate']?.toString() ?? '';
      final endStr = booking['endDate']?.toString() ?? '';
      
      DateTime? startDate;
      DateTime? endDate;
      
      try {
        startDate = DateTime.parse(startStr);
        endDate = DateTime.parse(endStr);
      } catch (_) {
        continue;
      }
      
      final bookingMap = Map<String, dynamic>.from(booking);
      bookingMap['_startDate'] = startDate;
      bookingMap['_endDate'] = endDate;
      
      if (endDate.isBefore(now)) {
        past.add(bookingMap);
      } else if (startDate.isAfter(now)) {
        upcoming.add(bookingMap);
      } else {
        current.add(bookingMap);
      }
    }
    
    // Sort upcoming by start date
    upcoming.sort((a, b) => (a['_startDate'] as DateTime).compareTo(b['_startDate'] as DateTime));
    
    buffer.writeln('📅 الحجوزات:');
    buffer.writeln('  - إجمالي الحجوزات: ${bookings.length}');
    buffer.writeln('  - الحجوزات الحالية: ${current.length}');
    buffer.writeln('  - الحجوزات القادمة: ${upcoming.length}');
    buffer.writeln('  - الحجوزات السابقة: ${past.length}');
    
    if (current.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('  🏨 الحجوزات الحالية:');
      for (final b in current) {
        _writeBookingDetails(buffer, b);
      }
    }
    
    if (upcoming.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('  📆 الحجوزات القادمة:');
      for (final b in upcoming.take(10)) {
        _writeBookingDetails(buffer, b);
      }
      if (upcoming.length > 10) {
        buffer.writeln('    ... و ${upcoming.length - 10} حجز آخر');
      }
    }
    
    return buffer.toString();
  }
  
  void _writeBookingDetails(StringBuffer buffer, Map<String, dynamic> booking) {
    final unitId = booking['unitId'];
    final unitName = _getUnitName(unitId) ?? 'وحدة غير معروفة';
    final summary = booking['summary'] ?? 'بدون ملخص';
    final startDate = booking['_startDate'] as DateTime?;
    final endDate = booking['_endDate'] as DateTime?;
    final channel = booking['channel'] ?? '';
    final gross = booking['grossAmount'];
    final net = booking['netAmount'];
    final paymentStatus = booking['paymentStatus'] ?? '';
    final currency = booking['currency'] ?? 'BHD';
    
    int nights = 0;
    if (startDate != null && endDate != null) {
      nights = endDate.difference(startDate).inDays;
    }
    
    buffer.writeln('    • $unitName: ${_formatDateShort(startDate)} - ${_formatDateShort(endDate)} ($nights ليالي)');
    buffer.writeln('      الملخص: $summary');
    if (channel.isNotEmpty) buffer.writeln('      القناة: $channel');
    if (gross != null) buffer.writeln('      المبلغ الإجمالي: $gross $currency');
    if (net != null) buffer.writeln('      الصافي: $net $currency');
    if (paymentStatus.isNotEmpty) buffer.writeln('      حالة الدفع: ${_translatePaymentStatus(paymentStatus)}');
  }
  
  String _getAvailabilitySummary() {
    final buffer = StringBuffer();
    buffer.writeln('🗓️ التوافر والتقويمات:');
    
    final units = _units;
    if (units.isEmpty) {
      buffer.writeln('  لا توجد وحدات');
      return buffer.toString();
    }
    
    for (final unit in units) {
      final unitId = unit['id'] as String?;
      final unitName = unit['name'] ?? 'بدون اسم';
      
      if (unitId == null) continue;
      
      final events = _cachedCalendars[unitId] ?? [];
      final bookingsCount = events.where((e) => e.containsKey('summary')).length;
      final blocksCount = events.where((e) => e.containsKey('reason') || e.containsKey('source')).length;
      
      buffer.writeln('  • $unitName:');
      buffer.writeln('    - حجوزات قادمة: $bookingsCount');
      buffer.writeln('    - أيام محظورة: $blocksCount');
      
      // Calculate available days in next 30 days
      final now = DateTime.now();
      final bookedDays = <DateTime>{};
      
      for (final event in events) {
        final startStr = event['startDate']?.toString() ?? event['date']?.toString() ?? '';
        final endStr = event['endDate']?.toString() ?? startStr;
        
        try {
          final start = DateTime.parse(startStr);
          final end = DateTime.parse(endStr);
          
          for (var d = start; d.isBefore(end) || d.isAtSameMomentAs(end); d = d.add(const Duration(days: 1))) {
            bookedDays.add(DateTime(d.year, d.month, d.day));
          }
        } catch (_) {}
      }
      
      int availableDays = 0;
      for (int i = 0; i < 30; i++) {
        final day = DateTime(now.year, now.month, now.day).add(Duration(days: i));
        if (!bookedDays.contains(day)) {
          availableDays++;
        }
      }
      
      buffer.writeln('    - أيام متاحة (30 يوم قادمة): $availableDays يوم');
    }
    
    return buffer.toString();
  }
  
  String _getRatesSummary() {
    final rules = _rates;
    if (rules.isEmpty) return '💰 الأسعار: لا توجد قواعد تسعير مخصصة';
    
    final buffer = StringBuffer();
    buffer.writeln('💰 قواعد التسعير (${rules.length} قاعدة):');
    
    for (final rule in rules.take(10)) {
      final unitId = rule['unitId'];
      final unitName = _getUnitName(unitId) ?? 'كل الوحدات';
      final name = rule['name'] ?? 'بدون اسم';
      final channel = rule['channel'] ?? 'كل القنوات';
      final baseRate = rule['baseRate'] ?? 0;
      final weekendRate = rule['weekendRate'];
      final minNights = rule['minNights'] ?? 1;
      final startDate = rule['startDate'];
      final endDate = rule['endDate'];
      
      buffer.writeln('  • $name ($unitName - $channel):');
      buffer.writeln('    - السعر الأساسي: $baseRate');
      if (weekendRate != null) buffer.writeln('    - سعر نهاية الأسبوع: $weekendRate');
      buffer.writeln('    - الحد الأدنى للإقامة: $minNights ليلة');
      if (startDate != null && endDate != null) {
        buffer.writeln('    - الفترة: ${_formatDateShort(DateTime.tryParse(startDate.toString()))} - ${_formatDateShort(DateTime.tryParse(endDate.toString()))}');
      }
    }
    
    if (rules.length > 10) {
      buffer.writeln('  ... و ${rules.length - 10} قاعدة أخرى');
    }
    
    return buffer.toString();
  }
  
  String _getFinancialSummary() {
    final months = _reportMonths;
    if (months.isEmpty) return '📈 الإحصائيات المالية: لا توجد بيانات';
    
    final buffer = StringBuffer();
    buffer.writeln('📈 الإحصائيات المالية:');
    
    num totalRevenue = 0;
    num totalExpenses = 0;
    
    for (final month in months.take(6)) {
      final monthName = month['month'] ?? '';
      final revenue = (month['bookingNet'] ?? 0) as num;
      final expenses = (month['expenseTotal'] ?? 0) as num;
      final currency = month['currency'] ?? 'BHD';
      final profit = revenue - expenses;
      
      totalRevenue += revenue;
      totalExpenses += expenses;
      
      buffer.writeln('  • $monthName:');
      buffer.writeln('    - الإيرادات: $revenue $currency');
      buffer.writeln('    - المصروفات: $expenses $currency');
      buffer.writeln('    - الصافي: $profit $currency');
    }
    
    if (months.length > 1) {
      final currency = months.first['currency'] ?? 'BHD';
      buffer.writeln();
      buffer.writeln('  📊 الإجمالي (آخر ${months.length.clamp(1, 6)} شهور):');
      buffer.writeln('    - إجمالي الإيرادات: $totalRevenue $currency');
      buffer.writeln('    - إجمالي المصروفات: $totalExpenses $currency');
      buffer.writeln('    - صافي الربح: ${totalRevenue - totalExpenses} $currency');
    }
    
    return buffer.toString();
  }
  
  String _getContentSummary() {
    if (_cachedContent.isEmpty) return '🏠 محتوى الوحدات: لا يوجد محتوى';
    
    final buffer = StringBuffer();
    buffer.writeln('🏠 محتوى الوحدات:');
    
    for (final entry in _cachedContent.entries) {
      final unitId = entry.key;
      final unitName = _getUnitName(unitId) ?? 'وحدة غير معروفة';
      final content = entry.value['master'] as Map<String, dynamic>? ?? {};
      
      if (content.isEmpty) continue;
      
      final title = content['title'] ?? '';
      final description = content['description'] ?? '';
      final address = content['address'] ?? '';
      final guestCapacity = content['guestCapacity'] ?? '';
      final amenities = (content['amenities'] as List?) ?? [];
      final images = (content['images'] as List?) ?? [];
      final checkIn = content['checkInInfo'] ?? '';
      final checkOut = content['checkOutInfo'] ?? '';
      final houseRules = content['houseRules'] ?? '';
      final highlights = content['propertyHighlights'] ?? '';
      
      buffer.writeln('  • $unitName:');
      if (title.isNotEmpty) buffer.writeln('    - العنوان: $title');
      if (description.isNotEmpty) {
        final shortDesc = description.length > 200 
            ? '${description.substring(0, 200)}...' 
            : description;
        buffer.writeln('    - الوصف: $shortDesc');
      }
      if (address.isNotEmpty) buffer.writeln('    - العنوان: $address');
      if (guestCapacity.toString().isNotEmpty) buffer.writeln('    - سعة الضيوف: $guestCapacity');
      if (amenities.isNotEmpty) buffer.writeln('    - المرافق: ${amenities.join(", ")}');
      buffer.writeln('    - الصور: ${images.length} صورة');
      if (images.isNotEmpty) {
        buffer.writeln('    - الصورة الرئيسية: ${images.first}');
      }
      if (checkIn.isNotEmpty) buffer.writeln('    - تسجيل الوصول: $checkIn');
      if (checkOut.isNotEmpty) buffer.writeln('    - تسجيل المغادرة: $checkOut');
      if (houseRules.isNotEmpty) {
        final shortRules = houseRules.length > 100 
            ? '${houseRules.substring(0, 100)}...' 
            : houseRules;
        buffer.writeln('    - قواعد المنزل: $shortRules');
      }
      if (highlights.isNotEmpty) buffer.writeln('    - مميزات العقار: $highlights');
    }
    
    return buffer.toString();
  }
  
  String? _getUnitName(String? unitId) {
    if (unitId == null) return null;
    for (final unit in _units) {
      if (unit['id'] == unitId) {
        return unit['name'] as String?;
      }
    }
    return null;
  }
  
  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final dt = date is DateTime ? date : DateTime.parse(date.toString());
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return date.toString();
    }
  }
  
  String _formatDateShort(DateTime? date) {
    if (date == null) return '';
    return '${date.day}/${date.month}';
  }
  
  String _translatePaymentStatus(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING': return 'في الانتظار';
      case 'PARTIAL': return 'دفع جزئي';
      case 'PAID': return 'مدفوع بالكامل';
      case 'REFUNDED': return 'مسترد';
      default: return status;
    }
  }
  
  /// Get specific data for targeted queries
  Future<Map<String, dynamic>> getUpcomingBookings({int limit = 10}) async {
    await ensureDataLoaded();
    
    final bookings = _bookings;
    final now = DateTime.now();
    
    final upcoming = bookings
        .where((b) {
          if (b['isCancelled'] == true) return false;
          try {
            final start = DateTime.parse(b['startDate'].toString());
            return start.isAfter(now);
          } catch (_) {
            return false;
          }
        })
        .take(limit)
        .map((b) {
          final unitId = b['unitId'];
          return {
            ...b,
            'unitName': _getUnitName(unitId) ?? 'غير معروف',
          };
        })
        .toList();
    
    return {'bookings': upcoming, 'total': bookings.length};
  }
  
  /// Get unit details by name
  Future<Map<String, dynamic>?> getUnitByName(String name) async {
    await ensureDataLoaded();
    
    final units = _units;
    final nameLower = name.toLowerCase();
    
    for (final unit in units) {
      final unitName = (unit['name'] ?? '').toString().toLowerCase();
      final unitCode = (unit['code'] ?? '').toString().toLowerCase();
      
      if (unitName.contains(nameLower) || unitCode.contains(nameLower)) {
        final unitId = unit['id'] as String?;
        final content = unitId != null ? _cachedContent[unitId] : null;
        final calendar = unitId != null ? _cachedCalendars[unitId] : null;
        return {
          ...unit,
          'content': content?['master'],
          'calendar': calendar,
        };
      }
    }
    
    return null;
  }
  
  /// Get revenue summary
  Future<Map<String, dynamic>> getRevenueSummary() async {
    await ensureDataLoaded();
    return {'months': _reportMonths};
  }
  
  /// Get units count
  Future<int> getUnitsCount() async {
    await ensureDataLoaded();
    return _units.length;
  }
  
  /// Get units list directly
  List<Map<String, dynamic>> get units => _units;
  
  /// Get bookings list directly
  List<Map<String, dynamic>> get bookings => _bookings;
}
