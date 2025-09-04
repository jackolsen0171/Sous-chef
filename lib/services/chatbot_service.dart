import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/ingredient.dart';
import '../models/chat_message.dart';
import 'logger_service.dart';

class ChatbotService {
  static final ChatbotService instance = ChatbotService._init();
  
  ChatbotService._init();

  GenerativeModel? _model;
  final LoggerService _logger = LoggerService.instance;
  List<ChatMessage> _conversationHistory = [];

  Future<void> initialize() async {
    await _logger.log(LogLevel.info, 'Chatbot', 'Initializing chatbot service...');
    
    try {
      await dotenv.load();
      await _logger.log(LogLevel.debug, 'Chatbot', '.env file loaded successfully');
    } catch (e) {
      await _logger.log(LogLevel.error, 'Chatbot', '.env load failed', {'error': e.toString()});
    }
    
    final apiKey = dotenv.env['GOOGLE_AI_API_KEY'];
    await _logger.log(LogLevel.debug, 'Chatbot', 'API key check', {
      'has_api_key': apiKey != null,
      'api_key_length': apiKey?.length ?? 0,
    });
    
    if (apiKey == null || apiKey.isEmpty || apiKey == 'your_api_key_here') {
      await _logger.log(LogLevel.error, 'Chatbot', 'No valid API key found');
      throw Exception('Google AI API key not found. Please add GOOGLE_AI_API_KEY to your .env file');
    }
    
    await _logger.log(LogLevel.info, 'Chatbot', 'API key loaded successfully');

    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.8,
        topP: 0.9,
        maxOutputTokens: 1024,
      ),
      systemInstruction: Content.text(_getSystemInstruction()),
    );
  }

  String _getSystemInstruction() {
    return '''
You are Sous Chef, a friendly and knowledgeable cooking assistant. Your role is to help users with cooking, recipes, and meal planning based on their available ingredients.

PERSONALITY:
- Friendly, enthusiastic, and helpful
- Use cooking emojis occasionally 
- Be encouraging and supportive
- Ask follow-up questions to better help the user

CAPABILITIES:
- Recipe suggestions based on available ingredients
- Cooking tips and techniques
- Ingredient substitutions
- Meal planning advice
- Dietary restriction accommodations
- Food safety guidance

RESPONSE STYLE:
- Keep responses conversational and helpful
- Use bullet points or numbered lists for recipes/steps
- Mention ingredient availability from their inventory
- Suggest using ingredients that are expiring soon
- Ask clarifying questions when needed

Remember: You have access to the user's current ingredient inventory with quantities, units, and expiry dates. Always consider this context in your responses.
''';
  }

  Future<ChatMessage> sendMessage(String userMessage, List<Ingredient> currentInventory) async {
    if (_model == null) {
      await initialize();
    }

    try {
      await _logger.log(LogLevel.debug, 'Chatbot', 'Sending message', {
        'user_message': userMessage,
        'inventory_count': currentInventory.length,
      });

      final userChatMessage = ChatMessage.userMessage(userMessage);
      _conversationHistory.add(userChatMessage);

      final prompt = _buildConversationalPrompt(userMessage, currentInventory);
      
      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);
      
      if (response.text == null || response.text!.isEmpty) {
        await _logger.log(LogLevel.error, 'Chatbot', 'Empty response from AI');
        throw Exception('No response from AI model');
      }

      final botMessage = ChatMessage.botMessage(
        response.text!,
        metadata: {
          'inventory_used': currentInventory.map((i) => i.name).toList(),
          'response_time': DateTime.now().toIso8601String(),
        },
      );
      
      _conversationHistory.add(botMessage);
      
      await _logger.log(LogLevel.info, 'Chatbot', 'Successfully generated response', {
        'response_length': response.text!.length,
        'conversation_length': _conversationHistory.length,
      });

      return botMessage;
      
    } catch (e) {
      await _logger.log(LogLevel.error, 'Chatbot', 'Failed to generate response', {
        'error': e.toString(),
      });
      
      return ChatMessage.botMessage(
        "I'm sorry, I'm having trouble responding right now. Please try again in a moment. 😊",
        metadata: {'error': true, 'error_message': e.toString()},
      );
    }
  }

  String _buildConversationalPrompt(String userMessage, List<Ingredient> inventory) {
    final inventoryContext = _buildInventoryContext(inventory);
    final conversationContext = _buildConversationContext();
    
    return '''
$inventoryContext

$conversationContext

USER MESSAGE: $userMessage

Please respond as Sous Chef, keeping the conversation natural and helpful. Consider the user's inventory when making suggestions.
''';
  }

  String _buildInventoryContext(List<Ingredient> inventory) {
    if (inventory.isEmpty) {
      return "CURRENT INVENTORY: Empty - User needs to add ingredients";
    }

    final expiringIngredients = <String>[];
    final regularIngredients = <String>[];
    
    final now = DateTime.now();
    
    for (final ingredient in inventory) {
      final expiryInfo = ingredient.expiryDate != null 
          ? ingredient.expiryDate!.difference(now).inDays
          : null;
      
      final ingredientStr = '${ingredient.name}: ${ingredient.quantity}${ingredient.unit}';
      
      if (expiryInfo != null && expiryInfo <= 3) {
        expiringIngredients.add('$ingredientStr (expires in $expiryInfo days) ⚠️');
      } else {
        regularIngredients.add(ingredientStr);
      }
    }

    final inventoryText = StringBuffer("CURRENT INVENTORY:\n");
    
    if (expiringIngredients.isNotEmpty) {
      inventoryText.writeln("EXPIRING SOON:");
      for (final ingredient in expiringIngredients) {
        inventoryText.writeln("- $ingredient");
      }
      inventoryText.writeln();
    }
    
    if (regularIngredients.isNotEmpty) {
      inventoryText.writeln("AVAILABLE:");
      for (final ingredient in regularIngredients) {
        inventoryText.writeln("- $ingredient");
      }
    }

    return inventoryText.toString();
  }

  String _buildConversationContext() {
    if (_conversationHistory.length <= 2) {
      return ""; // No conversation history needed for first exchange
    }

    final recentHistory = _conversationHistory
        .where((msg) => msg.type != MessageType.system)
        .take(6) // Last 3 exchanges (6 messages)
        .toList();

    if (recentHistory.isEmpty) return "";

    final contextBuffer = StringBuffer("RECENT CONVERSATION:\n");
    for (final message in recentHistory) {
      final speaker = message.type == MessageType.user ? "USER" : "ASSISTANT";
      contextBuffer.writeln("$speaker: ${message.content}");
    }

    return contextBuffer.toString();
  }

  List<String> getQuickReplySuggestions(List<Ingredient> inventory) {
    final suggestions = <String>[];
    
    if (inventory.isEmpty) {
      return [
        "Help me plan meals",
        "What should I buy?",
        "Cooking tips"
      ];
    }
    
    // Check for expiring ingredients
    final now = DateTime.now();
    final expiring = inventory.where((i) => 
      i.expiryDate != null && 
      i.expiryDate!.difference(now).inDays <= 3
    ).toList();
    
    if (expiring.isNotEmpty) {
      suggestions.add("What can I make with ${expiring.first.name}?");
    }
    
    // Add general suggestions
    suggestions.addAll([
      "What can I cook for dinner?",
      "Quick meal ideas",
      "Healthy recipes",
    ]);
    
    return suggestions.take(3).toList();
  }

  void clearConversation() {
    _conversationHistory.clear();
    _logger.log(LogLevel.info, 'Chatbot', 'Conversation history cleared');
  }

  List<ChatMessage> get conversationHistory => List.unmodifiable(_conversationHistory);

  void setConversationHistory(List<ChatMessage> history) {
    _conversationHistory = List.from(history);
  }

  void dispose() {
    _conversationHistory.clear();
  }
}