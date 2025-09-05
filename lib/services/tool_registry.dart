import 'dart:convert';

import '../models/ai_tool.dart';
import '../models/ingredient.dart';
import '../providers/inventory_provider.dart';
import 'logger_service.dart';

class ToolRegistry {
  static final ToolRegistry instance = ToolRegistry._init();
  ToolRegistry._init();

  final Map<String, AITool> _tools = {};
  final LoggerService _logger = LoggerService.instance;

  void registerInventoryTools(InventoryProvider inventoryProvider) {
    _logger.log(LogLevel.info, 'ToolRegistry', 'Registering inventory management tools');

    // Add ingredient tool
    registerTool(AITool(
      name: 'add_ingredient',
      description: 'Add a new ingredient to the user\'s inventory',
      category: 'inventory',
      parameters: {
        'name': ParameterSchema(
          name: 'name',
          type: ParameterType.string,
          description: 'Name of the ingredient',
          required: true,
        ),
        'quantity': ParameterSchema(
          name: 'quantity',
          type: ParameterType.number,
          description: 'Quantity of the ingredient',
          required: true,
        ),
        'unit': ParameterSchema(
          name: 'unit',
          type: ParameterType.string,
          description: 'Unit of measurement',
          required: true,
          allowedValues: IngredientUnit.all,
        ),
        'category': ParameterSchema(
          name: 'category',
          type: ParameterType.string,
          description: 'Category of the ingredient',
          required: false,
          defaultValue: IngredientCategory.other,
          allowedValues: IngredientCategory.all,
        ),
        'expiry_date': ParameterSchema(
          name: 'expiry_date',
          type: ParameterType.date,
          description: 'Expiry date in ISO format (optional)',
          required: false,
        ),
      },
      executor: (toolCall) => _addIngredient(toolCall, inventoryProvider),
    ));

    // Add multiple ingredients at once
    registerTool(AITool(
      name: 'add_ingredients_batch',
      description: 'Add multiple ingredients to inventory at once',
      category: 'inventory',
      parameters: {
        'ingredients': ParameterSchema(
          name: 'ingredients',
          type: ParameterType.string,
          description: 'JSON array of ingredients with name, quantity, unit, category (optional), and expiry_date (optional)',
          required: true,
        ),
      },
      executor: (toolCall) => _addIngredientsBatch(toolCall, inventoryProvider),
    ));

    // Update ingredient quantity tool
    registerTool(AITool(
      name: 'update_ingredient_quantity',
      description: 'Update the quantity of an existing ingredient',
      category: 'inventory',
      parameters: {
        'name': ParameterSchema(
          name: 'name',
          type: ParameterType.string,
          description: 'Name of the ingredient to update',
          required: true,
        ),
        'quantity': ParameterSchema(
          name: 'quantity',
          type: ParameterType.number,
          description: 'New quantity',
          required: true,
        ),
      },
      executor: (toolCall) => _updateIngredientQuantity(toolCall, inventoryProvider),
    ));

    // Delete ingredient tool
    registerTool(AITool(
      name: 'delete_ingredient',
      description: 'Remove an ingredient from the inventory',
      category: 'inventory',
      requiresConfirmation: true,
      parameters: {
        'name': ParameterSchema(
          name: 'name',
          type: ParameterType.string,
          description: 'Name of the ingredient to delete',
          required: true,
        ),
      },
      executor: (toolCall) => _deleteIngredient(toolCall, inventoryProvider),
    ));

    // Search ingredients tool
    registerTool(AITool(
      name: 'search_ingredients',
      description: 'Search for ingredients in the inventory',
      category: 'inventory',
      parameters: {
        'query': ParameterSchema(
          name: 'query',
          type: ParameterType.string,
          description: 'Search term to find ingredients',
          required: true,
        ),
      },
      executor: (toolCall) => _searchIngredients(toolCall, inventoryProvider),
    ));

    // List ingredients tool
    registerTool(AITool(
      name: 'list_ingredients',
      description: 'List ingredients, optionally filtered by category or expiring soon',
      category: 'inventory',
      parameters: {
        'category': ParameterSchema(
          name: 'category',
          type: ParameterType.string,
          description: 'Filter by category (optional)',
          required: false,
          allowedValues: IngredientCategory.all,
        ),
        'expiring_only': ParameterSchema(
          name: 'expiring_only',
          type: ParameterType.boolean,
          description: 'Show only ingredients expiring within 3 days',
          required: false,
          defaultValue: false,
        ),
      },
      executor: (toolCall) => _listIngredients(toolCall, inventoryProvider),
    ));

    _logger.log(LogLevel.info, 'ToolRegistry', 'Registered ${_tools.length} inventory tools');
  }

  void registerTool(AITool tool) {
    _tools[tool.name] = tool;
    _logger.log(LogLevel.debug, 'ToolRegistry', 'Registered tool: ${tool.name}');
  }

  AITool? getTool(String name) {
    return _tools[name];
  }

  List<AITool> getAllTools() {
    return _tools.values.toList();
  }

  List<AITool> getToolsByCategory(String category) {
    return _tools.values.where((tool) => tool.category == category).toList();
  }

  List<Map<String, dynamic>> getToolSchemas() {
    return _tools.values.map((tool) => tool.getSchema()).toList();
  }

  Future<ToolResult> executeTool(String toolName, ToolCall toolCall) async {
    final tool = _tools[toolName];
    if (tool == null) {
      return ToolResult.error(
        toolCallId: toolCall.id,
        message: 'Tool not found: $toolName',
        error: 'Unknown tool',
      );
    }

    _logger.log(LogLevel.info, 'ToolRegistry', 'Executing tool: $toolName', {
      'parameters': toolCall.parameters,
    });

    final result = await tool.execute(toolCall);
    
    _logger.log(LogLevel.info, 'ToolRegistry', 'Tool execution result', {
      'tool': toolName,
      'success': result.success,
      'message': result.message,
    });

    return result;
  }

  // Tool executors
  Future<ToolResult> _addIngredient(ToolCall toolCall, InventoryProvider inventoryProvider) async {
    try {
      final params = toolCall.parameters;
      final name = params['name'] as String;
      final quantity = (params['quantity'] as num).toDouble();
      final unit = params['unit'] as String;
      final category = params['category'] as String? ?? IngredientCategory.other;
      final expiryDateStr = params['expiry_date'] as String?;

      DateTime? expiryDate;
      if (expiryDateStr != null) {
        expiryDate = DateTime.tryParse(expiryDateStr);
        if (expiryDate == null) {
          return ToolResult.error(
            toolCallId: toolCall.id,
            message: 'Invalid expiry date format. Use ISO format (YYYY-MM-DD)',
          );
        }
      }

      final ingredient = Ingredient(
        name: name,
        quantity: quantity,
        unit: unit,
        category: category,
        expiryDate: expiryDate,
      );

      final success = await inventoryProvider.addIngredient(ingredient);
      
      if (success) {
        return ToolResult.success(
          toolCallId: toolCall.id,
          message: '✅ Added $quantity $unit of $name to your inventory!',
          data: {'ingredient': ingredient.toMap()},
        );
      } else {
        return ToolResult.error(
          toolCallId: toolCall.id,
          message: 'Failed to add ingredient to inventory',
          error: inventoryProvider.error,
        );
      }
    } catch (e) {
      return ToolResult.error(
        toolCallId: toolCall.id,
        message: 'Error adding ingredient: $e',
        error: e.toString(),
      );
    }
  }

  Future<ToolResult> _addIngredientsBatch(ToolCall toolCall, InventoryProvider inventoryProvider) async {
    try {
      final params = toolCall.parameters;
      final ingredientsParam = params['ingredients'];
      
      // Parse JSON string to List
      late List<dynamic> ingredientsList;
      try {
        if (ingredientsParam is String) {
          // Parse JSON string
          final decoded = jsonDecode(ingredientsParam);
          if (decoded is List) {
            ingredientsList = decoded;
          } else if (decoded is Map) {
            // Single ingredient passed as object
            ingredientsList = [decoded];
          } else {
            throw FormatException('Invalid format');
          }
        } else if (ingredientsParam is List) {
          // Already a list
          ingredientsList = ingredientsParam;
        } else {
          throw FormatException('Ingredients must be a JSON string or list');
        }
      } catch (e) {
        return ToolResult.error(
          toolCallId: toolCall.id,
          message: 'Invalid JSON format for ingredients. Expected JSON array of ingredient objects.',
          error: 'JSON parsing failed: $e',
        );
      }

      // Process each ingredient
      final results = <Map<String, dynamic>>[];
      int successCount = 0;
      int failCount = 0;

      for (final ingredientData in ingredientsList) {
        try {
          final ingredientMap = Map<String, dynamic>.from(ingredientData);
          
          // Extract and parse ingredient data
          String name = ingredientMap['name']?.toString() ?? '';
          double quantity = _parseQuantity(ingredientMap['quantity']);
          String unit = ingredientMap['unit']?.toString() ?? 'pieces';
          String category = ingredientMap['category']?.toString() ?? _inferCategory(name);
          String? expiryDateStr = ingredientMap['expiry_date']?.toString();

          // Validate required fields
          if (name.isEmpty) {
            results.add({
              'name': 'Unknown',
              'success': false,
              'message': 'Missing ingredient name',
            });
            failCount++;
            continue;
          }

          // Parse expiry date
          DateTime? expiryDate;
          if (expiryDateStr != null && expiryDateStr.isNotEmpty) {
            expiryDate = DateTime.tryParse(expiryDateStr);
          }

          // Create ingredient
          final ingredient = Ingredient(
            name: name,
            quantity: quantity,
            unit: unit,
            category: category,
            expiryDate: expiryDate,
          );

          // Add to inventory
          final success = await inventoryProvider.addIngredient(ingredient);
          
          if (success) {
            results.add({
              'name': name,
              'success': true,
              'message': 'Added $quantity $unit of $name',
            });
            successCount++;
          } else {
            results.add({
              'name': name,
              'success': false,
              'message': inventoryProvider.error ?? 'Failed to add',
            });
            failCount++;
          }
        } catch (e) {
          results.add({
            'name': ingredientData['name'] ?? 'Unknown',
            'success': false,
            'message': 'Error: $e',
          });
          failCount++;
        }
      }

      // Build summary message
      String message = '';
      if (successCount > 0 && failCount == 0) {
        message = '✅ Successfully added $successCount ingredient${successCount > 1 ? 's' : ''} to inventory!';
      } else if (successCount > 0 && failCount > 0) {
        message = '⚠️ Added $successCount ingredient${successCount > 1 ? 's' : ''}, $failCount failed.';
      } else {
        message = '❌ Failed to add ingredients to inventory.';
      }

      // Add details for each result
      if (results.isNotEmpty) {
        message += '\n\nDetails:';
        for (final result in results) {
          final icon = result['success'] ? '✅' : '❌';
          message += '\n$icon ${result['name']}: ${result['message']}';
        }
      }

      return ToolResult(
        toolCallId: toolCall.id,
        success: successCount > 0,
        message: message,
        data: {
          'results': results,
          'summary': {
            'total': ingredientsList.length,
            'succeeded': successCount,
            'failed': failCount,
          },
        },
      );
    } catch (e) {
      return ToolResult.error(
        toolCallId: toolCall.id,
        message: 'Error processing batch ingredients: $e',
        error: e.toString(),
      );
    }
  }

  double _parseQuantity(dynamic value) {
    if (value == null) return 1.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
      // Handle cases like "some" or empty
      return 1.0;
    }
    return 1.0;
  }

  String _inferCategory(String name) {
    final nameLower = name.toLowerCase();
    
    // Meat & Seafood
    if (RegExp(r'\b(chicken|beef|pork|lamb|turkey|bacon|ham|sausage|meat|steak|fish|salmon|tuna|shrimp|seafood)\b')
        .hasMatch(nameLower)) {
      return IngredientCategory.meat;
    }
    
    // Dairy
    if (RegExp(r'\b(milk|cheese|yogurt|butter|cream|dairy|egg)\b')
        .hasMatch(nameLower)) {
      return IngredientCategory.dairy;
    }
    
    // Produce
    if (RegExp(r'\b(apple|banana|orange|lemon|lime|grape|berry|fruit|vegetable|carrot|potato|onion|tomato|lettuce|spinach|broccoli|pepper|cucumber|celery)\b')
        .hasMatch(nameLower)) {
      return IngredientCategory.produce;
    }
    
    // Spices
    if (RegExp(r'\b(salt|pepper|spice|herb|garlic|ginger|cinnamon|cumin|paprika|oregano|basil|thyme|rosemary)\b')
        .hasMatch(nameLower)) {
      return IngredientCategory.spices;
    }
    
    // Pantry
    if (RegExp(r'\b(rice|pasta|flour|sugar|oil|vinegar|sauce|can|jar|bread|cereal|oat|bean|lentil)\b')
        .hasMatch(nameLower)) {
      return IngredientCategory.pantry;
    }
    
    return IngredientCategory.other;
  }

  Future<ToolResult> _updateIngredientQuantity(ToolCall toolCall, InventoryProvider inventoryProvider) async {
    try {
      final params = toolCall.parameters;
      final name = params['name'] as String;
      final newQuantity = (params['quantity'] as num).toDouble();

      // Find ingredient by name
      final ingredient = inventoryProvider.ingredients
          .where((i) => i.name.toLowerCase() == name.toLowerCase())
          .firstOrNull;

      if (ingredient == null) {
        return ToolResult.error(
          toolCallId: toolCall.id,
          message: 'Ingredient "$name" not found in inventory',
        );
      }

      final success = await inventoryProvider.updateQuantity(ingredient.id!, newQuantity);
      
      if (success) {
        return ToolResult.success(
          toolCallId: toolCall.id,
          message: '✅ Updated $name quantity to $newQuantity ${ingredient.unit}',
          data: {'ingredient_id': ingredient.id, 'new_quantity': newQuantity},
        );
      } else {
        return ToolResult.error(
          toolCallId: toolCall.id,
          message: 'Failed to update ingredient quantity',
          error: inventoryProvider.error,
        );
      }
    } catch (e) {
      return ToolResult.error(
        toolCallId: toolCall.id,
        message: 'Error updating ingredient: $e',
        error: e.toString(),
      );
    }
  }

  Future<ToolResult> _deleteIngredient(ToolCall toolCall, InventoryProvider inventoryProvider) async {
    try {
      final params = toolCall.parameters;
      final name = params['name'] as String;

      // Clean the input name (remove common phrases)
      final cleanedName = _cleanDeleteInputName(name);

      // Find ingredient by exact name first
      Ingredient? ingredient = inventoryProvider.ingredients
          .where((i) => i.name.toLowerCase() == cleanedName.toLowerCase())
          .firstOrNull;

      // If not found, try fuzzy matching
      if (ingredient == null) {
        ingredient = _findBestMatchingIngredient(cleanedName, inventoryProvider.ingredients);
      }

      if (ingredient == null) {
        // Show available ingredients
        final availableIngredients = inventoryProvider.ingredients
            .map((i) => i.name)
            .toList();
        
        if (availableIngredients.isEmpty) {
          return ToolResult.error(
            toolCallId: toolCall.id,
            message: 'No ingredients found in inventory to delete',
          );
        }

        return ToolResult.error(
          toolCallId: toolCall.id,
          message: 'Ingredient "$cleanedName" not found in inventory.\n\nAvailable ingredients:\n${availableIngredients.map((name) => '• $name').join('\n')}',
        );
      }

      final success = await inventoryProvider.deleteIngredient(ingredient.id!);
      
      if (success) {
        return ToolResult.success(
          toolCallId: toolCall.id,
          message: '✅ Removed "${ingredient.name}" from your inventory',
          data: {'deleted_ingredient': ingredient.toMap()},
        );
      } else {
        return ToolResult.error(
          toolCallId: toolCall.id,
          message: 'Failed to delete ingredient',
          error: inventoryProvider.error,
        );
      }
    } catch (e) {
      return ToolResult.error(
        toolCallId: toolCall.id,
        message: 'Error deleting ingredient: $e',
        error: e.toString(),
      );
    }
  }

  String _cleanDeleteInputName(String input) {
    // Remove common phrases that shouldn't be part of ingredient names
    String cleaned = input.toLowerCase();
    
    final phrasesToRemove = [
      r'\bfrom your inventory\b',
      r'\bfrom inventory\b', 
      r'\bfrom my inventory\b',
      r'\bfrom the inventory\b',
      r'\bin inventory\b',
      r'\bin my inventory\b',
      r'\bin your inventory\b',
      r'\ball\s+',
      r'\bthe\s+',
      r'\bmy\s+',
      r'\byour\s+',
    ];
    
    for (final phrase in phrasesToRemove) {
      cleaned = cleaned.replaceAll(RegExp(phrase), '');
    }
    
    return cleaned.trim();
  }

  Ingredient? _findBestMatchingIngredient(String searchName, List<Ingredient> ingredients) {
    if (ingredients.isEmpty) return null;
    
    final searchLower = searchName.toLowerCase();
    
    // Try partial matches
    for (final ingredient in ingredients) {
      final ingredientLower = ingredient.name.toLowerCase();
      
      // Check if search term is contained in ingredient name
      if (ingredientLower.contains(searchLower)) {
        return ingredient;
      }
      
      // Check if ingredient name is contained in search term
      if (searchLower.contains(ingredientLower)) {
        return ingredient;
      }
    }
    
    // Try word-by-word matching
    final searchWords = searchLower.split(' ');
    for (final ingredient in ingredients) {
      final ingredientWords = ingredient.name.toLowerCase().split(' ');
      
      // Check if any search word matches any ingredient word
      for (final searchWord in searchWords) {
        if (searchWord.length > 2) { // Only consider meaningful words
          for (final ingredientWord in ingredientWords) {
            if (searchWord == ingredientWord || 
                searchWord.contains(ingredientWord) || 
                ingredientWord.contains(searchWord)) {
              return ingredient;
            }
          }
        }
      }
    }
    
    return null;
  }

  Future<ToolResult> _searchIngredients(ToolCall toolCall, InventoryProvider inventoryProvider) async {
    try {
      final params = toolCall.parameters;
      final query = params['query'] as String;

      await inventoryProvider.searchIngredients(query);
      final results = inventoryProvider.ingredients;
      
      if (results.isEmpty) {
        return ToolResult.success(
          toolCallId: toolCall.id,
          message: 'No ingredients found matching "$query"',
          data: {'results': []},
        );
      }

      final resultStrings = results.map((i) => 
        '${i.name}: ${i.quantity}${i.unit}').toList();
      
      return ToolResult.success(
        toolCallId: toolCall.id,
        message: 'Found ${results.length} ingredient(s) matching "$query":\n${resultStrings.join('\n')}',
        data: {'results': results.map((i) => i.toMap()).toList()},
      );
    } catch (e) {
      return ToolResult.error(
        toolCallId: toolCall.id,
        message: 'Error searching ingredients: $e',
        error: e.toString(),
      );
    }
  }

  Future<ToolResult> _listIngredients(ToolCall toolCall, InventoryProvider inventoryProvider) async {
    try {
      final params = toolCall.parameters;
      final category = params['category'] as String?;
      final expiringOnly = params['expiring_only'] as bool? ?? false;

      List<Ingredient> ingredients;

      if (category != null) {
        await inventoryProvider.filterByCategory(category);
        ingredients = inventoryProvider.ingredients;
      } else {
        ingredients = inventoryProvider.ingredients;
      }

      if (expiringOnly) {
        final now = DateTime.now();
        ingredients = ingredients.where((i) {
          if (i.expiryDate == null) return false;
          final daysUntilExpiry = i.expiryDate!.difference(now).inDays;
          return daysUntilExpiry <= 3 && daysUntilExpiry >= 0;
        }).toList();
      }

      if (ingredients.isEmpty) {
        String message = 'No ingredients found';
        if (category != null) message += ' in category "$category"';
        if (expiringOnly) message += ' expiring soon';
        
        return ToolResult.success(
          toolCallId: toolCall.id,
          message: message,
          data: {'results': []},
        );
      }

      final resultStrings = ingredients.map((i) {
        String result = '${i.name}: ${i.quantity}${i.unit}';
        if (i.expiryDate != null) {
          final daysUntilExpiry = i.expiryDate!.difference(DateTime.now()).inDays;
          if (daysUntilExpiry <= 3) {
            result += ' (expires in $daysUntilExpiry days)';
          }
        }
        return result;
      }).toList();

      String message = 'Your inventory';
      if (category != null) message += ' ($category)';
      if (expiringOnly) message += ' (expiring soon)';
      message += ':\n${resultStrings.join('\n')}';

      return ToolResult.success(
        toolCallId: toolCall.id,
        message: message,
        data: {'results': ingredients.map((i) => i.toMap()).toList()},
      );
    } catch (e) {
      return ToolResult.error(
        toolCallId: toolCall.id,
        message: 'Error listing ingredients: $e',
        error: e.toString(),
      );
    }
  }
}