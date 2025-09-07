import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'logger_service.dart';

class OpenRouterService {
  static const String _baseUrl = 'https://openrouter.ai/api/v1';
  final LoggerService _logger = LoggerService.instance;

  late final String _apiKey;
  String _currentModel = 'anthropic/claude-sonnet-4'; // Default model

  // Available models - ordered by preference for tool calling
  static const Map<String, ModelInfo> availableModels = {
    'claude-4': ModelInfo(
      id: 'anthropic/claude-sonnet-4',
      name: 'claude-sonnet-4',
      description: 'Latest and most capable Claude model',
    ),
    'claude-3-sonnet': ModelInfo(
      id: 'anthropic/claude-3-sonnet-20240229',
      name: 'Claude 3 Sonnet',
      description: 'Balanced performance, excellent tool calling',
    ),
    'claude-3-haiku': ModelInfo(
      id: 'anthropic/claude-3-haiku-20240307',
      name: 'Claude 3 Haiku',
      description: 'Fast, affordable, great for tool calling',
    ),
    'claude-3-opus': ModelInfo(
      id: 'anthropic/claude-3-opus-20240229',
      name: 'Claude 3 Opus',
      description: 'Most capable Claude 3, best for complex tasks',
    ),
    'gpt-4-turbo': ModelInfo(
      id: 'openai/gpt-4-turbo',
      name: 'GPT-4 Turbo',
      description: 'Strong performance, good tool calling',
    ),
    'gemini-2.5-flash': ModelInfo(
      id: 'google/gemini-2.5-flash',
      name: 'Gemini 2.5 Flash',
      description: 'Latest Gemini model, fast and capable',
    ),
    'gemini-1.5-flash': ModelInfo(
      id: 'google/gemini-flash-1.5',
      name: 'Gemini 1.5 Flash',
      description: 'Fast Google model, good for quick tasks',
    ),
  };

  bool get isInitialized => _apiKey.isNotEmpty;
  String get currentModel => _currentModel;

  OpenRouterService() {
    _initialize();
  }

  void _initialize() {
    _apiKey = dotenv.env['OPENROUTER_API_KEY'] ?? '';
    if (_apiKey.isEmpty) {
      _logger.log(LogLevel.warning, 'OpenRouter', 'No API key found in .env');
    } else {
      _logger.log(
        LogLevel.info,
        'OpenRouter',
        'Service initialized successfully',
      );
    }
  }

  void setModel(String modelKey) {
    if (availableModels.containsKey(modelKey)) {
      _currentModel = availableModels[modelKey]!.id;
      _logger.log(
        LogLevel.info,
        'OpenRouter',
        'Model changed to: $_currentModel',
      );
    }
  }

  Future<Map<String, dynamic>> sendMessage({
    required String systemPrompt,
    required String userMessage,
    List<Map<String, dynamic>>? tools,
    int maxTokens = 2048,
    double temperature = 0.7,
  }) async {
    if (!isInitialized) {
      return {'success': false, 'error': 'OpenRouter API key not configured'};
    }

    try {
      // Ensure parameters are strings
      String safeSystemPrompt = systemPrompt;
      if (systemPrompt is List) {
        safeSystemPrompt = (systemPrompt as List).join(' ');
        _logger.log(LogLevel.warning, 'OpenRouter', 'System prompt was List, converted to String');
      } else if (systemPrompt is! String) {
        safeSystemPrompt = systemPrompt.toString();
        _logger.log(LogLevel.warning, 'OpenRouter', 'System prompt was not String, converted');
      }
      
      String safeUserMessage = userMessage;
      if (userMessage is List) {
        safeUserMessage = (userMessage as List).join(' ');
        _logger.log(LogLevel.warning, 'OpenRouter', 'User message was List, converted to String');
      } else if (userMessage is! String) {
        safeUserMessage = userMessage.toString();
        _logger.log(LogLevel.warning, 'OpenRouter', 'User message was not String, converted');
      }

      final messages = [
        {'role': 'system', 'content': safeSystemPrompt},
        {'role': 'user', 'content': safeUserMessage},
      ];

      final requestBody = {
        'model': _currentModel,
        'messages': messages,
        'max_tokens': maxTokens,
        'temperature': temperature,
      };

      // Add tools if provided
      if (tools != null && tools.isNotEmpty) {
        requestBody['tools'] = tools;
        requestBody['tool_choice'] = 'auto';
      }

      _logger.log(LogLevel.debug, 'OpenRouter', 'Sending request', {
        'model': _currentModel,
        'message_length': userMessage.length,
        'tools_count': tools?.length ?? 0,
      });

      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'sous-chef-app',
          'X-Title': 'Sous Chef Cooking Assistant',
        },
        body: jsonEncode(requestBody),
      );

      _logger.log(LogLevel.debug, 'OpenRouter', 'Response received', {
        'status': response.statusCode,
        'response_length': response.body.length,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Extract response data
        final message = data['choices']?[0]?['message'];
        final content = message?['content'] ?? '';
        final toolCalls = message?['tool_calls'];
        final usage = data['usage'];

        _logger.log(LogLevel.info, 'OpenRouter', 'Request successful', {
          'content_length': content.length,
          'tool_calls_count': toolCalls?.length ?? 0,
          'tokens_used': usage?['total_tokens'],
        });

        return {
          'success': true,
          'content': content,
          'tool_calls': toolCalls,
          'usage': usage,
        };
      } else {
        final errorMsg = 'OpenRouter API error: ${response.statusCode}';
        _logger.log(LogLevel.error, 'OpenRouter', errorMsg, {
          'response_body': response.body,
        });

        return {'success': false, 'error': errorMsg, 'details': response.body};
      }
    } catch (e) {
      _logger.log(LogLevel.error, 'OpenRouter', 'Request failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // No conversion needed - tools are now in native OpenAI format!
}

class ModelInfo {
  final String id;
  final String name;
  final String description;

  const ModelInfo({
    required this.id,
    required this.name,
    required this.description,
  });
}
