import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/ingredient.dart';
import '../models/chat_message.dart';
import '../models/ai_tool.dart';
import 'logger_service.dart';
import 'tool_registry.dart';
import 'tool_executor.dart';
import 'openrouter_service.dart';

class ChatbotService {
  static final ChatbotService instance = ChatbotService._init();

  ChatbotService._init();

  final LoggerService _logger = LoggerService.instance;
  final ToolRegistry _toolRegistry = ToolRegistry.instance;
  final ToolExecutor _toolExecutor = ToolExecutor.instance;
  final OpenRouterService _openRouterService = OpenRouterService();

  String get currentProviderName => 'openRouter';
  String get currentModel => _openRouterService.currentModel;
  bool get isOpenRouterAvailable => _openRouterService.isInitialized;
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

    await _logger.log(
      LogLevel.info,
      'Chatbot',
      'Chatbot service initialized - using OpenRouter for all models',
      {
        'openrouter_available': _openRouterService.isInitialized,
        'current_model': _openRouterService.currentModel,
      },
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

RESPONSE FORMATTING:
- ALWAYS format your responses using markdown for better readability
- Use headers (##, ###) to organize sections
- Use bullet points (-, *) for lists
- Use **bold** for emphasis on important points
- Use code blocks for recipes or structured data
- Make responses scannable and easy to read

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

INGREDIENT LIST PROCESSING - CRITICAL:
- When user provides ANY list of ingredients (regardless of format), you MUST process the ENTIRE list
- Be intelligent and flexible - handle any format the user provides:
  * Bullet points, numbered lists, comma-separated, line-by-line
  * With or without categories, headers, emojis, sections
  * Mixed formats, nested lists, informal text
  * Copy-pasted from recipes, shopping lists, or any source
- ALWAYS process everything - scan the entire message for all ingredients
- Extract and infer intelligent information:
  * Parse quantities from context (e.g., "2 cans of tomatoes" → 2 pieces)
  * Infer logical categories based on ingredient type
  * Handle abbreviations and variations (tsp, tablespoon, tbsp are all tablespoons)
  * Default to sensible quantities if not specified
- If the list has 100+ items, process in batches but COMPLETE ALL items
- Never ask for clarification - make intelligent assumptions and add everything

VALID UNITS AND CATEGORIES:
When adding ingredients, you MUST use only these valid units:
- Weight: g, kg, lbs, oz
- Volume: ml, L, cups, tbsp, tsp
- Count: pieces

You can create any category that makes sense for organizing ingredients. Be thoughtful and specific with categories. Examples:

COMMON CATEGORIES:
- Produce (fruits, vegetables, fresh herbs)
- Dairy (milk, cheese, eggs, yogurt, butter, cream)
- Meat (chicken, beef, pork, fish, seafood)
- Pantry (grains, pasta, rice, flour, dry goods)
- Spices (seasonings, dried herbs, salt, pepper, spice blends)
- Condiments (ketchup, mustard, hot sauce, BBQ sauce)
- Sauces (soy sauce, worcestershire, oyster sauce, tomato sauce)
- Oils (olive oil, sesame oil, vegetable oil)
- Vinegars (balsamic, white wine, rice vinegar)
- Beverages (juices, sodas, wine, coffee, tea)
- Baking (baking powder, vanilla, chocolate chips)
- Frozen (frozen vegetables, ice cream, frozen meals)
- Snacks (chips, crackers, nuts)

CATEGORY ASSIGNMENT RULES:
- Be specific and logical with categorization
- Create granular categories when it makes sense (separate "Oils" from "Vinegars" rather than lumping into "Pantry")
- When users provide structured lists with categories, follow their organization exactly
- Fresh herbs go in "Produce", dried herbs/spices go in "Spices"
- Group similar items together (all vinegars in "Vinegars", all oils in "Oils")

EMOJI ASSIGNMENT - IMPORTANT:
You MUST include appropriate emojis for both ingredients and categories:
- Choose the most fitting emoji for each ingredient (🍎 for apple, 🥛 for milk, 🌶️ for chili, etc.)
- Choose emojis for categories that represent the group (🥬 for Produce, 🥛 for Dairy, etc.)
- Be creative and match emojis to the actual items (🧄 for garlic, 🥓 for bacon, 🍯 for honey)
- For custom categories, choose appropriate emojis (🥤 for Beverages, 🍿 for Snacks)
- If unsure, use related food emojis rather than generic ones

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
          "ingredients": "[{\\"name\\":\\"chicken\\",\\"quantity\\":1,\\"unit\\":\\"pieces\\",\\"category\\":\\"Meat\\",\\"emoji\\":\\"🍗\\",\\"categoryEmoji\\":\\"🥩\\"},{\\"name\\":\\"apples\\",\\"quantity\\":3,\\"unit\\":\\"pieces\\",\\"category\\":\\"Produce\\",\\"emoji\\":\\"🍎\\",\\"categoryEmoji\\":\\"🥬\\"},{\\"name\\":\\"bacon\\",\\"quantity\\":200,\\"unit\\":\\"g\\",\\"category\\":\\"Meat\\",\\"emoji\\":\\"🥓\\",\\"categoryEmoji\\":\\"🥩\\"}]"
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
          "category": "Produce",
          "emoji": "🍅",
          "categoryEmoji": "🥬"
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

  // Model switching method

  void switchModel({String? model}) {
    if (model != null) {
      _openRouterService.setModel(model);
      _logger.log(
        LogLevel.info,
        'Chatbot',
        'Switched to model: $model',
        {'model_id': _openRouterService.currentModel},
      );
    }
  }

  Future<ChatMessage> sendMessage(
    String userMessage,
    List<Ingredient> currentInventory,
  ) async {
    if (!_openRouterService.isInitialized) {
      await _logger.log(
        LogLevel.error,
        'Chatbot',
        'OpenRouter service not available - API key missing',
      );
      return ChatMessage.botMessage(
        'Sorry, I need an OpenRouter API key to work. Please add OPENROUTER_API_KEY to your .env file.',
        metadata: {'error': true},
      );
    }
    
    return _sendMessageViaOpenRouter(userMessage, currentInventory);
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
    bool showSuggestions = false;
    if (showSuggestions) {
      suggestions.addAll([
        "What can I cook for dinner?",
        "Quick meal ideas",
        "Healthy recipes",
      ]);
    }

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

  Future<ChatMessage> _sendMessageViaOpenRouter(
    String userMessage,
    List<Ingredient> currentInventory,
  ) async {
    try {
      final userChatMessage = ChatMessage.userMessage(userMessage);
      _conversationHistory.add(userChatMessage);

      // Get tools in native OpenAI format (no conversion needed!)
      List<Map<String, dynamic>> tools = [];
      try {
        tools = _toolRegistry.getAllTools();
        await _logger.log(LogLevel.debug, 'Chatbot', 'Tools loaded successfully', {
          'tool_count': tools.length,
        });
      } catch (e) {
        await _logger.log(LogLevel.error, 'Chatbot', 'Error loading tools: $e');
        tools = []; // Continue without tools if there's an error
      }

      // Build prompt with error handling
      String prompt;
      try {
        prompt = _buildConversationalPrompt(userMessage, currentInventory);
        await _logger.log(LogLevel.debug, 'Chatbot', 'Prompt built successfully', {
          'prompt_length': prompt.length,
        });
      } catch (e) {
        await _logger.log(LogLevel.error, 'Chatbot', 'Error building prompt: $e');
        throw Exception('Failed to build conversation prompt: $e');
      }

      // Get system instruction with error handling
      String systemInstruction;
      try {
        systemInstruction = _getSystemInstruction();
        await _logger.log(LogLevel.debug, 'Chatbot', 'System instruction built successfully', {
          'instruction_length': systemInstruction.length,
        });
      } catch (e) {
        await _logger.log(LogLevel.error, 'Chatbot', 'Error building system instruction: $e');
        systemInstruction = 'You are Sous Chef, a helpful cooking assistant.'; // Fallback
      }

      await _logger.log(LogLevel.debug, 'Chatbot', 'About to call OpenRouter', {
        'system_prompt_type': systemInstruction.runtimeType.toString(),
        'user_message_type': prompt.runtimeType.toString(),
        'tools_count': tools.length,
      });

      final response = await _openRouterService.sendMessage(
        systemPrompt: systemInstruction,
        userMessage: prompt,
        tools: tools,
        maxTokens: 2048,
      );

      if (!response["success"]) {
        throw Exception(response["error"] ?? "Unknown OpenRouter error");
      }

      final toolCalls = <ToolCall>[];
      if (response["tool_calls"] != null && response["tool_calls"] is List) {
        for (final toolCall in response["tool_calls"]) {
          try {
            final function = toolCall["function"];
            if (function == null) continue;
            
            Map<String, dynamic> arguments = {};
            
            if (function["arguments"] != null) {
              if (function["arguments"] is String) {
                try {
                  arguments = jsonDecode(function["arguments"]);
                } catch (e) {
                  await _logger.log(
                    LogLevel.warning, 
                    'Chatbot', 
                    'Failed to decode tool arguments as JSON: $e',
                    {'raw_arguments': function["arguments"]}
                  );
                  continue;
                }
              } else if (function["arguments"] is Map) {
                arguments = Map<String, dynamic>.from(function["arguments"]);
              }
            }

            final toolName = function["name"];
            if (toolName != null && toolName is String) {
              toolCalls.add(
                ToolCall(toolName: toolName, parameters: arguments),
              );
            }
          } catch (e) {
            await _logger.log(
              LogLevel.warning, 
              'Chatbot', 
              'Error parsing tool call: $e',
              {'tool_call': toolCall.toString()}
            );
          }
        }
      }

      final toolResults = await _toolExecutor.executeToolCalls(toolCalls);
      
      // Ensure response content is a string
      String responseContent = "";
      if (response["content"] != null) {
        if (response["content"] is String) {
          responseContent = response["content"];
        } else if (response["content"] is List) {
          // Handle case where content might be a list
          responseContent = response["content"].join(" ");
        } else {
          responseContent = response["content"].toString();
        }
      }
      
      final finalResponse = _buildResponseWithToolResults(
        responseContent,
        toolResults,
      );

      final botMessage = ChatMessage.botMessage(
        finalResponse,
        metadata: {
          "provider": "openRouter",
          "model": _openRouterService.currentModel,
          "tool_calls": toolCalls.map((tc) {
            try {
              return tc.toJson();
            } catch (e) {
              _logger.log(
                LogLevel.warning,
                'Chatbot',
                'Error serializing tool call: $e',
              );
              return {'error': 'serialization_failed'};
            }
          }).toList(),
          "response_tokens": response["usage"]?["total_tokens"],
        },
      );

      _conversationHistory.add(botMessage);
      return botMessage;
    } catch (e) {
      await _logger.log(LogLevel.error, "Chatbot", "OpenRouter error: $e");
      return ChatMessage.botMessage(
        "Sorry, I'm having trouble connecting to the AI service right now. Please try again in a moment.",
        metadata: {'error': true, 'error_message': e.toString()},
      );
    }
  }

  void dispose() {
    _conversationHistory.clear();
  }
}
