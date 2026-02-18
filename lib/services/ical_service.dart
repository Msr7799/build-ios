import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Parsed iCal event
class IcalEvent {
  final String uid;
  final String summary;
  final DateTime start;
  final DateTime end;
  IcalEvent({required this.uid, required this.summary, required this.start, required this.end});
}

/// Service for fetching and parsing iCal (.ics) feeds
class IcalService {
  static const _ua =
      'Mozilla/5.0 (compatible; PMS-Lite/1.0; +https://pms-lite.app)';

  /// Fetch ICS content from a URL and parse events
  static Future<List<IcalEvent>> fetchAndParse(String url) async {
    final response = await http.get(
      Uri.parse(url.trim()),
      headers: {'User-Agent': _ua},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch iCal (${response.statusCode})');
    }
    return parseIcs(response.body);
  }

  /// Parse ICS text into events
  static List<IcalEvent> parseIcs(String icsText) {
    final events = <IcalEvent>[];
    final lines = _unfoldLines(icsText);

    bool inEvent = false;
    String uid = '';
    String summary = '';
    DateTime? dtStart;
    DateTime? dtEnd;

    for (final line in lines) {
      if (line.startsWith('BEGIN:VEVENT')) {
        inEvent = true;
        uid = '';
        summary = '';
        dtStart = null;
        dtEnd = null;
      } else if (line.startsWith('END:VEVENT')) {
        if (inEvent && dtStart != null && dtEnd != null) {
          events.add(IcalEvent(
            uid: uid.isNotEmpty ? uid : 'evt_${events.length}',
            summary: summary,
            start: dtStart,
            end: dtEnd,
          ));
        }
        inEvent = false;
      } else if (inEvent) {
        if (line.startsWith('UID:')) {
          uid = line.substring(4).trim();
        } else if (line.startsWith('SUMMARY:')) {
          summary = line.substring(8).trim();
        } else if (line.startsWith('DTSTART')) {
          dtStart = _parseIcalDate(line);
        } else if (line.startsWith('DTEND')) {
          dtEnd = _parseIcalDate(line);
        }
      }
    }
    return events;
  }

  /// Unfold continuation lines per RFC 5545
  static List<String> _unfoldLines(String text) {
    final raw = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final result = <String>[];
    for (final line in raw.split('\n')) {
      if (line.startsWith(' ') || line.startsWith('\t')) {
        if (result.isNotEmpty) {
          result[result.length - 1] += line.substring(1);
        }
      } else {
        result.add(line);
      }
    }
    return result;
  }

  /// Parse iCal date/datetime values like:
  /// DTSTART;VALUE=DATE:20250301
  /// DTSTART:20250301T140000Z
  /// DTSTART;TZID=Asia/Bahrain:20250301T140000
  static DateTime? _parseIcalDate(String line) {
    // Get the value part after the last ':'
    final colonIdx = line.indexOf(':');
    if (colonIdx < 0) return null;
    final val = line.substring(colonIdx + 1).trim();
    if (val.isEmpty) return null;

    // Remove non-digit chars except T and Z for parsing
    final clean = val.replaceAll('-', '');

    try {
      if (clean.length == 8) {
        // DATE only: 20250301
        return DateTime.utc(
          int.parse(clean.substring(0, 4)),
          int.parse(clean.substring(4, 6)),
          int.parse(clean.substring(6, 8)),
        );
      } else if (clean.length >= 15) {
        // DATETIME: 20250301T140000 or 20250301T140000Z
        return DateTime.utc(
          int.parse(clean.substring(0, 4)),
          int.parse(clean.substring(4, 6)),
          int.parse(clean.substring(6, 8)),
          int.parse(clean.substring(9, 11)),
          int.parse(clean.substring(11, 13)),
          int.parse(clean.substring(13, 15)),
        );
      }
    } catch (e) {
      debugPrint('iCal date parse error: $e for $val');
    }
    return null;
  }
}
