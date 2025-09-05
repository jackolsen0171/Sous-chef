import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/ingredient.dart';
import '../models/chat_message.dart';
import '../models/ai_tool.dart';
import 'logger_service.dart';
import 'tool_registry.dart';
import 'tool_executor.dart';

class ChatbotService {
  static final ChatbotService instance = ChatbotService._init();

  ChatbotService._init();

  GenerativeModel? _model;
  final LoggerService _logger = LoggerService.instance;
  final ToolRegistry _toolRegistry = ToolRegistry.instance;
  final ToolExecutor _toolExecutor = ToolExecutor.instance;
  List<ChatMessage> _conversationHistory = [];

  Future<void> initialize() async {
    await _logger.log(
      LogLevel.info,
      'Chatbot',
      'Initializing chatbot service...',
    );

    try {
      await dotenv.load();
      await _logger.log(
        LogLevel.debug,
        'Chatbot',
        '.env file loaded successfully',
      );
    } catch (e) {
      await _logger.log(LogLevel.error, 'Chatbot', '.env load failed', {
        'error': e.toString(),
      });
    }

    final apiKey = dotenv.env['GOOGLE_AI_API_KEY'];
    await _logger.log(LogLevel.debug, 'Chatbot', 'API key check', {
      'has_api_key': apiKey != null,
      'api_key_length': apiKey?.length ?? 0,
    });

    if (apiKey == null || apiKey.isEmpty || apiKey == 'your_api_key_here') {
      await _logger.log(LogLevel.error, 'Chatbot', 'No valid API key found');
      throw Exception(
        'Google AI API key not found. Please add GOOGLE_AI_API_KEY to your .env file',
      );
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
    final toolSchemas = _toolRegistry.getToolSchemas();
    final toolDescriptions = toolSchemas
        .map((schema) => '- ${schema['name']}: ${schema['description']}')
        .join('\n');

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
- Inventory management through tools

INVENTORY MANAGEMENT TOOLS:
You have access to these tools to help manage the user's ingredient inventory:
$toolDescriptions

IMPORTANT BATCH TOOL USAGE:
- When the user mentions multiple ingredients they want added to their inventory, you MUST use the add_ingredients_batch tool
- add_ingredients_batch is specifically designed to add multiple ingredients at once efficiently
- Never call add_ingredient multiple times in a row - always use add_ingredients_batch for 2+ items
- Examples that MUST use add_ingredients_batch:
  * "Add apples, bananas, and oranges"
  * "I bought 1 apple, 1 banana, 3 oranges"
  * "Put chicken and bacon in my inventory"
  * Any request with 2 or more ingredients

VALID UNITS AND CATEGORIES:
When adding ingredients, you MUST use only these valid units:
- Weight: g, kg, lbs, oz
- Volume: ml, L, cups, tbsp, tsp
- Count: pieces

Valid categories are:
- Produce (fruits, vegetables)
- Dairy (milk, cheese, eggs, yogurt)
- Meat (all proteins including bacon, chicken, beef, fish)
- Pantry (grains, canned goods, dry ingredients)
- Spices (seasonings, herbs, salt, pepper)
- Other (anything that doesn't fit above categories)

INGREDIENT DEFAULTS - IMPORTANT:
When users ask to add ingredients without specifying quantity/details, ALWAYS use sensible defaults and add them immediately. DO NOT ask for clarification - just add with reasonable defaults:

- Eggs: 12 pieces (standard dozen), category "Dairy" 
- Bacon: 1 lbs, category "Meat"
- Milk: 1 L, category "Dairy"
- Bread: 1 pieces (loaf), category "Pantry"
- Butter: 250 g, category "Dairy"
- Produce items: 3-5 pieces for fruits/vegetables, appropriate category
- Spices/seasonings: 1 tsp, category "Spices"
- Dry goods (rice, pasta): 500 g, category "Pantry"
- Liquids (oil, vinegar): 500 ml, appropriate category

NEVER ask "how many" or "what size" - just add with defaults. Users can always ask you to update quantities later.

NEVER use units like "package", "pack", "container", "jar" - these are not valid units in our system.

TOOL USAGE - IMPORTANT:
- When users ask to add, remove, update, or list ingredients, you MUST use the appropriate tools IMMEDIATELY
- CRITICAL RULE: If adding 2 or more ingredients, ALWAYS use add_ingredients_batch, NEVER use add_ingredient multiple times
- ALWAYS use tools for inventory management - never just describe what you would do
- When adding ingredients, use defaults if details aren't specified - DON'T ask for clarification
- You can use tools in two ways:

METHOD 1 - JSON FORMAT (PREFERRED):
When you want to use a tool, include a JSON block in your response:

For multiple ingredients (ALWAYS USE THIS FOR 2+ ITEMS):
```json
{
  "tool_calls": [
    {
      "function": {
        "name": "add_ingredients_batch",
        "arguments": {
          "ingredients": "[{\\"name\\":\\"chicken\\",\\"quantity\\":1,\\"unit\\":\\"pieces\\",\\"category\\":\\"Meat\\"},{\\"name\\":\\"apples\\",\\"quantity\\":3,\\"unit\\":\\"pieces\\",\\"category\\":\\"Produce\\"},{\\"name\\":\\"bacon\\",\\"quantity\\":200,\\"unit\\":\\"g\\",\\"category\\":\\"Meat\\"}]"
        }
      }
    }
  ]
}
```

For single ingredient ONLY (use only when adding exactly 1 item):
```json
{
  "tool_calls": [
    {
      "function": {
        "name": "add_ingredient",
        "arguments": {
          "name": "tomatoes",
          "quantity": 3,
          "unit": "pieces",
          "category": "Produce"
        }
      }
    }
  ]
}
```

IMPORTANT - INGREDIENT NAMES:
- Use ONLY the ingredient name (e.g., "apples", "milk", "rice")
- Do NOT include phrases like "to your inventory", "in the pantry", etc.
- Keep names simple and clean (e.g., "apples" not "apples to your inventory")

BATCH VS SINGLE ADDITIONS - CRITICAL:
- MUST use add_ingredients_batch when users mention 2 or more items
- Use add_ingredient ONLY for single items
- ALWAYS use batch for lists like "1 apple, 1 banana, 3 oranges" 
- ALWAYS use batch for "X and Y" or "X, Y, and Z" patterns
- If user says "add apple, banana, and oranges" you MUST use add_ingredients_batch
- DO NOT call add_ingredient multiple times - use batch instead!

METHOD 2 - NATURAL LANGUAGE:
Be explicit about tool usage with clear action statements like:
  * "I'll add 5 eggs to your inventory now."
  * "Let me add 2 cups of rice to your pantry."
  * "I'm removing the expired milk from your inventory."
  * "I'll add all those items to your inventory - chicken, apples, and bacon."

CRITICAL: When using JSON format, the JSON should be processed internally and NOT shown to the user. Always provide a friendly, conversational response to the user while the tools work in the background.

RESPONSE GUIDELINES:
- NEVER show JSON code blocks to the user
- Always respond conversationally (e.g., "I've added 5 apples to your inventory! 🍎")
- The JSON is for internal processing only
- Keep responses natural and helpful

- Example user requests that REQUIRE tool usage:
  * "Add some tomatoes" → Use add_ingredient tool (single item)
  * "I need milk" → Use add_ingredient tool (single item)
  * "Can you add 3 apples?" → Use add_ingredient tool (single item)
  * "Put eggs in my inventory" → Use add_ingredient tool (single item)
  * "Add 1 apple, 1 banana, 3 oranges" → Use add_ingredients_batch tool (multiple items!)
  * "I bought chicken, 3 apples, and bacon" → Use add_ingredients_batch tool (multiple items!)
  * "Add milk, eggs, and bread to my inventory" → Use add_ingredients_batch tool (multiple items!)
  * "I went shopping and got tomatoes, lettuce, and cheese" → Use add_ingredients_batch tool (multiple items!)
  * "Add apple and banana" → Use add_ingredients_batch tool (2 items = use batch!)
- Always confirm successful tool actions with a friendly message
- For destructive actions (like deleting ingredients), the system will handle confirmation

RESPONSE STYLE:
- Keep responses conversational and helpful
- Use bullet points or numbered lists for recipes/steps
- Mention ingredient availability from their inventory
- Suggest using ingredients that are expiring soon
- Ask clarifying questions when needed
- When using tools, explain what you're doing in friendly terms

Remember: You have access to the user's current ingredient inventory with quantities, units, and expiry dates. Always consider this context in your responses. When users mention adding, removing, or managing ingredients, use the available tools to help them.
''';
  }

  Future<ChatMessage> sendMessage(
    String userMessage,
    List<Ingredient> currentInventory,
  ) async {
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

      // Check for tool calls in the response
      final toolCalls = _toolExecutor.parseToolCallsFromResponse(
        response.text!,
      );
      String finalResponse = response.text!;
      final toolResults = <ToolResult>[];

      if (toolCalls.isNotEmpty) {
        await _logger.log(
          LogLevel.info,
          'Chatbot',
          'Found ${toolCalls.length} tool calls in response',
        );

        // Execute tool calls
        final results = await _toolExecutor.executeToolCalls(toolCalls);
        toolResults.addAll(results);

        // Build enhanced response with tool results
        finalResponse = _buildResponseWithToolResults(
          response.text!,
          toolResults,
        );
      }

      final botMessage = ChatMessage.botMessage(
        finalResponse,
        metadata: {
          'inventory_used': currentInventory.map((i) => i.name).toList(),
          'response_time': DateTime.now().toIso8601String(),
          'tool_calls': toolCalls.map((tc) => tc.toJson()).toList(),
          'tool_results': toolResults.map((tr) => tr.toJson()).toList(),
        },
      );

      _conversationHistory.add(botMessage);

      await _logger
          .log(LogLevel.info, 'Chatbot', 'Successfully generated response', {
            'response_length': finalResponse.length,
            'conversation_length': _conversationHistory.length,
            'tool_calls_executed': toolCalls.length,
          });

      return botMessage;
    } catch (e) {
      await _logger.log(
        LogLevel.error,
        'Chatbot',
        'Failed to generate response',
        {'error': e.toString()},
      );

      return ChatMessage.botMessage(
        "I'm sorry, I'm having trouble responding right now. Please try again in a moment. 😊",
        metadata: {'error': true, 'error_message': e.toString()},
      );
    }
  }

  String _buildResponseWithToolResults(
    String originalResponse,
    List<ToolResult> toolResults,
  ) {
    if (toolResults.isEmpty) return originalResponse;

    final failedResults = toolResults.where((r) => !r.success).toList();

    final responseBuffer = StringBuffer();

    // Only add failed tool results to the response - successes are shown in the tool UI
    if (failedResults.isNotEmpty) {
      responseBuffer.writeln("I encountered some issues:");
      for (final result in failedResults) {
        responseBuffer.writeln("• ${result.message}");
      }
      responseBuffer.writeln();
    }

    // Add the original AI response, but clean it up if it contains tool-specific language
    String cleanedResponse = originalResponse;

    // Remove JSON blocks from user-facing response
    cleanedResponse = cleanedResponse.replaceAll(
      RegExp(r'```json\s*\{[\s\S]*?\}\s*```', multiLine: true),
      '',
    );

    // Remove standalone JSON objects
    cleanedResponse = cleanedResponse.replaceAll(
      RegExp(r'\{[^{}]*"tool_calls?"[^{}]*\}'),
      '',
    );

    // Remove common tool-related phrases that might confuse users
    final toolPhrases = [
      r"I'll (add|remove|update|delete)",
      r"Let me (add|remove|update|delete)",
      r"Adding.*to.*inventory",
      r"Removing.*from.*inventory",
      r"I'm (adding|removing|updating|deleting)",
    ];

    for (final phrase in toolPhrases) {
      cleanedResponse = cleanedResponse.replaceAll(
        RegExp(phrase, caseSensitive: false),
        '',
      );
    }

    // Clean up extra whitespace
    cleanedResponse = cleanedResponse
        .replaceAll(RegExp(r'\n\s*\n'), '\n')
        .trim();

    if (cleanedResponse.isNotEmpty) {
      responseBuffer.write(cleanedResponse);
    }

    return responseBuffer.toString().trim();
  }

  String _buildConversationalPrompt(
    String userMessage,
    List<Ingredient> inventory,
  ) {
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

      final ingredientStr =
          '${ingredient.name}: ${ingredient.quantity}${ingredient.unit}';

      if (expiryInfo != null && expiryInfo <= 3) {
        expiringIngredients.add(
          '$ingredientStr (expires in $expiryInfo days) ⚠️',
        );
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
      return ["Help me plan meals", "What should I buy?", "Cooking tips"];
    }

    // Check for expiring ingredients
    final now = DateTime.now();
    final expiring = inventory
        .where(
          (i) =>
              i.expiryDate != null && i.expiryDate!.difference(now).inDays <= 3,
        )
        .toList();

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

  List<ChatMessage> get conversationHistory =>
      List.unmodifiable(_conversationHistory);

  void setConversationHistory(List<ChatMessage> history) {
    _conversationHistory = List.from(history);
  }

  void dispose() {
    _conversationHistory.clear();
  }
}
