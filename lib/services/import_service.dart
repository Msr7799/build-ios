import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

class ImportService {
  /// Pick a file (CSV, JSON, or XLSX) and return parsed unit rows.
  /// Each row is a Map with keys: name, code, defaultRate, currency
  static Future<List<Map<String, dynamic>>?> pickAndParseUnits() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'json', 'xlsx', 'xls', 'txt'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final ext = (file.extension ?? '').toLowerCase();

    // ─── Excel binary files (.xlsx / .xls) ───────────────
    if (ext == 'xlsx' || ext == 'xls') {
      Uint8List bytes;
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      } else {
        return null;
      }
      return _parseExcel(bytes);
    }

    // ─── Text-based files (CSV, JSON, TXT) ───────────────
    String content;
    if (file.bytes != null) {
      content = utf8.decode(file.bytes!, allowMalformed: true);
    } else if (file.path != null) {
      content = await File(file.path!).readAsString();
    } else {
      return null;
    }

    if (ext == 'json') {
      return _parseJson(content);
    } else {
      return _parseCsv(content);
    }
  }

  // ─── Excel parser ──────────────────────────────────────
  static List<Map<String, dynamic>> _parseExcel(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    // Use first sheet
    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName]!;
    if (sheet.rows.isEmpty) return [];

    // Read header row
    final headerRow = sheet.rows.first
        .map((cell) => (cell?.value?.toString() ?? '').toLowerCase().trim())
        .toList();

    int nameIdx = -1, codeIdx = -1, rateIdx = -1, currIdx = -1;
    for (int i = 0; i < headerRow.length; i++) {
      final h = headerRow[i];
      if (h.contains('name') || h.contains('اسم') || h.contains('unit')) {
        nameIdx = i;
      } else if (h.contains('code') || h.contains('رمز')) {
        codeIdx = i;
      } else if (h.contains('rate') || h.contains('سعر') || h.contains('price')) {
        rateIdx = i;
      } else if (h.contains('currency') || h.contains('عملة')) {
        currIdx = i;
      }
    }

    final hasHeader = nameIdx >= 0;
    if (!hasHeader) {
      nameIdx = 0;
      codeIdx = headerRow.length > 1 ? 1 : -1;
      rateIdx = headerRow.length > 2 ? 2 : -1;
      currIdx = headerRow.length > 3 ? 3 : -1;
    }

    final dataRows = hasHeader ? sheet.rows.skip(1) : sheet.rows;
    final result = <Map<String, dynamic>>[];

    for (final row in dataRows) {
      String cellVal(int idx) {
        if (idx < 0 || idx >= row.length || row[idx] == null) return '';
        return row[idx]!.value?.toString().trim() ?? '';
      }

      final name = cellVal(nameIdx);
      if (name.isEmpty) continue;

      result.add({
        'name': name,
        'code': codeIdx >= 0 ? cellVal(codeIdx) : null,
        'defaultRate': rateIdx >= 0 ? _parseNum(cellVal(rateIdx)) : null,
        'currency': currIdx >= 0 && cellVal(currIdx).isNotEmpty
            ? cellVal(currIdx)
            : 'BHD',
      });
    }
    return result;
  }

  static List<Map<String, dynamic>> _parseJson(String content) {
    final decoded = jsonDecode(content);
    List<dynamic> items;
    if (decoded is List) {
      items = decoded;
    } else if (decoded is Map && decoded.containsKey('units')) {
      items = decoded['units'] as List;
    } else if (decoded is Map && decoded.containsKey('data')) {
      items = decoded['data'] as List;
    } else {
      throw FormatException('JSON must be an array or have "units"/"data" key');
    }

    return items.map<Map<String, dynamic>>((item) {
      final m = item as Map<String, dynamic>;
      return {
        'name': m['name'] ?? m['unitName'] ?? m['unit_name'] ?? '',
        'code': m['code'] ?? m['unitCode'] ?? m['unit_code'],
        'defaultRate': _parseNum(m['defaultRate'] ?? m['rate'] ?? m['default_rate']),
        'currency': m['currency'] ?? 'BHD',
      };
    }).where((m) => (m['name'] as String).isNotEmpty).toList();
  }

  static List<Map<String, dynamic>> _parseCsv(String content) {
    final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
        .convert(content);
    if (rows.isEmpty) return [];

    // Try to detect header row
    final firstRow = rows.first.map((e) => e.toString().toLowerCase().trim()).toList();
    int nameIdx = -1, codeIdx = -1, rateIdx = -1, currIdx = -1;

    for (int i = 0; i < firstRow.length; i++) {
      final h = firstRow[i];
      if (h.contains('name') || h.contains('اسم') || h.contains('unit')) {
        nameIdx = i;
      } else if (h.contains('code') || h.contains('رمز')) {
        codeIdx = i;
      } else if (h.contains('rate') || h.contains('سعر') || h.contains('price')) {
        rateIdx = i;
      } else if (h.contains('currency') || h.contains('عملة')) {
        currIdx = i;
      }
    }

    // If no header detected, assume: name, code, rate, currency
    final hasHeader = nameIdx >= 0;
    if (!hasHeader) {
      nameIdx = 0;
      codeIdx = rows.first.length > 1 ? 1 : -1;
      rateIdx = rows.first.length > 2 ? 2 : -1;
      currIdx = rows.first.length > 3 ? 3 : -1;
    }

    final dataRows = hasHeader ? rows.skip(1) : rows;
    final result = <Map<String, dynamic>>[];

    for (final row in dataRows) {
      final name = nameIdx >= 0 && nameIdx < row.length
          ? row[nameIdx].toString().trim()
          : '';
      if (name.isEmpty) continue;

      result.add({
        'name': name,
        'code': codeIdx >= 0 && codeIdx < row.length
            ? row[codeIdx].toString().trim()
            : null,
        'defaultRate': rateIdx >= 0 && rateIdx < row.length
            ? _parseNum(row[rateIdx])
            : null,
        'currency': currIdx >= 0 && currIdx < row.length
            ? row[currIdx].toString().trim()
            : 'BHD',
      });
    }
    return result;
  }

  static double? _parseNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', ''));
  }
}
