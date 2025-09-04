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

      final success = await inventoryProvider.deleteIngredient(ingredient.id!);
      
      if (success) {
        return ToolResult.success(
          toolCallId: toolCall.id,
          message: '✅ Removed $name from your inventory',
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