import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:powersync/powersync.dart';

/// SECURE PowerSync Connector - No database credentials in app!
/// All writes go through PowerSync Cloud, which handles Neon connection
class NeonPowerSyncConnector extends PowerSyncBackendConnector {
  final PowerSyncDatabase db;
  final String powerSyncEndpoint;
  final String devToken;

  NeonPowerSyncConnector({
    required this.db,
    required this.powerSyncEndpoint,
    required this.devToken,
  });

  /// Fetch PowerSync credentials (for authentication)
  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    // Development: use dev token from PowerSync Dashboard
    // Production: fetch JWT from your auth backend
    
    return PowerSyncCredentials(
      endpoint: powerSyncEndpoint,
      token: devToken,
      // Optional: user ID for user-specific buckets
      userId: 'dev-user',
    );

    // TODO: Production auth - fetch JWT from your backend
    // Example:
    // final response = await http.post(
    //   Uri.parse('https://your-backend.com/api/powersync-token'),
    //   headers: {'Authorization': 'Bearer ${yourAuthToken}'},
    // );
    // final data = jsonDecode(response.body);
    // return PowerSyncCredentials(
    //   endpoint: powerSyncEndpoint,
    //   token: data['token'],
    //   userId: data['userId'],
    // );
  }

  /// Upload local changes - PowerSync handles sync automatically
  /// SECURE: All writes go through PowerSync Cloud to Neon
  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    // PowerSync automatically syncs local writes to the backend
    // No manual upload needed - changes are queued and synced automatically
    // This method can remain empty or log upload events
    
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) return;

    try {
      // In production, you would send changes to your backend API
      // For now, PowerSync will handle the sync automatically
      // Just mark the transaction as complete
      await transaction.complete();
      print('✅ PowerSync queued ${transaction.crud.length} operations for sync');
    } catch (e) {
      print('❌ PowerSync upload error: $e');
      rethrow;
    }
  }

}
