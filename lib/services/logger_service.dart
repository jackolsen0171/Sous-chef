import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

enum LogLevel { debug, info, warning, error, llm }

class LoggerService {
  static final LoggerService instance = LoggerService._init();
  LoggerService._init();

  static const String _logFileName = 'sous_chef_logs.txt';
  static const String _llmLogFileName = 'llm_outputs.json';
  
  File? _logFile;
  File? _llmLogFile;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');

  Future<void> initialize() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${directory.path}/logs');
      
      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }
      
      _logFile = File('${logsDir.path}/$_logFileName');
      _llmLogFile = File('${logsDir.path}/$_llmLogFileName');
      
      // Create files if they don't exist
      if (!await _logFile!.exists()) {
        await _logFile!.create();
        await log(LogLevel.info, 'Logger', 'Logger service initialized');
      }
      
      if (!await _llmLogFile!.exists()) {
        await _llmLogFile!.create();
        await _llmLogFile!.writeAsString('[]'); // Initialize as JSON array
      }
      
      print('📁 Logger initialized: ${logsDir.path}');
    } catch (e) {
      print('❌ Failed to initialize logger: $e');
    }
  }

  Future<void> log(LogLevel level, String tag, String message, [Map<String, dynamic>? metadata]) async {
    final timestamp = _dateFormat.format(DateTime.now());
    final logEntry = '[$timestamp] [${level.name.toUpperCase()}] [$tag] $message';
    
    // Print to console
    print(logEntry);
    
    // Write to file
    try {
      if (_logFile != null) {
        await _logFile!.writeAsString('$logEntry\n', mode: FileMode.append);
      }
      
      // If metadata is provided, also log as structured data
      if (metadata != null) {
        await _logStructuredData(level, tag, message, metadata);
      }
    } catch (e) {
      print('❌ Failed to write log: $e');
    }
  }

  Future<void> _logStructuredData(LogLevel level, String tag, String message, Map<String, dynamic> metadata) async {
    try {
      final entry = {
        'timestamp': DateTime.now().toIso8601String(),
        'level': level.name,
        'tag': tag,
        'message': message,
        'metadata': metadata,
      };
      
      if (_llmLogFile != null) {
        // Read existing logs
        String content = '[]';
        if (await _llmLogFile!.exists()) {
          content = await _llmLogFile!.readAsString();
        }
        
        List<dynamic> logs = [];
        try {
          logs = jsonDecode(content);
        } catch (e) {
          logs = [];
        }
        
        // Add new entry
        logs.add(entry);
        
        // Keep only last 100 entries to prevent file from getting too large
        if (logs.length > 100) {
          logs = logs.sublist(logs.length - 100);
        }
        
        // Write back to file
        await _llmLogFile!.writeAsString(jsonEncode(logs));
      }
    } catch (e) {
      print('❌ Failed to write structured log: $e');
    }
  }

  Future<void> logLLMRequest(String prompt, List<String> inventory) async {
    await log(LogLevel.llm, 'LLM_REQUEST', 'Sending prompt to AI', {
      'prompt': prompt,
      'inventory_count': inventory.length,
      'inventory': inventory,
    });
  }

  Future<void> logLLMResponse(String response, int suggestionCount, {String? error}) async {
    await log(LogLevel.llm, 'LLM_RESPONSE', 
        error != null ? 'AI request failed: $error' : 'AI response received', {
      'raw_response': response,
      'suggestion_count': suggestionCount,
      'success': error == null,
      'error': error,
      'response_length': response.length,
    });
  }

  Future<void> logLLMParsing(String rawResponse, List<Map<String, dynamic>> parsedSuggestions, {String? error}) async {
    await log(LogLevel.llm, 'LLM_PARSING', 
        error != null ? 'Failed to parse AI response: $error' : 'AI response parsed successfully', {
      'raw_response': rawResponse,
      'parsed_suggestions': parsedSuggestions,
      'suggestion_count': parsedSuggestions.length,
      'success': error == null,
      'error': error,
    });
  }

  Future<String> getLogFilePath() async {
    if (_logFile != null) {
      return _logFile!.path;
    }
    return 'Log file not initialized';
  }

  Future<String> getLLMLogFilePath() async {
    if (_llmLogFile != null) {
      return _llmLogFile!.path;
    }
    return 'LLM log file not initialized';
  }

  Future<List<String>> getRecentLogs([int count = 50]) async {
    try {
      if (_logFile == null || !await _logFile!.exists()) {
        return ['No logs available'];
      }
      
      final content = await _logFile!.readAsString();
      final lines = content.split('\n').where((line) => line.isNotEmpty).toList();
      
      return lines.length > count ? lines.sublist(lines.length - count) : lines;
    } catch (e) {
      return ['Error reading logs: $e'];
    }
  }

  Future<List<Map<String, dynamic>>> getRecentLLMLogs([int count = 20]) async {
    try {
      if (_llmLogFile == null || !await _llmLogFile!.exists()) {
        return [];
      }
      
      final content = await _llmLogFile!.readAsString();
      final List<dynamic> logs = jsonDecode(content);
      final List<Map<String, dynamic>> typedLogs = logs.cast<Map<String, dynamic>>();
      
      return typedLogs.length > count ? typedLogs.sublist(typedLogs.length - count) : typedLogs;
    } catch (e) {
      print('Error reading LLM logs: $e');
      return [];
    }
  }

  Future<void> clearLogs() async {
    try {
      if (_logFile != null && await _logFile!.exists()) {
        await _logFile!.writeAsString('');
        await log(LogLevel.info, 'Logger', 'Log file cleared');
      }
      
      if (_llmLogFile != null && await _llmLogFile!.exists()) {
        await _llmLogFile!.writeAsString('[]');
      }
    } catch (e) {
      print('❌ Failed to clear logs: $e');
    }
  }
}