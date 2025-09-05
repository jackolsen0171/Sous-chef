enum MessageType {
  user,
  bot,
  system,
  toolCall,
  toolResult,
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  error,
  executing,
  success,
  failed,
}

class ChatMessage {
  final String id;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final MessageStatus status;
  final Map<String, dynamic>? metadata;

  ChatMessage({
    String? id,
    required this.content,
    required this.type,
    DateTime? timestamp,
    this.status = MessageStatus.delivered,
    this.metadata,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
      'metadata': metadata,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      content: map['content'],
      type: MessageType.values.firstWhere((e) => e.name == map['type']),
      timestamp: DateTime.parse(map['timestamp']),
      status: MessageStatus.values.firstWhere((e) => e.name == map['status']),
      metadata: map['metadata'],
    );
  }

  ChatMessage copyWith({
    String? id,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    MessageStatus? status,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
    );
  }

  static ChatMessage systemMessage(String content) {
    return ChatMessage(
      content: content,
      type: MessageType.system,
    );
  }

  static ChatMessage userMessage(String content) {
    return ChatMessage(
      content: content,
      type: MessageType.user,
    );
  }

  static ChatMessage botMessage(String content, {Map<String, dynamic>? metadata}) {
    return ChatMessage(
      content: content,
      type: MessageType.bot,
      metadata: metadata,
    );
  }

  static ChatMessage toolCallMessage({
    required String toolName,
    required Map<String, dynamic> parameters,
    MessageStatus status = MessageStatus.executing,
  }) {
    return ChatMessage(
      content: toolName,
      type: MessageType.toolCall,
      status: status,
      metadata: {
        'toolName': toolName,
        'parameters': parameters,
        'startTime': DateTime.now().toIso8601String(),
      },
    );
  }

  static ChatMessage toolResultMessage({
    required String toolName,
    required dynamic result,
    required bool success,
    String? errorMessage,
  }) {
    return ChatMessage(
      content: toolName,
      type: MessageType.toolResult,
      status: success ? MessageStatus.success : MessageStatus.failed,
      metadata: {
        'toolName': toolName,
        'result': result,
        'success': success,
        'errorMessage': errorMessage,
        'endTime': DateTime.now().toIso8601String(),
      },
    );
  }
}

class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime lastUpdated;
  final List<ChatMessage> messages;

  ChatSession({
    String? id,
    required this.title,
    DateTime? createdAt,
    DateTime? lastUpdated,
    List<ChatMessage>? messages,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt = createdAt ?? DateTime.now(),
        lastUpdated = lastUpdated ?? DateTime.now(),
        messages = messages ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'messages': messages.map((m) => m.toMap()).toList(),
    };
  }

  factory ChatSession.fromMap(Map<String, dynamic> map) {
    return ChatSession(
      id: map['id'],
      title: map['title'],
      createdAt: DateTime.parse(map['createdAt']),
      lastUpdated: DateTime.parse(map['lastUpdated']),
      messages: (map['messages'] as List<dynamic>)
          .map((m) => ChatMessage.fromMap(m))
          .toList(),
    );
  }

  ChatSession copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? lastUpdated,
    List<ChatMessage>? messages,
  }) {
    return ChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      messages: messages ?? this.messages,
    );
  }
}