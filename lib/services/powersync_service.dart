import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';
import 'powersync_schema.dart';
import 'powersync_connector.dart';

/// PowerSync Service - Singleton for managing offline-first sync
class PowerSyncService {
  static PowerSyncService? _instance;
  static PowerSyncService get instance => _instance ??= PowerSyncService._();

  late PowerSyncDatabase db;
  late NeonPowerSyncConnector connector;
  bool _initialized = false;

  PowerSyncService._();

  /// Initialize PowerSync - SECURE: No database credentials needed!
  Future<void> initialize({
    required String powerSyncEndpoint,
    required String devToken,
  }) async {
    if (_initialized) return;

    // Get local database path
    final dir = await getApplicationSupportDirectory();
    final dbPath = join(dir.path, 'powersync.db');

    // Create PowerSync database with schema
    db = PowerSyncDatabase(
      schema: schema,
      path: dbPath,
    );

    await db.initialize();

    // Create secure connector - PowerSync handles all database operations
    connector = NeonPowerSyncConnector(
      db: db,
      powerSyncEndpoint: powerSyncEndpoint,
      devToken: devToken,
    );

    // Connect PowerSync to backend
    await db.connect(connector: connector);

    _initialized = true;
    print('✅ PowerSync initialized: $dbPath');
  }

  /// Check sync status
  Future<SyncStatus> getSyncStatus() async {
    return await db.currentStatus;
  }

  /// Force a sync now
  Future<void> syncNow() async {
    // PowerSync syncs automatically, but you can trigger manually
    await db.waitForFirstSync();
  }

  /// Disconnect and close
  Future<void> dispose() async {
    await db.disconnect();
    await db.close();
    _initialized = false;
  }

  // ─── Query Helpers ───

  /// Get all active units
  Future<List<Map<String, dynamic>>> getUnits() async {
    return await db.getAll('SELECT * FROM Unit WHERE isActive = 1 ORDER BY name');
  }

  /// Get bookings for a unit in date range
  Future<List<Map<String, dynamic>>> getBookings({
    required String unitId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (startDate != null && endDate != null) {
      return await db.getAll(
        'SELECT * FROM Booking WHERE unitId = ? AND startDate >= ? AND endDate <= ? ORDER BY startDate',
        [unitId, startDate.toIso8601String(), endDate.toIso8601String()],
      );
    }
    return await db.getAll(
      'SELECT * FROM Booking WHERE unitId = ? ORDER BY startDate DESC',
      [unitId],
    );
  }

  /// Get blocked dates for a unit
  Future<List<Map<String, dynamic>>> getBlockedDates(String unitId) async {
    return await db.getAll(
      'SELECT * FROM DateBlock WHERE unitId = ? ORDER BY date',
      [unitId],
    );
  }

  /// Get expenses for a unit
  Future<List<Map<String, dynamic>>> getExpenses(String unitId) async {
    return await db.getAll(
      'SELECT * FROM Expense WHERE unitId = ? ORDER BY spentAt DESC',
      [unitId],
    );
  }

  // ─── Write Operations (will auto-sync to Neon) ───

  /// Create a new booking (will sync to server)
  Future<void> createBooking(Map<String, dynamic> booking) async {
    await db.execute(
      '''INSERT INTO Booking 
         (id, unitId, channel, externalUid, summary, startDate, endDate, 
          lastSeenAt, isCancelled, currency, paymentStatus, createdAt, updatedAt)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        booking['id'],
        booking['unitId'],
        booking['channel'],
        booking['externalUid'],
        booking['summary'],
        booking['startDate'],
        booking['endDate'],
        DateTime.now().toIso8601String(),
        booking['isCancelled'] ?? 0,
        booking['currency'],
        booking['paymentStatus'],
        DateTime.now().toIso8601String(),
        DateTime.now().toIso8601String(),
      ],
    );
  }

  /// Update booking
  Future<void> updateBooking(String id, Map<String, dynamic> updates) async {
    final setClauses = updates.keys.map((k) => '$k = ?').join(', ');
    final values = [...updates.values, DateTime.now().toIso8601String(), id];

    await db.execute(
      'UPDATE Booking SET $setClauses, updatedAt = ? WHERE id = ?',
      values,
    );
  }

  /// Delete booking
  Future<void> deleteBooking(String id) async {
    await db.execute('DELETE FROM Booking WHERE id = ?', [id]);
  }

  /// Add date block
  Future<void> blockDate({
    required String unitId,
    required DateTime date,
    required String source,
    String? reason,
  }) async {
    final id = '${unitId}_${date.toIso8601String()}';
    await db.execute(
      'INSERT OR REPLACE INTO DateBlock (id, unitId, date, source, reason, createdAt) VALUES (?, ?, ?, ?, ?, ?)',
      [id, unitId, date.toIso8601String(), source, reason, DateTime.now().toIso8601String()],
    );
  }

  /// Remove date block
  Future<void> unblockDate(String unitId, DateTime date) async {
    await db.execute(
      'DELETE FROM DateBlock WHERE unitId = ? AND date = ?',
      [unitId, date.toIso8601String()],
    );
  }
}
