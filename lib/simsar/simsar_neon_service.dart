import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'simsar_models.dart';

/// Service for storing Simsar conversations in Neon PostgreSQL database
class SimsarNeonService {
  // Neon connection details - should be in .env in production
  static const String _defaultConnStr = 
      'postgresql://neondb_owner:npg_PQLwn3qJi1gD@ep-black-butterfly-a5gepxjt-pooler.us-east-2.aws.neon.tech/neondb?sslmode=require';
  
  final String connectionString;
  late final String _httpUrl;
  late final String _neonHost;
  String? _cachedIp;
  bool _initialized = false;

  SimsarNeonService({String? connectionString})
      : connectionString = connectionString ?? _defaultConnStr {
    final uri = Uri.parse(this.connectionString);
    _neonHost = uri.host;
    _httpUrl = 'https://$_neonHost/sql';
  }

  /// Initialize the database schema
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Create conversations table if not exists
      await _query('''
        CREATE TABLE IF NOT EXISTS "SimsarConversation" (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL DEFAULT 'محادثة جديدة',
          messages JSONB NOT NULL DEFAULT '[]',
          "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
          "updatedAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
        )
      ''');
      
      // Create index for faster queries
      await _query('''
        CREATE INDEX IF NOT EXISTS idx_simsar_conv_updated 
        ON "SimsarConversation" ("updatedAt" DESC)
      ''');
      
      _initialized = true;
      debugPrint('[SimsarNeon] Database initialized');
    } catch (e) {
      debugPrint('[SimsarNeon] Failed to initialize: $e');
    }
  }

  /// DNS resolver with Cloudflare DoH fallback
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

    // 2) Fallback: Cloudflare DNS-over-HTTPS
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

    return _neonHost;
  }

  /// Execute SQL query via Neon HTTP endpoint
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
    client.connectionFactory = (Uri uri, String? proxyHost, int? proxyPort) async {
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
      return rows.map<Map<String, dynamic>>((r) => Map<String, dynamic>.from(r)).toList();
    } finally {
      client.close();
    }
  }

  /// Save a conversation to database
  Future<void> saveConversation(SimsarConversation conversation) async {
    await initialize();
    
    try {
      final messagesJson = jsonEncode(conversation.messages.map((m) => m.toJson()).toList());
      
      await _query('''
        INSERT INTO "SimsarConversation" (id, title, messages, "createdAt", "updatedAt")
        VALUES (@id, @title, @messages::jsonb, @createdAt, @updatedAt)
        ON CONFLICT (id) DO UPDATE SET
          title = @title,
          messages = @messages::jsonb,
          "updatedAt" = @updatedAt
      ''', {
        'id': conversation.id,
        'title': conversation.title,
        'messages': messagesJson,
        'createdAt': conversation.createdAt,
        'updatedAt': conversation.updatedAt,
      });
      
      debugPrint('[SimsarNeon] Saved conversation ${conversation.id}');
    } catch (e) {
      debugPrint('[SimsarNeon] Failed to save conversation: $e');
      rethrow;
    }
  }

  /// Load all conversations from database
  Future<List<SimsarConversation>> loadConversations() async {
    await initialize();
    
    try {
      final rows = await _query('''
        SELECT id, title, messages, "createdAt", "updatedAt"
        FROM "SimsarConversation"
        ORDER BY "updatedAt" DESC
        LIMIT 100
      ''');
      
      return rows.map((row) {
        List<SimsarMessage> messages = [];
        final messagesData = row['messages'];
        
        if (messagesData != null) {
          List<dynamic> messagesList;
          if (messagesData is String) {
            messagesList = jsonDecode(messagesData) as List;
          } else if (messagesData is List) {
            messagesList = messagesData;
          } else {
            messagesList = [];
          }
          
          messages = messagesList
              .map((m) => SimsarMessage.fromJson(Map<String, dynamic>.from(m)))
              .toList();
        }
        
        return SimsarConversation(
          id: row['id'] as String,
          title: row['title'] as String? ?? 'محادثة جديدة',
          messages: messages,
          createdAt: DateTime.tryParse(row['createdAt']?.toString() ?? '') ?? DateTime.now(),
          updatedAt: DateTime.tryParse(row['updatedAt']?.toString() ?? '') ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      debugPrint('[SimsarNeon] Failed to load conversations: $e');
      return [];
    }
  }

  /// Delete a conversation from database
  Future<void> deleteConversation(String id) async {
    await initialize();
    
    try {
      await _query('DELETE FROM "SimsarConversation" WHERE id = @id', {'id': id});
      debugPrint('[SimsarNeon] Deleted conversation $id');
    } catch (e) {
      debugPrint('[SimsarNeon] Failed to delete conversation: $e');
    }
  }

  /// Get a single conversation by ID
  Future<SimsarConversation?> getConversation(String id) async {
    await initialize();
    
    try {
      final rows = await _query('''
        SELECT id, title, messages, "createdAt", "updatedAt"
        FROM "SimsarConversation"
        WHERE id = @id
      ''', {'id': id});
      
      if (rows.isEmpty) return null;
      
      final row = rows.first;
      List<SimsarMessage> messages = [];
      final messagesData = row['messages'];
      
      if (messagesData != null) {
        List<dynamic> messagesList;
        if (messagesData is String) {
          messagesList = jsonDecode(messagesData) as List;
        } else if (messagesData is List) {
          messagesList = messagesData;
        } else {
          messagesList = [];
        }
        
        messages = messagesList
            .map((m) => SimsarMessage.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      }
      
      return SimsarConversation(
        id: row['id'] as String,
        title: row['title'] as String? ?? 'محادثة جديدة',
        messages: messages,
        createdAt: DateTime.tryParse(row['createdAt']?.toString() ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(row['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      );
    } catch (e) {
      debugPrint('[SimsarNeon] Failed to get conversation: $e');
      return null;
    }
  }
}
