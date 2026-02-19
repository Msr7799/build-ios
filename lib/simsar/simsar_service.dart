import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'simsar_config.dart';
import 'simsar_models.dart';
import 'simsar_data_provider.dart';
import 'simsar_neon_service.dart';

class SimsarService {
  static final SimsarService _instance = SimsarService._internal();
  factory SimsarService() => _instance;
  SimsarService._internal();

  List<SimsarConversation> _conversations = [];
  SimsarConversation? _currentConversation;
  
  // Data provider for real property data
  final SimsarDataProvider _dataProvider = SimsarDataProvider();
  
  // Neon DB service for cloud storage
  final SimsarNeonService _neonService = SimsarNeonService();
  
  // Track current model being used
  String _currentModel = SimsarConfig.defaultModel;
  String get currentModel => _currentModel;
  String get currentModelName => SimsarConfig.getModelName(_currentModel);
  
  // Data context cache
  String? _cachedDataContext;
  DateTime? _lastContextRefresh;
  
  List<SimsarConversation> get conversations => _conversations;
  SimsarConversation? get currentConversation => _currentConversation;
  SimsarDataProvider get dataProvider => _dataProvider;

  /// Load conversations - tries Neon DB first, falls back to local storage
  Future<void> loadConversations() async {
    try {
      // Try loading from Neon DB first
      final neonConversations = await _neonService.loadConversations();
      if (neonConversations.isNotEmpty) {
        _conversations = neonConversations;
        debugPrint('[SimsarService] Loaded ${_conversations.length} conversations from Neon DB');
      } else {
        // Fallback to local storage
        final prefs = await SharedPreferences.getInstance();
        final data = prefs.getString('simsar_conversations');
        if (data != null) {
          final List<dynamic> jsonList = jsonDecode(data);
          _conversations = jsonList.map((j) => SimsarConversation.fromJson(j)).toList();
          debugPrint('[SimsarService] Loaded ${_conversations.length} conversations from local storage');
          
          // Migrate to Neon DB
          for (final conv in _conversations) {
            await _neonService.saveConversation(conv);
          }
        }
      }
      _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      
      // Pre-load data context
      _refreshDataContext();
    } catch (e) {
      debugPrint('[SimsarService] Error loading conversations: $e');
    }
  }

  /// Save conversations to both Neon DB and local storage
  Future<void> saveConversations() async {
    try {
      // Save to Neon DB
      if (_currentConversation != null) {
        await _neonService.saveConversation(_currentConversation!);
      }
      
      // Also save to local storage as backup
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_conversations.map((c) => c.toJson()).toList());
      await prefs.setString('simsar_conversations', data);
    } catch (e) {
      debugPrint('[SimsarService] Error saving conversations: $e');
    }
  }
  
  /// Refresh data context from API
  Future<void> _refreshDataContext() async {
    try {
      _cachedDataContext = await _dataProvider.getFullContext();
      _lastContextRefresh = DateTime.now();
      debugPrint('[SimsarService] Data context refreshed');
    } catch (e) {
      debugPrint('[SimsarService] Error refreshing data context: $e');
    }
  }
  
  /// Get current data context (refresh if stale)
  Future<String> _getDataContext() async {
    final shouldRefresh = _lastContextRefresh == null ||
        DateTime.now().difference(_lastContextRefresh!) > const Duration(minutes: 5);
    
    if (shouldRefresh || _cachedDataContext == null) {
      await _refreshDataContext();
    }
    
    return _cachedDataContext ?? '';
  }

  void newConversation() {
    _currentConversation = SimsarConversation();
    _conversations.insert(0, _currentConversation!);
  }

  void selectConversation(SimsarConversation conversation) {
    _currentConversation = conversation;
  }

  Future<void> deleteConversation(SimsarConversation conversation) async {
    _conversations.remove(conversation);
    if (_currentConversation?.id == conversation.id) {
      _currentConversation = _conversations.isNotEmpty ? _conversations.first : null;
    }
    
    // Delete from Neon DB
    await _neonService.deleteConversation(conversation.id);
    await saveConversations();
  }
  
  /// Force refresh property data
  Future<void> refreshPropertyData() async {
    await _dataProvider.refreshData();
    await _refreshDataContext();
  }

  Stream<String> sendMessage(String content) async* {
    if (!SimsarConfig.isConfigured) {
      yield '⚠️ سمسار غير مُعَد. يرجى إضافة SIMSAR_API_KEY';
      return;
    }

    if (_currentConversation == null) {
      newConversation();
    }

    // Add user message
    final userMessage = SimsarMessage(content: content, isUser: true);
    _currentConversation!.messages.add(userMessage);
    _currentConversation!.updatedAt = DateTime.now();

    // Generate title from first message
    if (_currentConversation!.messages.length == 1) {
      _currentConversation!.title = content.length > 30 
          ? '${content.substring(0, 30)}...' 
          : content;
    }

    // Select the best model for this query (Omni routing)
    _currentModel = SimsarConfig.getModelForQuery(content);
    debugPrint('[SimsarService] Selected model: $_currentModel for query: ${content.substring(0, content.length.clamp(0, 50))}...');

    // Get real property data context
    final dataContext = await _getDataContext();
    final systemPrompt = SimsarConfig.getSystemPrompt(dataContext);

    // Build messages for API with real data context
    final apiMessages = [
      {'role': 'system', 'content': systemPrompt},
      ..._currentConversation!.messages.map((m) => m.toApiFormat()),
    ];

    try {
      final request = http.Request('POST', Uri.parse(SimsarConfig.apiUrl));
      request.headers.addAll(SimsarConfig.headers);
      request.body = jsonEncode({
        'model': _currentModel,
        'messages': apiMessages,
        'stream': true,
        'max_tokens': 4096,
        'temperature': 0.7,
      });

      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        debugPrint('[SimsarService] API Error: ${response.statusCode} - $body');
        
        // Try fallback model if primary fails
        if (_currentModel != SimsarConfig.defaultModel) {
          debugPrint('[SimsarService] Trying fallback model...');
          _currentModel = SimsarConfig.defaultModel;
          yield* _retryWithModel(apiMessages);
          return;
        }
        
        yield '⚠️ خطأ: ${response.statusCode}';
        return;
      }

      final assistantMessage = SimsarMessage(content: '', isUser: false);
      _currentConversation!.messages.add(assistantMessage);

      String fullContent = '';
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        final lines = chunk.split('\n');
        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6);
            if (data == '[DONE]') continue;
            
            try {
              final json = jsonDecode(data);
              final content = json['choices']?[0]?['delta']?['content'] ?? '';
              if (content.isNotEmpty) {
                fullContent += content;
                yield content;
              }
            } catch (_) {}
          }
        }
      }

      // Update assistant message with full content
      final index = _currentConversation!.messages.indexOf(assistantMessage);
      if (index != -1) {
        _currentConversation!.messages[index] = SimsarMessage(
          id: assistantMessage.id,
          content: fullContent,
          isUser: false,
          timestamp: assistantMessage.timestamp,
        );
      }

      _currentConversation!.updatedAt = DateTime.now();
      await saveConversations();

    } catch (e) {
      debugPrint('[SimsarService] Error: $e');
      yield '⚠️ خطأ في الاتصال: $e';
    }
  }
  
  /// Retry with a different model
  Stream<String> _retryWithModel(List<Map<String, dynamic>> apiMessages) async* {
    try {
      final request = http.Request('POST', Uri.parse(SimsarConfig.apiUrl));
      request.headers.addAll(SimsarConfig.headers);
      request.body = jsonEncode({
        'model': _currentModel,
        'messages': apiMessages,
        'stream': true,
        'max_tokens': 4096,
        'temperature': 0.7,
      });

      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        yield '⚠️ خطأ في الاتصال بالنموذج';
        return;
      }

      String fullContent = '';
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        final lines = chunk.split('\n');
        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6);
            if (data == '[DONE]') continue;
            
            try {
              final json = jsonDecode(data);
              final content = json['choices']?[0]?['delta']?['content'] ?? '';
              if (content.isNotEmpty) {
                fullContent += content;
                yield content;
              }
            } catch (_) {}
          }
        }
      }

      // Update last message
      if (_currentConversation != null && _currentConversation!.messages.isNotEmpty) {
        final lastIndex = _currentConversation!.messages.length - 1;
        if (!_currentConversation!.messages[lastIndex].isUser) {
          _currentConversation!.messages[lastIndex] = SimsarMessage(
            id: _currentConversation!.messages[lastIndex].id,
            content: fullContent,
            isUser: false,
            timestamp: _currentConversation!.messages[lastIndex].timestamp,
          );
        }
      }

      await saveConversations();
    } catch (e) {
      yield '⚠️ خطأ: $e';
    }
  }

  Future<void> regenerateLastMessage() async {
    if (_currentConversation == null || _currentConversation!.messages.isEmpty) return;

    // Find last user message
    SimsarMessage? lastUserMessage;
    for (int i = _currentConversation!.messages.length - 1; i >= 0; i--) {
      if (_currentConversation!.messages[i].isUser) {
        lastUserMessage = _currentConversation!.messages[i];
        break;
      }
    }

    if (lastUserMessage == null) return;

    // Remove last assistant message if exists
    if (_currentConversation!.messages.isNotEmpty && 
        !_currentConversation!.messages.last.isUser) {
      _currentConversation!.messages.removeLast();
    }

    // Remove the user message too (will be re-added by sendMessage)
    _currentConversation!.messages.remove(lastUserMessage);
  }

  String? getLastUserMessageContent() {
    if (_currentConversation == null) return null;
    for (int i = _currentConversation!.messages.length - 1; i >= 0; i--) {
      if (_currentConversation!.messages[i].isUser) {
        return _currentConversation!.messages[i].content;
      }
    }
    return null;
  }
}
