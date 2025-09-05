import '../services/chatbot_service.dart';
import '../models/ingredient.dart';
import 'logger_service.dart';

class DebugChatbot {
  static Future<void> testToolParsing() async {
    final chatbot = ChatbotService.instance;
    final logger = LoggerService.instance;
    
    await chatbot.initialize();
    
    // Test messages that should trigger tools
    final testMessages = [
      "Add 2 cups of rice to my inventory",
      "Show me what ingredients I have",
      "Remove expired milk",
      "Update chicken quantity to 1 pound",
    ];
    
    for (final message in testMessages) {
      await logger.log(LogLevel.info, 'DebugChatbot', 'Testing message: $message');
      
      try {
        final response = await chatbot.sendMessage(message, <Ingredient>[]);
        
        await logger.log(LogLevel.info, 'DebugChatbot', 'AI Response:', {
          'message': message,
          'response': response.content,
          'metadata': response.metadata.toString(),
        });
        
        // Check if any tool calls were detected
        final toolCalls = response.metadata?['tool_calls'] as List? ?? [];
        final toolResults = response.metadata?['tool_results'] as List? ?? [];
        
        await logger.log(LogLevel.info, 'DebugChatbot', 'Tool Analysis:', {
          'tool_calls_found': toolCalls.length,
          'tool_results': toolResults.length,
          'tool_calls': toolCalls.toString(),
        });
        
      } catch (e) {
        await logger.log(LogLevel.error, 'DebugChatbot', 'Error testing message', {
          'message': message,
          'error': e.toString(),
        });
      }
      
      // Wait between requests
      await Future.delayed(const Duration(seconds: 2));
    }
  }
}