import 'package:uuid/uuid.dart';

class SimsarMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  
  SimsarMessage({
    String? id,
    required this.content,
    required this.isUser,
    DateTime? timestamp,
  }) : id = id ?? const Uuid().v4(),
       timestamp = timestamp ?? DateTime.now();
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'isUser': isUser,
    'timestamp': timestamp.toIso8601String(),
  };
  
  factory SimsarMessage.fromJson(Map<String, dynamic> json) => SimsarMessage(
    id: json['id'],
    content: json['content'],
    isUser: json['isUser'],
    timestamp: DateTime.parse(json['timestamp']),
  );
  
  Map<String, String> toApiFormat() => {
    'role': isUser ? 'user' : 'assistant',
    'content': content,
  };
}

class SimsarConversation {
  final String id;
  String title;
  final List<SimsarMessage> messages;
  final DateTime createdAt;
  DateTime updatedAt;
  
  SimsarConversation({
    String? id,
    this.title = 'محادثة جديدة',
    List<SimsarMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       messages = messages ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'messages': messages.map((m) => m.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
  
  factory SimsarConversation.fromJson(Map<String, dynamic> json) => SimsarConversation(
    id: json['id'],
    title: json['title'],
    messages: (json['messages'] as List).map((m) => SimsarMessage.fromJson(m)).toList(),
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
  );
}
