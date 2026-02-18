import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AppProvider extends ChangeNotifier {
  final ApiService api = ApiService();

  String _locale = 'ar';
  String get locale => _locale;
  bool get isRtl => _locale == 'ar';

  void setLocale(String l) {
    _locale = l;
    notifyListeners();
  }

  // ─── Units cache ────────────────────────────────────────────
  List<Map<String, dynamic>> _units = [];
  List<Map<String, dynamic>> get units => _units;
  bool _unitsLoading = false;
  bool get unitsLoading => _unitsLoading;

  Future<void> loadUnits() async {
    _unitsLoading = true;
    _safeNotify();
    try {
      final data = await api.getUnits();
      _units = List<Map<String, dynamic>>.from(data['units'] ?? []);
    } catch (e) {
      debugPrint('loadUnits error: $e');
    }
    _unitsLoading = false;
    _safeNotify();
  }

  void _safeNotify() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  // ─── Sync ───────────────────────────────────────────────────
  bool _syncing = false;
  bool get syncing => _syncing;
  String? _syncMsg;
  String? get syncMsg => _syncMsg;

  Future<void> syncAll({String? unitId}) async {
    _syncing = true;
    _syncMsg = null;
    _safeNotify();
    try {
      final res = await api.syncAll(unitId: unitId);
      _syncMsg =
          'Synced ${res['synced'] ?? 0} feeds, ${res['errors'] ?? 0} errors';
    } catch (e) {
      _syncMsg = 'Sync failed: $e';
    }
    _syncing = false;
    _safeNotify();
  }
}
