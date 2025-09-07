import 'logger_service.dart';
import '../models/ingredient.dart';
import '../models/ai_tool.dart';
import '../providers/inventory_provider.dart';

class ToolRegistry {
  static final ToolRegistry instance = ToolRegistry._init();
  ToolRegistry._init();

  final Map<String, Map<String, dynamic>> _openAITools = {};
  final Map<String, Function> _executors = {};
  final LoggerService _logger = LoggerService.instance;

  void registerInventoryTools(InventoryProvider inventoryProvider) {
    _logger.log(LogLevel.info, 'ToolRegistry', 'Registering simplified inventory tools');

    // Single add_ingredient tool with batch support (OpenAI native format)
    final addIngredientTool = {
      "type": "function",
      "function": {
        "name": "add_ingredient", 
        "description": "Add one or more ingredients to the user's inventory",
        "parameters": {
          "type": "object",
          "properties": {
            "ingredients": {
              "type": "array",
              "description": "List of ingredients to add",
              "items": {
                "type": "object",
                "properties": {
                  "name": {
                    "type": "string",
                    "description": "Name of the ingredient"
                  },
                  "quantity": {
                    "type": "number", 
                    "description": "Amount of ingredient"
                  },
                  "unit": {
                    "type": "string",
                    "description": "Unit of measurement",
                    "enum": ["g", "kg", "ml", "L", "cups", "tbsp", "tsp", "pieces", "lbs", "oz"]
                  },
                  "category": {
                    "type": "string",
                    "description": "Ingredient category (e.g., Produce, Dairy, Meat, Pantry, Spices, Condiments, Baking Supplies, Beverages, etc.)",
                    "default": "Other"
                  },
                  "emoji": {
                    "type": "string", 
                    "description": "Emoji representing the ingredient (e.g., 🍎 for apple, 🥛 for milk)",
                    "default": "🍽️"
                  },
                  "categoryEmoji": {
                    "type": "string",
                    "description": "Emoji representing the ingredient category (e.g., 🥬 for Produce, 🥛 for Dairy)", 
                    "default": "📦"
                  }
                },
                "required": ["name", "quantity", "unit"]
              },
              "minItems": 1
            }
          },
          "required": ["ingredients"]
        }
      }
    };

    _openAITools['add_ingredient'] = addIngredientTool;
    _executors['add_ingredient'] = (ToolCall toolCall) => _addIngredients(toolCall, inventoryProvider);

    _logger.log(LogLevel.info, 'ToolRegistry', 'Registered ${_openAITools.length} inventory tools');
  }

  Map<String, dynamic>? getTool(String name) {
    return _openAITools[name];
  }

  List<Map<String, dynamic>> getAllTools() {
    return _openAITools.values.toList();
  }

  List<String> getToolNames() {
    return _openAITools.keys.toList();
  }

  List<Map<String, dynamic>> getToolSchemas() {
    return _openAITools.values.toList();
  }

  Future<ToolResult> executeTool(String toolName, ToolCall toolCall) async {
    final executor = _executors[toolName];
    if (executor == null) {
      return ToolResult.error(
        toolCallId: toolCall.id,
        message: 'Tool executor not found: $toolName',
        error: 'Unknown tool',
      );
    }

    _logger.log(LogLevel.info, 'ToolRegistry', 'Executing tool: $toolName', {
      'parameters': toolCall.parameters,
    });

    final result = await executor(toolCall);
    
    _logger.log(LogLevel.info, 'ToolRegistry', 'Tool execution result', {
      'tool': toolName,
      'success': result.success,
      'message': result.message,
    });

    return result;
  }

  // Tool executor - handles both single and batch ingredient addition
  Future<ToolResult> _addIngredients(ToolCall toolCall, InventoryProvider inventoryProvider) async {
    try {
      final params = toolCall.parameters;
      List<Map<String, dynamic>> ingredientsList;
      
      // Handle both new batch format and old single ingredient format for backward compatibility
      if (params.containsKey('ingredients') && params['ingredients'] is List) {
        // New batch format: { "ingredients": [...] }
        ingredientsList = List<Map<String, dynamic>>.from(params['ingredients']);
      } else if (params.containsKey('name') && params.containsKey('quantity') && params.containsKey('unit')) {
        // Old single ingredient format: { "name": "apple", "quantity": 1, "unit": "pieces", ... }
        ingredientsList = [Map<String, dynamic>.from(params)];
      } else {
        return ToolResult.error(
          toolCallId: toolCall.id,
          message: 'Invalid parameters - expected either "ingredients" array or single ingredient fields (name, quantity, unit)',
        );
      }
      final List<Ingredient> ingredientsToAdd = [];
      final List<String> errors = [];

      // Process each ingredient
      for (int i = 0; i < ingredientsList.length; i++) {
        try {
          final ingredientData = ingredientsList[i] as Map<String, dynamic>;
          
          final name = ingredientData['name'] as String;
          final quantity = (ingredientData['quantity'] as num).toDouble();
          final unit = ingredientData['unit'] as String;
          final category = ingredientData['category'] as String? ?? 'Other';
          final emoji = ingredientData['emoji'] as String? ?? '🍽️';
          final categoryEmoji = ingredientData['categoryEmoji'] as String? ?? '📦';

          final ingredient = Ingredient(
            name: name,
            quantity: quantity,
            unit: unit,
            category: category,
            emoji: emoji,
            categoryEmoji: categoryEmoji,
          );

          ingredientsToAdd.add(ingredient);
        } catch (e) {
          errors.add('Ingredient ${i + 1}: $e');
        }
      }

      if (ingredientsToAdd.isEmpty) {
        return ToolResult.error(
          toolCallId: toolCall.id,
          message: 'No valid ingredients to add. Errors: ${errors.join(', ')}',
        );
      }

      // Add all valid ingredients
      int successCount = 0;
      final List<String> addedIngredients = [];

      for (final ingredient in ingredientsToAdd) {
        final success = await inventoryProvider.addIngredient(ingredient);
        if (success) {
          successCount++;
          addedIngredients.add('${ingredient.quantity} ${ingredient.unit} ${ingredient.name}');
        } else {
          errors.add('Failed to add ${ingredient.name}');
        }
      }

      if (successCount > 0) {
        String message;
        if (successCount == 1) {
          message = '✅ Added ${addedIngredients.first} to your inventory!';
        } else {
          // Group ingredients by category for better organization
          final Map<String, List<Ingredient>> byCategory = {};
          for (final ingredient in ingredientsToAdd) {
            byCategory.putIfAbsent(ingredient.category, () => []).add(ingredient);
          }
          
          message = '✅ Added $successCount ingredients to your inventory:\n\n';
          
          for (final category in byCategory.keys) {
            final ingredients = byCategory[category]!;
            final categoryEmoji = ingredients.first.categoryEmoji;
            message += '$categoryEmoji $category (${ingredients.length} ${ingredients.length == 1 ? 'item' : 'items'})\n';
            
            for (final ingredient in ingredients) {
              message += '  • ${ingredient.quantity} ${ingredient.unit} ${ingredient.name}\n';
            }
            message += '\n';
          }
          
          // Remove trailing newline
          message = message.trim();
        }

        if (errors.isNotEmpty) {
          message += '\n\n⚠️ Some items had issues: ${errors.join(', ')}';
        }

        // UI should automatically update via notifyListeners() calls
        
        return ToolResult.success(
          toolCallId: toolCall.id,
          message: message,
          data: {
            'added_count': successCount,
            'total_count': ingredientsList.length,
            'ingredients': ingredientsToAdd.map((i) => i.toMap()).toList(),
          },
        );
      } else {
        return ToolResult.error(
          toolCallId: toolCall.id,
          message: 'Failed to add any ingredients. Errors: ${errors.join(', ')}',
        );
      }
    } catch (e) {
      return ToolResult.error(
        toolCallId: toolCall.id,
        message: 'Error processing ingredients: $e',
        error: e.toString(),
      );
    }
  }
}