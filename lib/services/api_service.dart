import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiService {
  final String baseUrl;
  ApiService({String? baseUrl}) : baseUrl = baseUrl ?? ApiConfig.baseUrl;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-api-key': 'pms-lite-secret-api-key',
      };

  Future<Map<String, dynamic>> get(String path,
      {Map<String, String>? query}) async {
    final res = await http.get(_uri(path, query), headers: _headers);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body);
    }
    throw ApiException(res.statusCode, res.body);
  }

  Future<Map<String, dynamic>> post(String path,
      {Map<String, dynamic>? body}) async {
    final res = await http.post(
      _uri(path),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body);
    }
    throw ApiException(res.statusCode, res.body);
  }

  Future<Map<String, dynamic>> put(String path,
      {Map<String, dynamic>? body}) async {
    final res = await http.put(
      _uri(path),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body);
    }
    throw ApiException(res.statusCode, res.body);
  }

  Future<Map<String, dynamic>> patch(String path,
      {Map<String, dynamic>? body}) async {
    final res = await http.patch(
      _uri(path),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body);
    }
    throw ApiException(res.statusCode, res.body);
  }

  Future<Map<String, dynamic>> delete(String path,
      {Map<String, dynamic>? body, Map<String, String>? query}) async {
    final req = http.Request('DELETE', _uri(path, query));
    req.headers.addAll(_headers);
    if (body != null) req.body = jsonEncode(body);
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body);
    }
    throw ApiException(res.statusCode, res.body);
  }

  // ─── Dashboard ──────────────────────────────────────────────
  Future<Map<String, dynamic>> getDashboard() => get(ApiConfig.dashboard);

  // ─── Units ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> getUnits() => get(ApiConfig.units);
  Future<Map<String, dynamic>> createUnit(Map<String, dynamic> data) =>
      post(ApiConfig.units, body: data);
  Future<Map<String, dynamic>> updateUnit(String id, Map<String, dynamic> data) =>
      patch(ApiConfig.unit(id), body: data);
  Future<Map<String, dynamic>> deleteUnit(String id) =>
      delete(ApiConfig.unit(id));

  // ─── Feeds ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> addFeed(Map<String, dynamic> data) =>
      post(ApiConfig.feeds, body: data);
  Future<Map<String, dynamic>> deleteFeed(String id, {bool purge = true}) =>
      delete(ApiConfig.feed(id), query: {'purge': purge ? '1' : '0'});

  // ─── Sync ───────────────────────────────────────────────────
  Future<Map<String, dynamic>> syncAll({String? unitId}) =>
      post(ApiConfig.sync, body: unitId != null ? {'unitId': unitId} : {});

  // ─── Calendar ───────────────────────────────────────────────
  Future<Map<String, dynamic>> getCalendar(
          String unitId, String from, String to) =>
      get(ApiConfig.calendar(unitId), query: {'from': from, 'to': to});

  Future<Map<String, dynamic>> blockDates(
          String unitId, List<String> dates,
          {String source = 'MANUAL', String? reason}) =>
      post(ApiConfig.calendarBlock(unitId),
          body: {'dates': dates, 'source': source, 'reason': reason});

  Future<Map<String, dynamic>> unblockDates(
          String unitId, List<String> dates) =>
      delete(ApiConfig.calendarBlock(unitId), body: {'dates': dates});

  // ─── Bookings ───────────────────────────────────────────────
  Future<Map<String, dynamic>> getBookings(
          {String? unitId, String? from, String? to}) =>
      get(ApiConfig.bookings, query: {
        if (unitId != null) 'unitId': unitId,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
      });

  Future<Map<String, dynamic>> updateBooking(
          String id, Map<String, dynamic> data) =>
      patch(ApiConfig.booking(id), body: data);

  // ─── Content ────────────────────────────────────────────────
  Future<Map<String, dynamic>> getContent(String unitId) =>
      get(ApiConfig.content(unitId));
  Future<Map<String, dynamic>> saveContent(
          String unitId, Map<String, dynamic> data) =>
      put(ApiConfig.content(unitId), body: {'master': data});
  Future<Map<String, dynamic>> extractFromUrl(String url) =>
      post('/api/content/extract', body: {'url': url});

  // ─── Expenses ───────────────────────────────────────────────
  Future<Map<String, dynamic>> getExpenses(
          {String? unitId, String? from, String? to}) =>
      get(ApiConfig.expenses, query: {
        if (unitId != null) 'unitId': unitId,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
      });
  Future<Map<String, dynamic>> createExpense(Map<String, dynamic> data) =>
      post(ApiConfig.expenses, body: data);
  Future<Map<String, dynamic>> deleteExpense(String id) =>
      delete(ApiConfig.expense(id));

  // ─── Reports ────────────────────────────────────────────────
  Future<Map<String, dynamic>> getReports({String? unitId}) =>
      get(ApiConfig.reports, query: {
        if (unitId != null) 'unitId': unitId,
      });

  // ─── Rates ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> getRates({String? unitId}) =>
      get(ApiConfig.rates, query: {
        if (unitId != null) 'unitId': unitId,
      });
  Future<Map<String, dynamic>> createRate(Map<String, dynamic> data) =>
      post(ApiConfig.rates, body: data);
  Future<Map<String, dynamic>> deleteRate(String id) =>
      delete(ApiConfig.rate(id));
  Future<Map<String, dynamic>> getRatesPreview(
          {String? unitId, String? channel}) =>
      get(ApiConfig.ratesPreview, query: {
        if (unitId != null) 'unitId': unitId,
        if (channel != null) 'channel': channel,
      });

  // ─── Payouts ────────────────────────────────────────────────
  Future<Map<String, dynamic>> getPayouts() => get(ApiConfig.payouts);
  Future<Map<String, dynamic>> createPayout(Map<String, dynamic> data) =>
      post(ApiConfig.payouts, body: data);
  Future<Map<String, dynamic>> deletePayout(String id) =>
      delete(ApiConfig.payout(id));
  Future<Map<String, dynamic>> allocatePayout(
          String id, Map<String, dynamic> data) =>
      post(ApiConfig.payoutAllocate(id), body: data);

  // ─── Publishing ─────────────────────────────────────────────
  Future<Map<String, dynamic>> getPublishingStatus({String? unitId}) =>
      get(ApiConfig.publishingStatus, query: {
        if (unitId != null) 'unitId': unitId,
      });
  Future<Map<String, dynamic>> markPublished(Map<String, dynamic> data) =>
      post(ApiConfig.publishing, body: data);

  // ─── Notes ─────────────────────────────────────────────────
  Future<List<dynamic>> getNotes({String? unitId, bool? isResolved}) async {
    final res = await http.get(_uri(ApiConfig.notes, {
      if (unitId != null) 'unitId': unitId,
      if (isResolved != null) 'isResolved': isResolved.toString(),
    }), headers: _headers);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body);
    }
    throw ApiException(res.statusCode, res.body);
  }

  Future<Map<String, dynamic>> createNote(Map<String, dynamic> data) =>
      post(ApiConfig.notes, body: data);

  Future<Map<String, dynamic>> updateNote(
          String id, Map<String, dynamic> data) =>
      patch(ApiConfig.note(id), body: data);

  Future<Map<String, dynamic>> deleteNote(String id) =>
      delete(ApiConfig.note(id));

  Future<Map<String, dynamic>> uploadFile(String filePath) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl${ApiConfig.upload}'),
    );
    request.headers['x-api-key'] = 'pms-lite-secret-api-key';
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body);
    }
    throw ApiException(res.statusCode, res.body);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String body;
  ApiException(this.statusCode, this.body);

  @override
  String toString() => 'ApiException($statusCode): $body';
}
