import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../models/ingredient.dart';
import '../models/ai_tool.dart';
import '../services/chatbot_service.dart';
import '../services/logger_service.dart';
import '../services/tool_registry.dart';
import '../services/tool_executor.dart';
import '../services/ingredient_list_parser.dart';
import 'inventory_provider.dart';

class ChatProvider extends ChangeNotifier {
  final ChatbotService _chatbotService = ChatbotService.instance;
  final LoggerService _logger = LoggerService.instance;
  final ToolRegistry _toolRegistry = ToolRegistry.instance;

  List<ChatMessage> _messages = [];
  final bool _isLoading = false;
  bool _isTyping = false;
  String? _error;
  ChatSession? _currentSession;
  bool _toolsInitialized = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get isTyping => _isTyping;
  String? get error => _error;
  ChatSession? get currentSession => _currentSession;
  bool get hasMessages => _messages.isNotEmpty;
  String get currentProvider => _chatbotService.currentProviderName;
  String get currentModel => _chatbotService.currentModel;
  bool get isOpenRouterAvailable => _chatbotService.isOpenRouterAvailable;

  ChatProvider() {
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      await _chatbotService.initialize();
      _startNewSession();
      await _logger.log(
        LogLevel.info,
        'ChatProvider',
        'Chat initialized successfully',
      );
    } catch (e) {
      _error = 'Failed to initialize chat: $e';
      await _logger.log(
        LogLevel.error,
        'ChatProvider',
        'Chat initialization failed',
        {'error': e.toString()},
      );
      notifyListeners();
    }
  }

  void initializeTools(InventoryProvider inventoryProvider) {
    if (_toolsInitialized) {
      _logger.log(LogLevel.debug, 'ChatProvider', 'Tools already initialized, skipping...');
      return;
    }
    
    _toolRegistry.registerInventoryTools(inventoryProvider);
    _toolsInitialized = true;
    _logger.log(LogLevel.info, 'ChatProvider', 'Inventory tools registered');

    // Set up tool status update callback
    ToolExecutor.instance.onToolStatusUpdate =
        (toolName, parameters, status, result) {
          _addToolStatusMessage(toolName, parameters, status, result);
        };
  }

  void _addToolStatusMessage(
    String toolName,
    Map<String, dynamic> parameters,
    String status,
    ToolResult? result,
  ) {
    if (status == 'executing') {
      // Add tool call message
      final toolCallMessage = ChatMessage.toolCallMessage(
        toolName: toolName,
        parameters: parameters,
        status: MessageStatus.executing,
      );
      _messages.add(toolCallMessage);
    } else {
      // Find the corresponding tool call message and add result
      for (int i = _messages.length - 1; i >= 0; i--) {
        if (_messages[i].type == MessageType.toolCall &&
            _messages[i].metadata?['toolName'] == toolName &&
            _messages[i].status == MessageStatus.executing) {
          // Update the tool call message status
          _messages[i] = _messages[i].copyWith(
            status: status == 'success'
                ? MessageStatus.success
                : MessageStatus.failed,
          );

          // Add tool result message with the actual result message
          final toolResultMessage = ChatMessage.toolResultMessage(
            toolName: toolName,
            result:
                result?.message ??
                (status == 'success'
                    ? 'Operation completed successfully'
                    : 'Operation failed'),
            success: status == 'success',
            errorMessage: status == 'failed' ? result?.error : null,
          );
          _messages.add(toolResultMessage);
          break;
        }
      }
    }
    notifyListeners();
  }

  void _startNewSession() {
    _currentSession = ChatSession(
      title:
          'Cooking Chat ${DateTime.now().toLocal().toString().split(' ')[0]}',
    );

    _messages = [];

    notifyListeners();
  }

  Future<void> sendMessage(
    String content,
    List<Ingredient> currentInventory,
  ) async {
    if (content.trim().isEmpty) return;

    final userMessage = ChatMessage.userMessage(content.trim());
    _messages.add(userMessage);
    _isTyping = true;
    _error = null;
    notifyListeners();

    try {
      await _logger
          .log(LogLevel.debug, 'ChatProvider', 'Sending user message', {
            'message_length': content.length,
            'inventory_count': currentInventory.length,
          });

      // Check if this looks like a multi-line ingredient list
      String processedContent = content.trim();
      if (_isIngredientList(content)) {
        processedContent = await _processIngredientList(content);
        await _logger.log(
          LogLevel.info,
          'ChatProvider',
          'Detected and processed ingredient list',
        );
      }

      final botResponse = await _chatbotService.sendMessage(
        processedContent,
        currentInventory,
      );

      _messages.add(botResponse);

      // Update session with new messages
      if (_currentSession != null) {
        _currentSession = _currentSession!.copyWith(
          lastUpdated: DateTime.now(),
          messages: _messages,
        );
      }

      await _logger.log(
        LogLevel.info,
        'ChatProvider',
        'Message exchange completed',
        {'total_messages': _messages.length},
      );
    } catch (e) {
      _error = 'Failed to send message: $e';

      // Add error message to chat
      _messages.add(
        ChatMessage.botMessage(
          "I apologize, but I'm having trouble responding right now. Please try again in a moment.",
          metadata: {'error': true},
        ),
      );

      await _logger.log(
        LogLevel.error,
        'ChatProvider',
        'Message sending failed',
        {'error': e.toString()},
      );
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }

  List<String> getQuickReplySuggestions(List<Ingredient> inventory) {
    return _chatbotService.getQuickReplySuggestions(inventory);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearChat() {
    _chatbotService.clearConversation();
    _startNewSession();
    _logger.log(LogLevel.info, 'ChatProvider', 'Chat cleared');
  }

  void retryLastMessage(List<Ingredient> currentInventory) {
    if (_messages.isEmpty) return;

    // Find the last user message
    ChatMessage? lastUserMessage;
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].type == MessageType.user) {
        lastUserMessage = _messages[i];
        break;
      }
    }

    if (lastUserMessage != null) {
      // Remove messages after the last user message
      final lastUserIndex = _messages.indexOf(lastUserMessage);
      _messages = _messages.sublist(0, lastUserIndex + 1);

      // Resend the message
      sendMessage(lastUserMessage.content, currentInventory);
    }
  }

  Future<void> loadSession(ChatSession session) async {
    _currentSession = session;
    _messages = List.from(session.messages);
    _chatbotService.setConversationHistory(_messages);
    notifyListeners();

    await _logger.log(LogLevel.info, 'ChatProvider', 'Session loaded', {
      'session_id': session.id,
      'message_count': session.messages.length,
    });
  }

  void updateMessageStatus(String messageId, MessageStatus status) {
    final messageIndex = _messages.indexWhere((m) => m.id == messageId);
    if (messageIndex != -1) {
      _messages[messageIndex] = _messages[messageIndex].copyWith(
        status: status,
      );
      notifyListeners();
    }
  }

  void markMessagesAsRead() {
    bool hasUnreadBotMessages = false;

    for (int i = 0; i < _messages.length; i++) {
      if (_messages[i].type == MessageType.bot &&
          _messages[i].status != MessageStatus.delivered) {
        _messages[i] = _messages[i].copyWith(status: MessageStatus.delivered);
        hasUnreadBotMessages = true;
      }
    }

    if (hasUnreadBotMessages) {
      notifyListeners();
    }
  }

  // Model switching method
  void switchModel({String? model}) {
    _chatbotService.switchModel(model: model);
    notifyListeners();
  }
  @override
  void dispose() {
    _chatbotService.dispose();
    super.dispose();
  }

  /// Checks if the message appears to be a multi-line ingredient list
  bool _isIngredientList(String content) {
    // Check for multiple lines
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.length < 3) return false;
    
    // Check for category headers (##) or multiple ingredient-like lines
    bool hasCategories = lines.any((line) => line.trim().startsWith('##'));
    
    // Check if most lines look like ingredients (short, no sentences)
    int ingredientLikeLines = 0;
    for (final line in lines) {
      final trimmed = line.trim();
      // Skip headers and separators
      if (trimmed.startsWith('#') || trimmed.startsWith('-') || 
          trimmed.startsWith('=') || trimmed.contains('[*]')) {
        continue;
      }
      // Ingredient-like: short (under 30 chars), no periods (not sentences)
      if (trimmed.length < 30 && !trimmed.contains('.')) {
        ingredientLikeLines++;
      }
    }
    
    // If we have categories or most lines look like ingredients, it's probably a list
    return hasCategories || (ingredientLikeLines >= lines.length * 0.5);
  }

  /// Processes a multi-line ingredient list into a format the AI can handle better
  Future<String> _processIngredientList(String content) async {
    final parser = IngredientListParser.instance;
    final ingredients = parser.parseIngredientList(content);
    
    if (ingredients.isEmpty) {
      // Couldn't parse, return original
      return content;
    }
    
    // Group ingredients by category
    final Map<String, List<String>> categorized = {};
    for (final ingredient in ingredients) {
      categorized.putIfAbsent(ingredient.category, () => []);
      String item = ingredient.name;
      if (ingredient.quantity != 1.0 || ingredient.unit != 'pieces') {
        item = '${ingredient.quantity} ${ingredient.unit} ${ingredient.name}';
      }
      categorized[ingredient.category]!.add(item);
    }
    
    // Build a cleaner message for the AI
    final buffer = StringBuffer();
    buffer.writeln('Please add these ingredients to my inventory:');
    buffer.writeln();
    
    for (final entry in categorized.entries) {
      buffer.writeln('${entry.key}:');
      for (final item in entry.value) {
        buffer.writeln('- $item');
      }
      buffer.writeln();
    }
    
    buffer.writeln('Total: ${ingredients.length} ingredients');
    
    await _logger.log(
      LogLevel.info,
      'ChatProvider',
      'Processed ingredient list',
      {
        'original_length': content.length,
        'ingredient_count': ingredients.length,
        'categories': categorized.keys.toList(),
      },
    );
    
    return buffer.toString();
  }
}
