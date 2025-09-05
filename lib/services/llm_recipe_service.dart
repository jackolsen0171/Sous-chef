import 'dart:async';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/ingredient.dart';
import '../models/ai_recipe_suggestion.dart';
import 'logger_service.dart';

class LLMRecipeService {
  static final LLMRecipeService instance = LLMRecipeService._init();
  
  LLMRecipeService._init();

  GenerativeModel? _model;
  final LoggerService _logger = LoggerService.instance;

  Future<void> initialize() async {
    await _logger.log(LogLevel.info, 'LLM', 'Initializing LLM service...');
    
    try {
      await dotenv.load();
      await _logger.log(LogLevel.debug, 'LLM', '.env file loaded successfully');
    } catch (e) {
      await _logger.log(LogLevel.error, 'LLM', '.env load failed', {'error': e.toString()});
    }
    
    final apiKey = dotenv.env['GOOGLE_AI_API_KEY'];
    await _logger.log(LogLevel.debug, 'LLM', 'API key check', {
      'has_api_key': apiKey != null,
      'api_key_length': apiKey?.length ?? 0,
      'api_key_preview': apiKey?.substring(0, apiKey.length > 10 ? 10 : apiKey.length) ?? 'null'
    });
    
    if (apiKey == null || apiKey.isEmpty || apiKey == 'your_api_key_here') {
      await _logger.log(LogLevel.error, 'LLM', 'No valid API key found');
      throw Exception('Google AI API key not found. Please add GOOGLE_AI_API_KEY to your .env file');
    }
    
    await _logger.log(LogLevel.info, 'LLM', 'API key loaded successfully');

    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topP: 0.8,
        maxOutputTokens: 2048,
      ),
    );
  }

  Future<List<AIRecipeSuggestion>> generateRecipeSuggestions(List<Ingredient> inventory) async {
    if (_model == null) {
      await _logger.log(LogLevel.error, 'LLM', 'Service not initialized');
      throw Exception('LLM service not initialized. Call initialize() first.');
    }

    if (inventory.isEmpty) {
      await _logger.log(LogLevel.warning, 'LLM', 'Empty inventory provided');
      return [];
    }

    try {
      final prompt = _buildInventoryPrompt(inventory);
      final inventoryNames = inventory.map((i) => i.name).toList();
      
      await _logger.logLLMRequest(prompt, inventoryNames);
      
      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);
      
      if (response.text == null) {
        await _logger.logLLMResponse('', 0, error: 'No response text from AI model');
        throw Exception('No response text from AI model');
      }

      await _logger.logLLMResponse(response.text!, 0);
      
      final suggestions = _parseAIResponse(response.text!);
      await _logger.log(LogLevel.info, 'LLM', 'Successfully generated ${suggestions.length} recipe suggestions');
      
      return suggestions;
    } catch (e) {
      await _logger.logLLMResponse('', 0, error: e.toString());
      throw Exception('Failed to generate recipe suggestions: $e');
    }
  }


  String _buildInventoryPrompt(List<Ingredient> inventory) {
    final inventoryList = inventory.map((ingredient) {
      final expiryInfo = ingredient.expiryDate != null 
          ? ' (expires ${ingredient.expiryDate!.difference(DateTime.now()).inDays} days)'
          : '';
      return '- ${ingredient.name}: ${ingredient.quantity}${ingredient.unit}$expiryInfo';
    }).join('\n');

    return '''
You are a creative chef assistant. Generate 3-4 practical recipe suggestions based on the following kitchen inventory.

CURRENT INVENTORY:
$inventoryList

REQUIREMENTS:
1. Prioritize ingredients that expire soon
2. Suggest recipes that use the maximum number of available ingredients
3. Include simple recipes that can be made with mostly available ingredients
4. For each recipe, clearly identify which ingredients from inventory are used and which need to be purchased

RESPONSE FORMAT (JSON):
{
  "suggestions": [
    {
      "title": "Recipe Name",
      "description": "Brief description",
      "ingredients": ["ingredient 1", "ingredient 2", ...],
      "instructions": ["step 1", "step 2", ...],
      "reasoning": "Why this recipe fits the available ingredients",
      "confidenceScore": 0.85,
      "missingIngredients": ["items not in inventory"],
      "estimatedPrepTime": 15,
      "estimatedCookTime": 30,
      "difficulty": "Easy|Medium|Hard",
      "category": "Breakfast|Lunch|Dinner|Snack|Dessert",
      "servings": 4
    }
  ]
}

Generate creative, practical recipes that make good use of the available ingredients.''';
  }

  List<AIRecipeSuggestion> _parseAIResponse(String response) {
    try {
      final cleanResponse = response.trim();
      
      String jsonStr;
      if (cleanResponse.startsWith('```json')) {
        final startIndex = cleanResponse.indexOf('{');
        final endIndex = cleanResponse.lastIndexOf('}') + 1;
        jsonStr = cleanResponse.substring(startIndex, endIndex);
      } else if (cleanResponse.startsWith('```')) {
        final lines = cleanResponse.split('\n');
        lines.removeAt(0);
        if (lines.last.trim() == '```') {
          lines.removeLast();
        }
        jsonStr = lines.join('\n');
      } else {
        jsonStr = cleanResponse;
      }

      final Map<String, dynamic> parsed = jsonDecode(jsonStr);
      final List<dynamic> suggestions = parsed['suggestions'] ?? [];

      final parsedSuggestions = suggestions.map((suggestion) {
        return {
          'title': suggestion['title'] ?? 'Untitled Recipe',
          'description': suggestion['description'] ?? '',
          'ingredients': suggestion['ingredients'] ?? [],
          'instructions': suggestion['instructions'] ?? [],
          'reasoning': suggestion['reasoning'] ?? 'AI generated suggestion',
          'confidenceScore': suggestion['confidenceScore'] ?? 0.5,
          'missingIngredients': suggestion['missingIngredients'] ?? [],
          'estimatedPrepTime': suggestion['estimatedPrepTime'] ?? 15,
          'estimatedCookTime': suggestion['estimatedCookTime'] ?? 30,
          'difficulty': suggestion['difficulty'] ?? 'Medium',
          'category': suggestion['category'] ?? 'Dinner',
          'servings': suggestion['servings'] ?? 4,
        };
      }).toList();

      _logger.logLLMParsing(response, parsedSuggestions);

      return parsedSuggestions.map((suggestion) {
        return AIRecipeSuggestion(
          id: DateTime.now().millisecondsSinceEpoch.toString() + parsedSuggestions.indexOf(suggestion).toString(),
          title: suggestion['title'],
          description: suggestion['description'],
          ingredients: List<String>.from(suggestion['ingredients']),
          instructions: List<String>.from(suggestion['instructions']),
          reasoning: suggestion['reasoning'],
          confidenceScore: suggestion['confidenceScore'].toDouble(),
          missingIngredients: List<String>.from(suggestion['missingIngredients']),
          estimatedPrepTime: suggestion['estimatedPrepTime'],
          estimatedCookTime: suggestion['estimatedCookTime'],
          difficulty: suggestion['difficulty'],
          category: suggestion['category'],
          servings: suggestion['servings'],
        );
      }).toList();
    } catch (e) {
      _logger.logLLMParsing(response, [], error: e.toString());
      return [];
    }
  }

  void dispose() {
  }
}