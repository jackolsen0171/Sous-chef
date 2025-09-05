import 'dart:convert';
import '../models/ai_tool.dart';
import 'tool_registry.dart';
import 'logger_service.dart';

class ToolExecutor {
  static final ToolExecutor instance = ToolExecutor._init();
  ToolExecutor._init();

  final ToolRegistry _toolRegistry = ToolRegistry.instance;
  final LoggerService _logger = LoggerService.instance;

  // Callback for tool execution status updates
  Function(String toolName, Map<String, dynamic> parameters, String status, ToolResult? result)?
  onToolStatusUpdate;

  Future<List<ToolResult>> executeToolCalls(List<ToolCall> toolCalls) async {
    final results = <ToolResult>[];

    for (final toolCall in toolCalls) {
      final result = await _executeToolCall(toolCall);
      results.add(result);
    }

    return results;
  }

  Future<ToolResult> _executeToolCall(ToolCall toolCall) async {
    await _logger.log(LogLevel.info, 'ToolExecutor', 'Executing tool call', {
      'tool': toolCall.toolName,
      'parameters': toolCall.parameters,
    });

    // Notify about tool execution starting
    onToolStatusUpdate?.call(
      toolCall.toolName,
      toolCall.parameters,
      'executing',
      null,
    );

    try {
      final result = await _toolRegistry.executeTool(
        toolCall.toolName,
        toolCall,
      );

      await _logger
          .log(LogLevel.info, 'ToolExecutor', 'Tool execution completed', {
            'tool': toolCall.toolName,
            'success': result.success,
            'message': result.message,
          });

      // Notify about tool execution result
      onToolStatusUpdate?.call(
        toolCall.toolName,
        toolCall.parameters,
        result.success ? 'success' : 'failed',
        result,
      );

      return result;
    } catch (e) {
      await _logger.log(
        LogLevel.error,
        'ToolExecutor',
        'Tool execution failed',
        {'tool': toolCall.toolName, 'error': e.toString()},
      );

      // Notify about tool execution failure
      final errorResult = ToolResult.error(
        toolCallId: toolCall.id,
        message: 'Failed to execute ${toolCall.toolName}: $e',
        error: e.toString(),
      );
      
      onToolStatusUpdate?.call(
        toolCall.toolName,
        toolCall.parameters,
        'failed',
        errorResult,
      );

      return ToolResult.error(
        toolCallId: toolCall.id,
        message: 'Failed to execute ${toolCall.toolName}: $e',
        error: e.toString(),
      );
    }
  }

  List<ToolCall> parseToolCallsFromResponse(String aiResponse) {
    final toolCalls = <ToolCall>[];

    try {
      _logger.log(
        LogLevel.debug,
        'ToolExecutor',
        'Parsing AI response for tool calls',
        {
          'response_preview': aiResponse.substring(
            0,
            aiResponse.length > 300 ? 300 : aiResponse.length,
          ),
          'response_length': aiResponse.length,
          'full_response': aiResponse, // Log full response for debugging
        },
      );

      // Check if response seems incomplete (ends mid-word or mid-sentence)
      if (_isIncompleteResponse(aiResponse)) {
        _logger.log(
          LogLevel.warning,
          'ToolExecutor',
          'Response appears incomplete, skipping natural language parsing',
        );
        // Still try JSON parsing as it's more structured
        final jsonBlocks = _extractJsonBlocks(aiResponse);
        for (final jsonBlock in jsonBlocks) {
          final parsed = _tryParseToolCall(jsonBlock);
          if (parsed != null) {
            toolCalls.add(parsed);
          }
        }
        return toolCalls;
      }

      // Look for JSON blocks that might contain tool calls
      final jsonBlocks = _extractJsonBlocks(aiResponse);
      _logger.log(
        LogLevel.debug,
        'ToolExecutor',
        'Found ${jsonBlocks.length} JSON blocks',
      );

      for (final jsonBlock in jsonBlocks) {
        final parsed = _tryParseToolCall(jsonBlock);
        if (parsed != null) {
          toolCalls.add(parsed);
          _logger.log(
            LogLevel.info,
            'ToolExecutor',
            'Parsed JSON tool call: ${parsed.toolName}',
          );
        }
      }

      // Only try natural language parsing if no JSON tool calls were found
      if (toolCalls.isEmpty) {
        final naturalLanguageCalls = _parseNaturalLanguageToolCalls(aiResponse);
        toolCalls.addAll(naturalLanguageCalls);

        if (naturalLanguageCalls.isNotEmpty) {
          _logger.log(
            LogLevel.info,
            'ToolExecutor',
            'Parsed ${naturalLanguageCalls.length} natural language tool calls',
            {'tools': naturalLanguageCalls.map((tc) => tc.toolName).toList()},
          );
        }
      } else {
        _logger.log(
          LogLevel.debug,
          'ToolExecutor',
          'Skipping natural language parsing - JSON tool calls found',
        );
      }
    } catch (e) {
      _logger
          .log(LogLevel.error, 'ToolExecutor', 'Failed to parse tool calls', {
            'error': e.toString(),
            'response': aiResponse.substring(
              0,
              aiResponse.length > 200 ? 200 : aiResponse.length,
            ),
          });
    }

    _logger.log(
      LogLevel.debug,
      'ToolExecutor',
      'Total parsed ${toolCalls.length} tool calls from response',
    );

    // Log each tool call for debugging
    for (final toolCall in toolCalls) {
      _logger.log(LogLevel.info, 'ToolExecutor', 'Tool call parsed', {
        'tool': toolCall.toolName,
        'parameters': toolCall.parameters,
      });
    }

    return toolCalls;
  }

  bool _isIncompleteResponse(String response) {
    if (response.isEmpty) return true;

    final trimmed = response.trim();
    if (trimmed.isEmpty) return true;

    // Only mark as incomplete if it's very obviously incomplete
    final obviouslyIncompletePatterns = [
      r'\s[a-z]$', // Ends with single lowercase letter after space
      r'\sm$', // Common incomplete word "m" for "my"
      r'\syour?$', // Incomplete "your"
      r'\sthe$', // Incomplete "the"
      r'\sand$', // Incomplete "and"
      r'\s(I|We|You|The|A|An)$', // Incomplete sentence starters
    ];

    // Check for obviously incomplete patterns
    for (final pattern in obviouslyIncompletePatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(trimmed)) {
        _logger.log(
          LogLevel.debug,
          'ToolExecutor',
          'Response marked incomplete due to pattern: $pattern',
        );
        return true;
      }
    }

    // If response is very short (under 10 chars) and doesn't end with punctuation
    if (trimmed.length < 10 && !RegExp(r'[.!?]$').hasMatch(trimmed)) {
      _logger.log(
        LogLevel.debug,
        'ToolExecutor',
        'Response marked incomplete - too short without punctuation',
      );
      return true;
    }

    _logger.log(LogLevel.debug, 'ToolExecutor', 'Response considered complete');
    return false;
  }

  List<String> _extractJsonBlocks(String text) {
    final jsonBlocks = <String>[];
    final regex = RegExp(r'```json\s*(\{[\s\S]*?\})\s*```', multiLine: true);
    final matches = regex.allMatches(text);

    for (final match in matches) {
      if (match.group(1) != null) {
        jsonBlocks.add(match.group(1)!);
      }
    }

    // Also look for standalone JSON objects
    final standaloneRegex = RegExp(r'\{[^{}]*"tool_calls?"[^{}]*\}');
    final standaloneMatches = standaloneRegex.allMatches(text);

    for (final match in standaloneMatches) {
      jsonBlocks.add(match.group(0)!);
    }

    return jsonBlocks;
  }

  ToolCall? _tryParseToolCall(String jsonString) {
    try {
      final json = jsonDecode(jsonString);

      // Handle different JSON formats
      if (json is Map<String, dynamic>) {
        // Direct tool call format
        if (json.containsKey('tool_name') ||
            json.containsKey('function_name')) {
          final toolName = json['tool_name'] ?? json['function_name'];
          final parameters =
              json['parameters'] ?? json['arguments'] ?? <String, dynamic>{};

          return ToolCall(
            toolName: toolName,
            parameters: Map<String, dynamic>.from(parameters),
          );
        }

        // Tool calls array format
        if (json.containsKey('tool_calls')) {
          final toolCalls = json['tool_calls'] as List?;
          if (toolCalls != null && toolCalls.isNotEmpty) {
            final firstCall = toolCalls.first;
            if (firstCall is Map<String, dynamic>) {
              final function = firstCall['function'] ?? firstCall;
              final toolName = function['name'];
              final parameters = function['arguments'];

              if (toolName != null) {
                return ToolCall(
                  toolName: toolName,
                  parameters: parameters is String
                      ? jsonDecode(parameters)
                      : Map<String, dynamic>.from(parameters ?? {}),
                );
              }
            }
          }
        }
      }
    } catch (e) {
      _logger.log(
        LogLevel.debug,
        'ToolExecutor',
        'Failed to parse JSON as tool call: $e',
      );
    }

    return null;
  }

  List<ToolCall> _parseNaturalLanguageToolCalls(String response) {
    final toolCalls = <ToolCall>[];
    final availableTools = _toolRegistry.getAllTools();

    _logger.log(
      LogLevel.debug,
      'ToolExecutor',
      'Parsing natural language from response',
      {
        'response_excerpt': response.length > 200
            ? '${response.substring(0, 200)}...'
            : response,
      },
    );

    // Look for patterns like "I'll add [ingredient] to your inventory"
    for (final tool in availableTools) {
      final calls = _parseToolFromNaturalLanguage(response, tool);
      if (calls.isNotEmpty) {
        _logger.log(
          LogLevel.debug,
          'ToolExecutor',
          'Found ${calls.length} calls for ${tool.name}',
        );
        for (final call in calls) {
          _logger.log(LogLevel.debug, 'ToolExecutor', 'Tool call details', {
            'tool': call.toolName,
            'parameters': call.parameters,
          });
        }
      }
      toolCalls.addAll(calls);
    }

    // Remove duplicate calls (same tool with same parameters)
    final uniqueToolCalls = <ToolCall>[];
    for (final toolCall in toolCalls) {
      final isDuplicate = uniqueToolCalls.any(
        (existing) =>
            existing.toolName == toolCall.toolName &&
            _parametersEqual(existing.parameters, toolCall.parameters),
      );
      if (!isDuplicate) {
        uniqueToolCalls.add(toolCall);
      } else {
        _logger.log(
          LogLevel.warning,
          'ToolExecutor',
          'Removed duplicate tool call',
          {'tool': toolCall.toolName, 'parameters': toolCall.parameters},
        );
      }
    }

    return uniqueToolCalls;
  }

  bool _parametersEqual(
    Map<String, dynamic> params1,
    Map<String, dynamic> params2,
  ) {
    if (params1.length != params2.length) return false;

    for (final key in params1.keys) {
      if (!params2.containsKey(key)) return false;

      // Compare values with type consideration
      final val1 = params1[key];
      final val2 = params2[key];

      if (val1 is num && val2 is num) {
        if (val1.toDouble() != val2.toDouble()) return false;
      } else if (val1 != val2) {
        return false;
      }
    }
    return true;
  }

  List<ToolCall> _parseToolFromNaturalLanguage(String response, AITool tool) {
    final toolCalls = <ToolCall>[];

    switch (tool.name) {
      case 'add_ingredient':
        toolCalls.addAll(_parseAddIngredientFromText(response));
        break;
      case 'add_ingredients_batch':
        toolCalls.addAll(_parseAddIngredientsBatchFromText(response));
        break;
      case 'delete_ingredient':
        toolCalls.addAll(_parseDeleteIngredientFromText(response));
        break;
      case 'update_ingredient_quantity':
        toolCalls.addAll(_parseUpdateQuantityFromText(response));
        break;
      case 'list_ingredients':
        toolCalls.addAll(_parseListIngredientsFromText(response));
        break;
    }

    return toolCalls;
  }

  List<ToolCall> _parseAddIngredientFromText(String text) {
    final toolCalls = <ToolCall>[];

    _logger.log(
      LogLevel.debug,
      'ToolExecutor',
      'Parsing add ingredient from text',
      {
        'text': text.length > 100 ? '${text.substring(0, 100)}...' : text,
        'full_text': text, // Log full text for debugging
      },
    );

    // More flexible patterns for adding ingredients

    // Pattern 1: "add [quantity] [unit] [ingredient]" or "add [quantity] [unit] of [ingredient]"
    final pattern1 = RegExp(
      r"(?:add|adding)\s+(\d+(?:\.\d+)?)\s*([a-z]{1,10})\s+(?:of\s+)?([a-zA-Z]{2,}(?:\s+[a-zA-Z]{2,})*)",
      caseSensitive: false,
    );

    // Pattern 2: "add [quantity] [ingredient]" with optional size adjective
    final pattern2 = RegExp(
      r"(?:add|adding)\s+(\d+(?:\.\d+)?)\s+(?:large|medium|small\s+)?([a-zA-Z]{2,}(?:\s+[a-zA-Z]{2,})*)",
      caseSensitive: false,
    );

    // Pattern 3: "I'll add [ingredient] to inventory" - more flexible
    final pattern3 = RegExp(
      r"(?:I'll add|I will add|let me add|adding)\s+(?:some\s+)?(?:(\d+(?:\.\d+)?)\s+)?([a-zA-Z]{2,}(?:\s+[a-zA-Z]{2,})*?)(?:\s+to\s+(?:your\s+|the\s+)?inventory)?",
      caseSensitive: false,
    );

    // Pattern 4: Simple "add [ingredient]"
    final pattern4 = RegExp(
      r"(?:add|put)\s+(?:some\s+)?([a-zA-Z]{2,}(?:\s+[a-zA-Z]{2,})*?)(?:\s+(?:to|in)\s+(?:inventory|pantry|fridge))?",
      caseSensitive: false,
    );

    // Pattern 5: "I need [ingredient]" or "can you add [ingredient]"
    final pattern5 = RegExp(
      r"(?:I need|can you add|please add)\s+(?:some\s+)?(?:(\d+(?:\.\d+)?)\s+)?([a-zA-Z]{2,}(?:\s+[a-zA-Z]{2,})*)",
      caseSensitive: false,
    );

    final patterns = [
      {'pattern': pattern1, 'hasUnit': true},
      {'pattern': pattern2, 'hasUnit': false},
      {'pattern': pattern3, 'hasUnit': false},
      {'pattern': pattern4, 'hasUnit': false},
      {'pattern': pattern5, 'hasUnit': false},
    ];

    for (final patternInfo in patterns) {
      final pattern = patternInfo['pattern'] as RegExp;
      final hasUnit = patternInfo['hasUnit'] as bool;

      final matches = pattern.allMatches(text);
      for (final match in matches) {
        double? quantity;
        String? unit;
        String? name;

        if (hasUnit && match.groupCount >= 3) {
          // Pattern with explicit unit
          quantity = double.tryParse(match.group(1) ?? '');
          unit = match.group(2)?.toLowerCase();
          name = match.group(3)?.trim().toLowerCase();

          final mappedUnit = _mapUnit(unit ?? '');
          if (mappedUnit == null) continue;
          unit = mappedUnit;
        } else {
          // Pattern without explicit unit - infer from context
          quantity = double.tryParse(match.group(1) ?? '') ?? 1.0;
          name = match.group(2)?.trim().toLowerCase();
          unit = _inferDefaultUnit(name ?? '') ?? 'pieces';
        }

        // Validate ingredient name before adding
        if (name != null &&
            name.length > 1 &&
            !_isSuspiciousIngredientName(name) &&
            unit != null) {
          // Clean up ingredient name (remove common descriptors)
          name = _cleanIngredientName(name);

          // Additional validation after cleaning
          if (name.length > 1 && !_isSuspiciousIngredientName(name)) {
            final category = _inferCategory(name);

            _logger.log(
              LogLevel.debug,
              'ToolExecutor',
              'Creating add ingredient tool call',
              {
                'original_name': match.group(2)?.trim().toLowerCase(),
                'cleaned_name': name,
                'quantity': quantity,
                'unit': unit,
                'category': category,
              },
            );

            toolCalls.add(
              ToolCall(
                toolName: 'add_ingredient',
                parameters: {
                  'name': name,
                  'quantity': quantity,
                  'unit': unit,
                  'category': category,
                },
              ),
            );
          }
        }
      }
    }

    return toolCalls;
  }

  List<ToolCall> _parseAddIngredientsBatchFromText(String text) {
    final toolCalls = <ToolCall>[];

    _logger.log(
      LogLevel.debug,
      'ToolExecutor',
      'Parsing batch add ingredients from text',
      {
        'text': text.length > 100 ? '${text.substring(0, 100)}...' : text,
      },
    );

    // Patterns for detecting multiple ingredients in a list
    // Pattern 1: "I bought X, Y, and Z"
    final boughtPattern = RegExp(
      r"(?:bought|purchased|got|have)\s+(?:some\s+)?(.+?)(?:\.|$)",
      caseSensitive: false,
    );
    
    // Pattern 2: "Add X, Y, and Z to inventory" or just "add X, Y, and Z"
    final addListPattern = RegExp(
      r"(?:add|adding|I'll add|I will add|let me add)\s+(.+?)(?:\s+to\s+(?:your\s+|my\s+)?inventory|$)",
      caseSensitive: false,
    );

    // Pattern 3: List with "and" or commas - more flexible
    final listPattern = RegExp(
      r"(?:ingredients?:|items?:|list:)?\s*(.+(?:,|\sand\s).+)",
      caseSensitive: false,
    );
    
    // Pattern 4: AI response patterns like "I've added X, Y, and Z"
    final addedPattern = RegExp(
      r"(?:I've added|added|I'll add|adding)\s+(.+(?:,|\sand\s).+?)\s+(?:to|in)?",
      caseSensitive: false,
    );

    String? itemsList;
    
    // Try to extract the list of items
    for (final pattern in [boughtPattern, addListPattern, listPattern, addedPattern]) {
      final match = pattern.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        itemsList = match.group(1);
        if (itemsList != null && itemsList.contains(',') || itemsList!.contains(' and ')) {
          break;
        }
      }
    }

    if (itemsList == null || (!itemsList.contains(',') && !itemsList.contains(' and '))) {
      return toolCalls; // No batch pattern found
    }

    _logger.log(
      LogLevel.debug,
      'ToolExecutor',
      'Found potential batch list',
      {'list': itemsList},
    );

    // Parse the list into individual ingredients
    final ingredients = <Map<String, dynamic>>[];
    
    // Split by commas and "and"
    final items = itemsList
        .split(RegExp(r',|\sand\s'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    for (final item in items) {
      // Parse each item for quantity and name
      // Pattern: "[quantity] [unit] [name]" or "[quantity] [name]" or just "[name]"
      final quantityPattern = RegExp(
        r"^(?:(\d+(?:\.\d+)?)\s*)?(?:([a-z]{1,10})\s+)?(.+)$",
        caseSensitive: false,
      );
      
      final match = quantityPattern.firstMatch(item);
      if (match != null) {
        final quantityStr = match.group(1);
        final unitStr = match.group(2);
        String? name = match.group(3)?.trim();
        
        // Clean and validate name
        if (name != null && name.length > 1) {
          name = _cleanIngredientName(name);
          
          if (!_isSuspiciousIngredientName(name)) {
            double quantity = 1.0;
            String unit = 'pieces';
            
            // Parse quantity
            if (quantityStr != null) {
              quantity = double.tryParse(quantityStr) ?? 1.0;
            }
            
            // Parse or infer unit
            if (unitStr != null) {
              final mappedUnit = _mapUnit(unitStr);
              if (mappedUnit != null) {
                unit = mappedUnit;
              }
            } else {
              // Check if quantity is in the name (e.g., "3 apples")
              final nameQuantityPattern = RegExp(r"^(\d+)\s+(.+)$");
              final nameMatch = nameQuantityPattern.firstMatch(name);
              if (nameMatch != null) {
                quantity = double.tryParse(nameMatch.group(1) ?? '1') ?? 1.0;
                name = nameMatch.group(2) ?? name;
              }
              unit = _inferDefaultUnit(name) ?? 'pieces';
            }
            
            // Infer category
            final category = _inferCategory(name);
            
            ingredients.add({
              'name': name,
              'quantity': quantity,
              'unit': unit,
              'category': category,
            });
            
            _logger.log(
              LogLevel.debug,
              'ToolExecutor',
              'Parsed batch ingredient',
              {
                'name': name,
                'quantity': quantity,
                'unit': unit,
                'category': category,
              },
            );
          }
        }
      }
    }

    // If we found multiple valid ingredients, create a batch tool call
    if (ingredients.length >= 2) {
      _logger.log(
        LogLevel.info,
        'ToolExecutor',
        'Creating batch add tool call for ${ingredients.length} ingredients',
      );
      
      toolCalls.add(
        ToolCall(
          toolName: 'add_ingredients_batch',
          parameters: {
            'ingredients': jsonEncode(ingredients),
          },
        ),
      );
    } else if (ingredients.length == 1) {
      // If only one ingredient, use single add instead
      final ing = ingredients.first;
      toolCalls.add(
        ToolCall(
          toolName: 'add_ingredient',
          parameters: {
            'name': ing['name'],
            'quantity': ing['quantity'],
            'unit': ing['unit'],
            'category': ing['category'],
          },
        ),
      );
    }

    return toolCalls;
  }

  List<ToolCall> _parseDeleteIngredientFromText(String text) {
    final toolCalls = <ToolCall>[];

    // More specific patterns for delete operations
    final patterns = [
      // Pattern 1: "delete/remove all ingredients/inventory"
      RegExp(
        r"(?:delete|remove|clear|empty)\s+(?:all\s+)?(?:my\s+)?(?:ingredients|inventory)",
        caseSensitive: false,
      ),
      // Pattern 2: "delete/remove the [specific ingredient]" - with word boundaries
      RegExp(
        r"(?:delete|remove|get rid of)\s+(?:the\s+)?([a-zA-Z]{2,}(?:\s+[a-zA-Z]{2,})*)\b",
        caseSensitive: false,
      ),
      // Pattern 3: "delete [ingredient] from inventory"
      RegExp(
        r"(?:delete|remove)\s+([a-zA-Z]{2,}(?:\s+[a-zA-Z]{2,})*)\s+from\s+(?:my\s+)?inventory",
        caseSensitive: false,
      ),
    ];

    // Check for "delete all" pattern first
    if (patterns[0].hasMatch(text)) {
      // Don't return a tool call for "delete all" - this needs special handling
      // The AI should list ingredients first or confirm the action
      _logger.log(
        LogLevel.warning,
        'ToolExecutor',
        'Delete all inventory requested but not executing - needs confirmation',
      );
      return toolCalls;
    }

    // Check for specific ingredient deletion patterns - but only take the first match
    // to prevent duplicate deletions
    final foundIngredients = <String>{};

    for (int i = 1; i < patterns.length; i++) {
      final matches = patterns[i].allMatches(text);
      for (final match in matches) {
        if (match.groupCount >= 1) {
          final name = match.group(1)?.trim().toLowerCase();

          // Validate the ingredient name and check for duplicates
          if (name != null &&
              name.length > 1 &&
              !_isSuspiciousIngredientName(name) &&
              !foundIngredients.contains(name)) {
            foundIngredients.add(name);
            toolCalls.add(
              ToolCall(
                toolName: 'delete_ingredient',
                parameters: {'name': name},
              ),
            );

            // Only take the first valid match to prevent multiple calls
            // for the same intention expressed in different ways
            if (toolCalls.length >= 1) {
              _logger.log(
                LogLevel.debug,
                'ToolExecutor',
                'Found delete ingredient match, stopping to prevent duplicates',
              );
              return toolCalls;
            }
          }
        }
      }
    }

    return toolCalls;
  }

  bool _isSuspiciousIngredientName(String name) {
    // Filter out suspicious patterns that might be from incomplete streaming
    if (name.length <= 1) return true; // Single characters
    if (RegExp(r'^(m|my|your|the|a|an|some)$').hasMatch(name))
      return true; // Common partial words
    if (RegExp(r'^(ing|ent|ory)$').hasMatch(name))
      return true; // Word fragments
    if (RegExp(r'[^a-zA-Z\s]').hasMatch(name))
      return true; // Contains non-letter characters

    return false;
  }

  List<ToolCall> _parseUpdateQuantityFromText(String text) {
    final toolCalls = <ToolCall>[];

    // Pattern: "update [ingredient] to [quantity]"
    final updatePattern = RegExp(
      r"(?:update|change)\s+([a-zA-Z\s]+)\s+(?:to|quantity to)\s+(\d+(?:\.\d+)?)",
      caseSensitive: false,
    );

    final matches = updatePattern.allMatches(text);
    for (final match in matches) {
      final name = match.group(1)?.trim().toLowerCase();
      final quantity = double.tryParse(match.group(2) ?? '');

      if (name != null && name.isNotEmpty && quantity != null) {
        toolCalls.add(
          ToolCall(
            toolName: 'update_ingredient_quantity',
            parameters: {'name': name, 'quantity': quantity},
          ),
        );
      }
    }

    return toolCalls;
  }

  List<ToolCall> _parseListIngredientsFromText(String text) {
    final toolCalls = <ToolCall>[];

    // Pattern: "show/list [ingredients/inventory]"
    if (RegExp(
      r"(?:show|list|what(?:'s| is))\s+(?:my\s+)?(?:inventory|ingredients)",
      caseSensitive: false,
    ).hasMatch(text)) {
      final parameters = <String, dynamic>{};

      // Check for category filter
      for (final category in ['produce', 'dairy', 'meat', 'pantry', 'spices']) {
        if (text.toLowerCase().contains(category)) {
          parameters['category'] = category;
          break;
        }
      }

      // Check for expiring filter
      if (RegExp(r"expir(?:ing|e)|soon", caseSensitive: false).hasMatch(text)) {
        parameters['expiring_only'] = true;
      }

      toolCalls.add(
        ToolCall(toolName: 'list_ingredients', parameters: parameters),
      );
    }

    return toolCalls;
  }

  String? _mapUnit(String unit) {
    final unitMap = {
      'g': 'g',
      'gram': 'g',
      'grams': 'g',
      'kg': 'kg',
      'kilo': 'kg',
      'kilogram': 'kg',
      'kilograms': 'kg',
      'lb': 'lbs',
      'lbs': 'lbs',
      'pound': 'lbs',
      'pounds': 'lbs',
      'oz': 'oz',
      'ounce': 'oz',
      'ounces': 'oz',
      'ml': 'ml',
      'milliliter': 'ml',
      'milliliters': 'ml',
      'l': 'L',
      'liter': 'L',
      'liters': 'L',
      'cup': 'cups',
      'cups': 'cups',
      'tbsp': 'tbsp',
      'tablespoon': 'tbsp',
      'tablespoons': 'tbsp',
      'tsp': 'tsp',
      'teaspoon': 'tsp',
      'teaspoons': 'tsp',
      'piece': 'pieces',
      'pieces': 'pieces',
    };

    return unitMap[unit.toLowerCase()];
  }

  String _inferCategory(String ingredientName) {
    final name = ingredientName.toLowerCase();

    // Produce
    if (RegExp(
      r'tomato|lettuce|onion|carrot|potato|apple|banana|orange|lemon|lime|garlic|ginger|pepper|cucumber|spinach|broccoli|celery',
    ).hasMatch(name)) {
      return 'Produce';
    }

    // Meat
    if (RegExp(
      r'chicken|beef|pork|fish|salmon|tuna|turkey|lamb|bacon|ham|sausage',
    ).hasMatch(name)) {
      return 'Meat';
    }

    // Dairy
    if (RegExp(
      r'milk|cheese|butter|yogurt|cream|eggs?|yoghurt',
    ).hasMatch(name)) {
      return 'Dairy';
    }

    // Pantry
    if (RegExp(
      r'rice|pasta|bread|flour|sugar|oil|vinegar|sauce|beans|lentils|quinoa|oats',
    ).hasMatch(name)) {
      return 'Pantry';
    }

    // Spices
    if (RegExp(
      r'salt|pepper|cumin|paprika|oregano|basil|thyme|rosemary|cinnamon|turmeric',
    ).hasMatch(name)) {
      return 'Spices';
    }

    return 'Other';
  }

  String? _inferDefaultUnit(String ingredientName) {
    final name = ingredientName.toLowerCase();

    // Count-based items
    if (RegExp(
      r'eggs?|apples?|oranges?|bananas?|potatoes?|onions?|tomatoes?',
    ).hasMatch(name)) {
      return 'pieces';
    }

    // Liquid items
    if (RegExp(
      r'milk|juice|water|oil|vinegar|wine|broth|stock',
    ).hasMatch(name)) {
      return 'ml';
    }

    // Small granular items (spices, seasonings)
    if (RegExp(
      r'salt|pepper|cumin|paprika|oregano|basil|thyme|rosemary|cinnamon|turmeric|sugar',
    ).hasMatch(name)) {
      return 'tsp';
    }

    // Default to grams for most solid ingredients
    return 'g';
  }

  String _cleanIngredientName(String name) {
    // Remove inventory-related phrases
    name = name
        .replaceAll(
          RegExp(
            r'\s+to\s+(?:your\s+|the\s+)?inventory\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'\s+in\s+(?:your\s+|the\s+)?(?:inventory|pantry|fridge)\b',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    // Remove size descriptors
    name = name
        .replaceAll(
          RegExp(r'\b(?:large|medium|small|big|tiny)\b', caseSensitive: false),
          '',
        )
        .trim();

    // Remove common descriptors
    name = name
        .replaceAll(
          RegExp(
            r'\b(?:fresh|organic|free-range|whole|ground)\b',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    // Clean up extra spaces
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();

    return name;
  }
}
