import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../models/ingredient.dart';
import '../models/ai_tool.dart';
import '../services/chatbot_service.dart';
import '../services/logger_service.dart';
import '../services/tool_registry.dart';
import '../services/tool_executor.dart';
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

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get isTyping => _isTyping;
  String? get error => _error;
  ChatSession? get currentSession => _currentSession;
  bool get hasMessages => _messages.isNotEmpty;

  ChatProvider() {
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      await _chatbotService.initialize();
      _startNewSession();
      await _logger.log(LogLevel.info, 'ChatProvider', 'Chat initialized successfully');
    } catch (e) {
      _error = 'Failed to initialize chat: $e';
      await _logger.log(LogLevel.error, 'ChatProvider', 'Chat initialization failed', {
        'error': e.toString()
      });
      notifyListeners();
    }
  }

  void initializeTools(InventoryProvider inventoryProvider) {
    _toolRegistry.registerInventoryTools(inventoryProvider);
    _logger.log(LogLevel.info, 'ChatProvider', 'Inventory tools registered');
    
    // Set up tool status update callback
    ToolExecutor.instance.onToolStatusUpdate = (toolName, parameters, status) {
      _addToolStatusMessage(toolName, parameters, status);
    };
  }
  
  void _addToolStatusMessage(String toolName, Map<String, dynamic> parameters, String status) {
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
            status: status == 'success' ? MessageStatus.success : MessageStatus.failed,
          );
          
          // Add tool result message
          final toolResultMessage = ChatMessage.toolResultMessage(
            toolName: toolName,
            result: status == 'success' 
              ? 'Operation completed successfully' 
              : 'Operation failed',
            success: status == 'success',
            errorMessage: status == 'failed' ? 'Tool execution failed' : null,
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
      title: 'Cooking Chat ${DateTime.now().toLocal().toString().split(' ')[0]}',
    );
    
    _messages = [
      ChatMessage.botMessage(
        "Hi! I'm your Sous Chef assistant! 👨‍🍳\n\nI can help you with recipes, cooking tips, and meal planning based on your ingredients. What would you like to cook today?",
        metadata: {'welcome_message': true},
      ),
    ];
    
    notifyListeners();
  }

  Future<void> sendMessage(String content, List<Ingredient> currentInventory) async {
    if (content.trim().isEmpty) return;

    final userMessage = ChatMessage.userMessage(content.trim());
    _messages.add(userMessage);
    _isTyping = true;
    _error = null;
    notifyListeners();

    try {
      await _logger.log(LogLevel.debug, 'ChatProvider', 'Sending user message', {
        'message_length': content.length,
        'inventory_count': currentInventory.length,
      });

      final botResponse = await _chatbotService.sendMessage(content.trim(), currentInventory);
      
      _messages.add(botResponse);
      
      // Update session with new messages
      if (_currentSession != null) {
        _currentSession = _currentSession!.copyWith(
          lastUpdated: DateTime.now(),
          messages: _messages,
        );
      }

      await _logger.log(LogLevel.info, 'ChatProvider', 'Message exchange completed', {
        'total_messages': _messages.length,
      });

    } catch (e) {
      _error = 'Failed to send message: $e';
      
      // Add error message to chat
      _messages.add(ChatMessage.botMessage(
        "I apologize, but I'm having trouble responding right now. Please try again in a moment.",
        metadata: {'error': true},
      ));

      await _logger.log(LogLevel.error, 'ChatProvider', 'Message sending failed', {
        'error': e.toString(),
      });
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
      _messages[messageIndex] = _messages[messageIndex].copyWith(status: status);
      notifyListeners();
    }
  }

  void markMessagesAsRead() {
    bool hasUnreadBotMessages = false;
    
    for (int i = 0; i < _messages.length; i++) {
      if (_messages[i].type == MessageType.bot && _messages[i].status != MessageStatus.delivered) {
        _messages[i] = _messages[i].copyWith(status: MessageStatus.delivered);
        hasUnreadBotMessages = true;
      }
    }
    
    if (hasUnreadBotMessages) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _chatbotService.dispose();
    super.dispose();
  }
}