import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'ical_service.dart';

// DEPRECATED: This service is no longer used. All data access goes through ApiService → Vercel backend.
// Keeping file to avoid breaking imports during migration.
class DbService {
  static const String _defaultConnStr = '';

  final String connectionString;
  late final String _httpUrl;
  late final String _neonHost;
  String? _cachedIp;

  DbService({String? connectionString})
      : connectionString = connectionString ?? _defaultConnStr {
    final uri = Uri.parse(this.connectionString);
    _neonHost = uri.host;
    _httpUrl = 'https://$_neonHost/sql';
  }

  Future<void> close() async {}

  // ─── DNS resolver with Cloudflare DoH fallback ────────────
  Future<String> _resolveHost() async {
    if (_cachedIp != null) return _cachedIp!;

    // 1) Try normal DNS
    try {
      final addrs = await InternetAddress.lookup(_neonHost)
          .timeout(const Duration(seconds: 3));
      if (addrs.isNotEmpty) {
        _cachedIp = addrs.first.address;
        debugPrint('[DNS] Resolved $_neonHost → $_cachedIp');
        return _cachedIp!;
      }
    } catch (e) {
      debugPrint('[DNS] Normal lookup failed: $e');
    }

    // 2) Fallback: Cloudflare DNS-over-HTTPS (1.1.1.1 cert includes IP SAN)
    try {
      final dohClient = HttpClient();
      dohClient.connectionTimeout = const Duration(seconds: 5);
      final req = await dohClient.getUrl(
          Uri.parse('https://1.1.1.1/dns-query?name=$_neonHost&type=A'));
      req.headers.set('Accept', 'application/dns-json');
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      dohClient.close();

      final data = jsonDecode(body);
      final answers = data['Answer'] as List?;
      if (answers != null) {
        for (final a in answers) {
          if (a['type'] == 1) {
            _cachedIp = a['data'] as String;
            debugPrint('[DoH] Resolved $_neonHost → $_cachedIp');
            return _cachedIp!;
          }
        }
      }
    } catch (e) {
      debugPrint('[DoH] Cloudflare resolution failed: $e');
    }

    return _neonHost; // last resort: let the system try
  }

  // ─── HTTP SQL via Neon serverless endpoint ────────────────
  Future<List<Map<String, dynamic>>> _query(String sql, [Map<String, dynamic>? params]) async {
    String converted = sql;
    List<dynamic> positional = [];
    if (params != null && params.isNotEmpty) {
      final order = <String>[];
      final map = <String, int>{};
      converted = sql.replaceAllMapped(RegExp(r'@(\w+)'), (m) {
        final name = m.group(1)!;
        if (!map.containsKey(name)) {
          order.add(name);
          map[name] = order.length;
        }
        return '\$${map[name]}';
      });
      positional = order.map((name) {
        final v = params[name];
        if (v is DateTime) return v.toIso8601String();
        if (v is List || v is Map) return jsonEncode(v);
        return v;
      }).toList();
    }

    final resolvedIp = await _resolveHost();

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    // Route TCP to resolved IP, TLS uses original hostname for SNI
    client.connectionFactory =
        (Uri uri, String? proxyHost, int? proxyPort) async {
      if (uri.host == _neonHost) {
        return Socket.startConnect(resolvedIp, uri.port);
      }
      return Socket.startConnect(uri.host, uri.port);
    };

    try {
      final request = await client.postUrl(Uri.parse(_httpUrl));
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Neon-Connection-String', connectionString);
      request.write(jsonEncode({'query': converted, 'params': positional}));

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw Exception('DB ${response.statusCode}: $body');
      }
      final data = jsonDecode(body);
      final rows = data['rows'];
      if (rows == null || rows is! List) return [];
      return rows
          .map<Map<String, dynamic>>((r) => Map<String, dynamic>.from(r))
          .toList();
    } finally {
      client.close();
    }
  }

  List<dynamic> _jsonCol(dynamic v) {
    if (v is List) return v;
    if (v is String && v.isNotEmpty) {
      try { final d = jsonDecode(v); if (d is List) return d; } catch (_) {}
    }
    return [];
  }

  // ─── Dashboard ────────────────────────────────────────────
  Future<Map<String, dynamic>> getDashboard() async {
    final units = await _query('''
      SELECT u.id, u.name, u.code, u."defaultRate", u.currency,
             uc.title, uc.description, uc.images, uc.address,
             uc."guestCapacity", uc."propertyHighlights"
      FROM "Unit" u
      LEFT JOIN "UnitContent" uc ON uc."unitId" = u.id
      WHERE u."isActive" = true
      ORDER BY u."createdAt" ASC
    ''');

    final cards = <Map<String, dynamic>>[];
    for (final row in units) {
      final feedsRes = await _query(
          'SELECT DISTINCT channel FROM "IcalFeed" WHERE "unitId" = @id',
          {'id': row['id']});
      final channels = feedsRes.map((r) => r['channel']?.toString() ?? '').toList();
      final images = _jsonCol(row['images']).map((e) => e.toString()).toList();

      cards.add({
        'unitId': row['id'],
        'unitName': row['name'],
        'defaultRate': row['defaultRate'],
        'currency': row['currency'] ?? 'BHD',
        'images': images,
        'channels': channels,
        'address': row['address'] ?? '',
        'guestCapacity': row['guestCapacity'] ?? '',
        'propertyHighlights': row['propertyHighlights'] ?? '',
      });
    }
    return {'cards': cards};
  }

  // ─── Units ────────────────────────────────────────────────
  Future<Map<String, dynamic>> getUnits() async {
    final res = await _query('''
      SELECT id, name, code, "isActive", currency, "defaultRate",
             "createdAt", "updatedAt"
      FROM "Unit"
      WHERE "isActive" = true
      ORDER BY "createdAt" ASC
    ''');
    final units = <Map<String, dynamic>>[];
    for (final row in res) {
      final feedsRes = await _query(
          'SELECT id, channel, type, name, url, "lastSyncAt", "lastError" FROM "IcalFeed" WHERE "unitId" = @id',
          {'id': row['id']});
      row['feeds'] = feedsRes;
      units.add(row);
    }
    return {'units': units};
  }

  Future<Map<String, dynamic>> createUnit(Map<String, dynamic> data) async {
    final id = _cuid();
    final now = DateTime.now().toUtc();
    await _query('''
      INSERT INTO "Unit" (id, name, code, "defaultRate", currency, "isActive", "createdAt", "updatedAt")
      VALUES (@id, @name, @code, @rate, 'BHD', true, @now, @now)
    ''', {
      'id': id,
      'name': data['name'] ?? '',
      'code': data['code'],
      'rate': data['defaultRate'],
      'now': now,
    });
    return {'id': id, 'ok': true};
  }

  Future<Map<String, dynamic>> deleteUnit(String id) async {
    await _query('DELETE FROM "Unit" WHERE id = @id', {'id': id});
    return {'ok': true};
  }

  // ─── Feeds ────────────────────────────────────────────────
  Future<Map<String, dynamic>> addFeed(Map<String, dynamic> data) async {
    final id = _cuid();
    final now = DateTime.now().toUtc();
    await _query('''
      INSERT INTO "IcalFeed" (id, "unitId", channel, type, name, url, "createdAt", "updatedAt")
      VALUES (@id, @unitId, @channel::"Channel", @type::"FeedType", @name, @url, @now, @now)
    ''', {
      'id': id,
      'unitId': data['unitId'],
      'channel': data['channel'] ?? 'BOOKING',
      'type': data['type'] ?? 'URL',
      'name': data['name'],
      'url': data['url'],
      'now': now,
    });
    return {'id': id, 'ok': true};
  }

  Future<Map<String, dynamic>> deleteFeed(String id, {bool purge = true}) async {
    if (purge) {
      final feed = await _query(
          'SELECT "unitId", channel FROM "IcalFeed" WHERE id = @id',
          {'id': id});
      if (feed.isNotEmpty) {
        final row = feed.first;
        final ch = row['channel']?.toString() ?? '';
        if (ch != 'MANUAL') {
          await _query(
              'DELETE FROM "Booking" WHERE "unitId" = @uid AND channel = @ch::"Channel"',
              {'uid': row['unitId'], 'ch': ch});
        }
      }
    }
    await _query('DELETE FROM "IcalFeed" WHERE id = @id', {'id': id});
    return {'ok': true};
  }

  // ─── Calendar ─────────────────────────────────────────────
  Future<Map<String, dynamic>> getCalendar(String unitId, String from, String to) async {
    final fromDt = DateTime.parse('${from}T00:00:00Z');
    final toDt = DateTime.parse('${to}T23:59:59Z');

    final bookingsRes = await _query('''
      SELECT id, channel, summary, "startDate", "endDate"
      FROM "Booking"
      WHERE "unitId" = @uid AND "isCancelled" = false
        AND "startDate" <= @to AND "endDate" >= @from
      ORDER BY "startDate" ASC
    ''', {'uid': unitId, 'from': fromDt, 'to': toDt});

    final blocksRes = await _query('''
      SELECT id, date, source, reason
      FROM "DateBlock"
      WHERE "unitId" = @uid AND date >= @from AND date <= @to
      ORDER BY date ASC
    ''', {'uid': unitId, 'from': fromDt, 'to': toDt});

    final feedsRes = await _query('''
      SELECT id, channel, type, name, url, "lastSyncAt", "lastError"
      FROM "IcalFeed"
      WHERE "unitId" = @uid
    ''', {'uid': unitId});

    return {
      'bookings': bookingsRes,
      'dateBlocks': blocksRes,
      'feeds': feedsRes,
    };
  }

  Future<Map<String, dynamic>> blockDates(String unitId, List<String> dates,
      {String source = 'MANUAL', String? reason}) async {
    int created = 0;
    for (final d in dates) {
      final dateUtc = DateTime.parse('${d}T00:00:00Z');
      try {
        await _query('''
          INSERT INTO "DateBlock" (id, "unitId", date, source, reason, "createdAt")
          VALUES (@id, @uid, @date, @src, @reason, @now)
          ON CONFLICT ("unitId", date) DO UPDATE SET source = @src, reason = @reason
        ''', {
          'id': _cuid(),
          'uid': unitId,
          'date': dateUtc,
          'src': source,
          'reason': reason,
          'now': DateTime.now().toUtc(),
        });
        created++;
      } catch (e) {
        debugPrint('[block] error for $d: $e');
      }
    }
    return {'ok': true, 'created': created};
  }

  Future<Map<String, dynamic>> unblockDates(String unitId, List<String> dates) async {
    int deleted = 0;
    for (final d in dates) {
      final dateUtc = DateTime.parse('${d}T00:00:00Z');
      await _query(
          'DELETE FROM "DateBlock" WHERE "unitId" = @uid AND date = @date',
          {'uid': unitId, 'date': dateUtc});
      deleted++;
    }
    return {'ok': true, 'deleted': deleted};
  }

  // ─── Bookings ─────────────────────────────────────────────
  Future<Map<String, dynamic>> getBookings({String? unitId, String? from, String? to}) async {
    String where = 'WHERE 1=1';
    final params = <String, dynamic>{};
    if (unitId != null) { where += ' AND "unitId" = @uid'; params['uid'] = unitId; }
    if (from != null) { where += ' AND "endDate" >= @from'; params['from'] = DateTime.parse('${from}T00:00:00Z'); }
    if (to != null) { where += ' AND "startDate" <= @to'; params['to'] = DateTime.parse('${to}T23:59:59Z'); }

    final res = await _query('''
      SELECT id, "unitId", channel, "externalUid", summary,
             "startDate", "endDate", currency,
             "grossAmount", "commissionAmount", "taxAmount", "otherFeesAmount", "netAmount",
             "paymentStatus", notes, "isCancelled"
      FROM "Booking"
      $where
      ORDER BY "startDate" DESC
      LIMIT 200
    ''', params);
    return {'bookings': res};
  }

  Future<Map<String, dynamic>> updateBooking(String id, Map<String, dynamic> data) async {
    final sets = <String>[];
    final params = <String, dynamic>{'id': id, 'now': DateTime.now().toUtc()};
    if (data.containsKey('grossAmount')) { sets.add('"grossAmount" = @gross'); params['gross'] = data['grossAmount']; }
    if (data.containsKey('commissionAmount')) { sets.add('"commissionAmount" = @comm'); params['comm'] = data['commissionAmount']; }
    if (data.containsKey('taxAmount')) { sets.add('"taxAmount" = @tax'); params['tax'] = data['taxAmount']; }
    if (data.containsKey('otherFeesAmount')) { sets.add('"otherFeesAmount" = @fees'); params['fees'] = data['otherFeesAmount']; }
    if (data.containsKey('paymentStatus')) { sets.add('"paymentStatus" = @ps::"PaymentStatus"'); params['ps'] = data['paymentStatus']; }
    if (data.containsKey('notes')) { sets.add('notes = @notes'); params['notes'] = data['notes']; }

    // Auto-calculate net
    sets.add('"netAmount" = COALESCE("grossAmount",0) - COALESCE("commissionAmount",0) - COALESCE("taxAmount",0) - COALESCE("otherFeesAmount",0)');
    sets.add('"updatedAt" = @now');

    if (sets.isNotEmpty) {
      await _query('UPDATE "Booking" SET ${sets.join(", ")} WHERE id = @id', params);
    }
    return {'ok': true};
  }

  // ─── Content ──────────────────────────────────────────────
  Future<Map<String, dynamic>> getContent(String unitId) async {
    final res = await _query('''
      SELECT * FROM "UnitContent" WHERE "unitId" = @uid
    ''', {'uid': unitId});
    if (res.isEmpty) return {'master': {}};
    return {'master': res.first};
  }

  Future<Map<String, dynamic>> saveContent(String unitId, Map<String, dynamic> data) async {
    final now = DateTime.now().toUtc();
    await _query('''
      INSERT INTO "UnitContent" (id, "unitId", title, description, "houseRules",
        "checkInInfo", "checkOutInfo", amenities, images, "locationNote",
        address, "guestCapacity", "propertyHighlights", "damageDeposit",
        "cancellationPolicy", "nearbyPlaces", "createdAt", "updatedAt")
      VALUES (@id, @uid, @title, @desc, @rules, @ci, @co, @amenities, @images,
        @loc, @addr, @cap, @hi, @dep, @cancel, @near, @now, @now)
      ON CONFLICT ("unitId") DO UPDATE SET
        title = @title, description = @desc, "houseRules" = @rules,
        "checkInInfo" = @ci, "checkOutInfo" = @co,
        amenities = @amenities, images = @images, "locationNote" = @loc,
        address = @addr, "guestCapacity" = @cap, "propertyHighlights" = @hi,
        "damageDeposit" = @dep, "cancellationPolicy" = @cancel,
        "nearbyPlaces" = @near, "updatedAt" = @now
    ''', {
      'id': _cuid(), 'uid': unitId,
      'title': data['title'], 'desc': data['description'],
      'rules': data['houseRules'], 'ci': data['checkInInfo'],
      'co': data['checkOutInfo'],
      'amenities': data['amenities'] is List ? data['amenities'] : null,
      'images': data['images'] is List ? data['images'] : null,
      'loc': data['locationNote'], 'addr': data['address'],
      'cap': data['guestCapacity'], 'hi': data['propertyHighlights'],
      'dep': data['damageDeposit'], 'cancel': data['cancellationPolicy'],
      'near': data['nearbyPlaces'], 'now': now,
    });
    return {'ok': true};
  }

  // ─── Expenses ─────────────────────────────────────────────
  Future<Map<String, dynamic>> getExpenses({String? unitId, String? from, String? to}) async {
    String where = 'WHERE 1=1';
    final params = <String, dynamic>{};
    if (unitId != null) { where += ' AND "unitId" = @uid'; params['uid'] = unitId; }
    if (from != null) { where += ' AND "spentAt" >= @from'; params['from'] = DateTime.parse('${from}T00:00:00Z'); }
    if (to != null) { where += ' AND "spentAt" <= @to'; params['to'] = DateTime.parse('${to}T23:59:59Z'); }

    final res = await _query('''
      SELECT id, "unitId", category, amount, currency, "spentAt", note
      FROM "Expense" $where ORDER BY "spentAt" DESC LIMIT 200
    ''', params);
    return {'expenses': res};
  }

  Future<Map<String, dynamic>> createExpense(Map<String, dynamic> data) async {
    final id = _cuid();
    await _query('''
      INSERT INTO "Expense" (id, "unitId", category, amount, currency, "spentAt", note, "createdAt")
      VALUES (@id, @uid, @cat::"ExpenseCategory", @amt, 'BHD', @dt, @note, @now)
    ''', {
      'id': id, 'uid': data['unitId'],
      'cat': data['category'] ?? 'OTHER',
      'amt': data['amount'] ?? 0,
      'dt': DateTime.tryParse(data['spentAt'] ?? '') ?? DateTime.now().toUtc(),
      'note': data['note'], 'now': DateTime.now().toUtc(),
    });
    return {'ok': true, 'id': id};
  }

  Future<Map<String, dynamic>> deleteExpense(String id) async {
    await _query('DELETE FROM "Expense" WHERE id = @id', {'id': id});
    return {'ok': true};
  }

  // ─── Reports ──────────────────────────────────────────────
  Future<Map<String, dynamic>> getReports({String? unitId}) async {
    final unitFilter = unitId != null ? 'AND "unitId" = @uid' : '';
    final params = <String, dynamic>{};
    if (unitId != null) params['uid'] = unitId;

    final bookingRes = await _query('''
      SELECT to_char("startDate", 'YYYY-MM') AS month,
             COALESCE(SUM("netAmount"), 0) AS "bookingNet",
             MIN(currency) AS currency
      FROM "Booking"
      WHERE "isCancelled" = false $unitFilter
      GROUP BY month ORDER BY month DESC LIMIT 24
    ''', params);

    final expRes = await _query('''
      SELECT to_char("spentAt", 'YYYY-MM') AS month,
             COALESCE(SUM(amount), 0) AS "expenseTotal"
      FROM "Expense"
      WHERE 1=1 $unitFilter
      GROUP BY month ORDER BY month DESC LIMIT 24
    ''', params);

    final bMap = <String, Map<String, dynamic>>{};
    for (final r in bookingRes) {
      bMap[r['month']] = r;
    }
    final eMap = <String, dynamic>{};
    for (final r in expRes) {
      eMap[r['month']] = r['expenseTotal'];
    }

    final allMonths = {...bMap.keys, ...eMap.keys}.toList()..sort((a, b) => b.compareTo(a));
    final months = allMonths.map((m) {
      final bn = bMap[m]?['bookingNet'] ?? 0;
      final et = eMap[m] ?? 0;
      return {
        'month': m,
        'bookingNet': bn,
        'expenseTotal': et,
        'currency': bMap[m]?['currency'] ?? 'BHD',
      };
    }).toList();

    return {'months': months};
  }

  // ─── Rates ────────────────────────────────────────────────
  Future<Map<String, dynamic>> getRates({String? unitId}) async {
    String where = '';
    final params = <String, dynamic>{};
    if (unitId != null) { where = 'WHERE "unitId" = @uid'; params['uid'] = unitId; }

    final res = await _query('''
      SELECT id, "unitId", channel, name, "startDate", "endDate",
             "baseRate", "weekendRate", "minNights", "maxNights", "stopSell", priority
      FROM "RateRule" $where ORDER BY "startDate" ASC
    ''', params);
    return {'rules': res};
  }

  Future<Map<String, dynamic>> createRate(Map<String, dynamic> data) async {
    final id = _cuid();
    final now = DateTime.now().toUtc();
    await _query('''
      INSERT INTO "RateRule" (id, "unitId", channel, name, "startDate", "endDate",
        "baseRate", "weekendRate", "minNights", "stopSell", priority, "createdAt", "updatedAt")
      VALUES (@id, @uid, @ch::"Channel", @name, @start, @end, @base, @wknd, @min, @stop, 0, @now, @now)
    ''', {
      'id': id, 'uid': data['unitId'],
      'ch': data['channel'],
      'name': data['name'] ?? '',
      'start': DateTime.tryParse(data['startDate'] ?? '') ?? now,
      'end': DateTime.tryParse(data['endDate'] ?? '') ?? now,
      'base': data['baseRate'] ?? 0,
      'wknd': data['weekendRate'],
      'min': data['minNights'] ?? 1,
      'stop': data['stopSell'] == true,
      'now': now,
    });
    return {'ok': true, 'id': id};
  }

  Future<Map<String, dynamic>> deleteRate(String id) async {
    await _query('DELETE FROM "RateRule" WHERE id = @id', {'id': id});
    return {'ok': true};
  }

  Future<Map<String, dynamic>> getRatesPreview({String? unitId, String? channel}) async {
    return {'days': []};
  }

  // ─── Payouts ──────────────────────────────────────────────
  Future<Map<String, dynamic>> getPayouts() async {
    final payouts = await _query('''
      SELECT id, channel, "payoutDate", currency, amount, "providerRef", status, note
      FROM "Payout" ORDER BY "payoutDate" DESC LIMIT 100
    ''');
    for (final p in payouts) {
      final linesRes = await _query(
          'SELECT id, amount, note FROM "PayoutLine" WHERE "payoutId" = @id',
          {'id': p['id']});
      p['lines'] = linesRes;
    }
    return {'payouts': payouts};
  }

  Future<Map<String, dynamic>> createPayout(Map<String, dynamic> data) async {
    final id = _cuid();
    await _query('''
      INSERT INTO "Payout" (id, channel, "payoutDate", currency, amount, "providerRef", status, note, "createdAt")
      VALUES (@id, @ch::"Channel", @dt, 'BHD', @amt, @ref, 'RECEIVED'::"PayoutStatus", @note, @now)
    ''', {
      'id': id,
      'ch': data['channel'] ?? 'BOOKING',
      'dt': DateTime.tryParse(data['payoutDate'] ?? '') ?? DateTime.now().toUtc(),
      'amt': data['amount'] ?? 0,
      'ref': data['providerRef'],
      'note': data['note'],
      'now': DateTime.now().toUtc(),
    });
    return {'ok': true, 'id': id};
  }

  Future<Map<String, dynamic>> deletePayout(String id) async {
    await _query('DELETE FROM "Payout" WHERE id = @id', {'id': id});
    return {'ok': true};
  }

  // ─── Publishing ───────────────────────────────────────────
  Future<Map<String, dynamic>> getPublishingStatus({String? unitId}) async {
    return {'channels': []};
  }

  Future<Map<String, dynamic>> markPublished(Map<String, dynamic> data) async {
    return {'ok': true};
  }

  // ─── Sync iCal feeds ─────────────────────────────────────
  Future<Map<String, dynamic>> syncAll({String? unitId}) async {
    int synced = 0;
    int errors = 0;

    String feedSql = 'SELECT id, "unitId", channel, url FROM "IcalFeed" WHERE type = \'URL\' AND url IS NOT NULL';
    final params = <String, dynamic>{};
    if (unitId != null) {
      feedSql += ' AND "unitId" = @uid';
      params['uid'] = unitId;
    }

    final feeds = await _query(feedSql, params);

    for (final feed in feeds) {
      final feedId = feed['id'] as String;
      final feedUnitId = feed['unitId'] as String;
      final channel = feed['channel']?.toString() ?? 'BOOKING';
      final url = feed['url']?.toString() ?? '';
      if (url.isEmpty) continue;

      try {
        final events = await IcalService.fetchAndParse(url);

        for (final evt in events) {
          final bookingId = _cuid();
          final existing = await _query(
            'SELECT id FROM "Booking" WHERE "externalUid" = @uid AND "unitId" = @unitId LIMIT 1',
            {'uid': evt.uid, 'unitId': feedUnitId});

          if (existing.isEmpty) {
            await _query('''
              INSERT INTO "Booking" (id, "unitId", channel, summary, "startDate", "endDate",
                "externalUid", "isCancelled", "createdAt", "updatedAt")
              VALUES (@id, @unitId, @ch::"Channel", @summary, @start, @end,
                @uid, false, @now, @now)
            ''', {
              'id': bookingId,
              'unitId': feedUnitId,
              'ch': channel,
              'summary': evt.summary,
              'start': evt.start,
              'end': evt.end,
              'uid': evt.uid,
              'now': DateTime.now().toUtc(),
            });
          } else {
            await _query('''
              UPDATE "Booking" SET summary = @summary, "startDate" = @start, "endDate" = @end,
                "isCancelled" = false, "updatedAt" = @now
              WHERE "externalUid" = @uid AND "unitId" = @unitId
            ''', {
              'summary': evt.summary,
              'start': evt.start,
              'end': evt.end,
              'uid': evt.uid,
              'unitId': feedUnitId,
              'now': DateTime.now().toUtc(),
            });
          }
        }

        await _query(
          'UPDATE "IcalFeed" SET "lastSyncAt" = @now, "lastError" = NULL, "updatedAt" = @now WHERE id = @id',
          {'id': feedId, 'now': DateTime.now().toUtc()});

        synced += events.length;
        debugPrint('Synced ${events.length} events from $channel feed');
      } catch (e) {
        errors++;
        debugPrint('Sync error for feed $feedId: $e');
        try {
          await _query(
            'UPDATE "IcalFeed" SET "lastError" = @err, "updatedAt" = @now WHERE id = @id',
            {'id': feedId, 'err': e.toString(), 'now': DateTime.now().toUtc()});
        } catch (_) {}
      }
    }

    return {'synced': synced, 'errors': errors, 'feeds': feeds.length};
  }

  // ─── Bulk import units ──────────────────────────────────
  Future<Map<String, dynamic>> bulkImportUnits(List<Map<String, dynamic>> units) async {
    int imported = 0;
    int skipped = 0;

    for (final u in units) {
      final name = u['name']?.toString() ?? '';
      if (name.isEmpty) {
        skipped++;
        continue;
      }

      final existing = await _query(
        'SELECT id FROM "Unit" WHERE name = @name LIMIT 1',
        {'name': name},
      );
      if (existing.isNotEmpty) {
        skipped++;
        continue;
      }

      final id = _cuid();
      final now = DateTime.now().toUtc();
      await _query('''
        INSERT INTO "Unit" (id, name, code, "defaultRate", currency, "isActive", "createdAt", "updatedAt")
        VALUES (@id, @name, @code, @rate, @currency, true, @now, @now)
      ''', {
        'id': id,
        'name': name,
        'code': u['code'],
        'rate': u['defaultRate'],
        'currency': u['currency'] ?? 'BHD',
        'now': now,
      });
      imported++;
    }

    return {'imported': imported, 'skipped': skipped, 'total': units.length};
  }

  // ─── CUID generator ──────────────────────────────────────
  static int _counter = 0;
  String _cuid() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _counter++;
    final rnd = now.toRadixString(36);
    final cnt = _counter.toRadixString(36).padLeft(4, '0');
    return 'cl$rnd$cnt';
  }
}
