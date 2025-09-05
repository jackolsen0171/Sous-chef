enum ParameterType {
  string,
  number,
  boolean,
  date,
}

class ParameterSchema {
  final String name;
  final ParameterType type;
  final String description;
  final bool required;
  final dynamic defaultValue;
  final List<String>? allowedValues;

  const ParameterSchema({
    required this.name,
    required this.type,
    required this.description,
    this.required = false,
    this.defaultValue,
    this.allowedValues,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type.name,
      'description': description,
      'required': required,
      'defaultValue': defaultValue,
      'allowedValues': allowedValues,
    };
  }
}

class ToolCall {
  final String toolName;
  final Map<String, dynamic> parameters;
  final String id;

  ToolCall({
    required this.toolName,
    required this.parameters,
    String? id,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() {
    return {
      'toolName': toolName,
      'parameters': parameters,
      'id': id,
    };
  }

  factory ToolCall.fromJson(Map<String, dynamic> json) {
    return ToolCall(
      toolName: json['toolName'],
      parameters: Map<String, dynamic>.from(json['parameters']),
      id: json['id'],
    );
  }
}

class ToolResult {
  final String toolCallId;
  final bool success;
  final String message;
  final dynamic data;
  final String? error;

  const ToolResult({
    required this.toolCallId,
    required this.success,
    required this.message,
    this.data,
    this.error,
  });

  Map<String, dynamic> toJson() {
    return {
      'toolCallId': toolCallId,
      'success': success,
      'message': message,
      'data': data,
      'error': error,
    };
  }

  factory ToolResult.success({
    required String toolCallId,
    required String message,
    dynamic data,
  }) {
    return ToolResult(
      toolCallId: toolCallId,
      success: true,
      message: message,
      data: data,
    );
  }

  factory ToolResult.error({
    required String toolCallId,
    required String message,
    String? error,
  }) {
    return ToolResult(
      toolCallId: toolCallId,
      success: false,
      message: message,
      error: error,
    );
  }
}

typedef ToolExecutorFunction = Future<ToolResult> Function(ToolCall toolCall);

class AITool {
  final String name;
  final String description;
  final Map<String, ParameterSchema> parameters;
  final ToolExecutorFunction executor;
  final bool requiresConfirmation;
  final String category;

  const AITool({
    required this.name,
    required this.description,
    required this.parameters,
    required this.executor,
    this.requiresConfirmation = false,
    this.category = 'general',
  });

  Map<String, dynamic> getSchema() {
    return {
      'name': name,
      'description': description,
      'parameters': {
        'type': 'object',
        'properties': parameters.map((key, param) => MapEntry(
          key,
          {
            'type': _getJsonType(param.type),
            'description': param.description,
            if (param.allowedValues != null) 'enum': param.allowedValues,
            if (param.defaultValue != null) 'default': param.defaultValue,
          },
        )),
        'required': parameters.entries
            .where((entry) => entry.value.required)
            .map((entry) => entry.key)
            .toList(),
      },
    };
  }

  String _getJsonType(ParameterType type) {
    switch (type) {
      case ParameterType.string:
        return 'string';
      case ParameterType.number:
        return 'number';
      case ParameterType.boolean:
        return 'boolean';
      case ParameterType.date:
        return 'string';
    }
  }

  Future<ToolResult> execute(ToolCall toolCall) async {
    try {
      // Validate parameters
      final validationResult = _validateParameters(toolCall.parameters);
      if (!validationResult.success) {
        return ToolResult.error(
          toolCallId: toolCall.id,
          message: validationResult.message,
          error: 'Parameter validation failed',
        );
      }

      // Execute the tool
      return await executor(toolCall);
    } catch (e) {
      return ToolResult.error(
        toolCallId: toolCall.id,
        message: 'Failed to execute tool: $e',
        error: e.toString(),
      );
    }
  }

  ToolResult _validateParameters(Map<String, dynamic> params) {
    // Check required parameters
    for (final entry in parameters.entries) {
      final paramName = entry.key;
      final paramSchema = entry.value;

      if (paramSchema.required && !params.containsKey(paramName)) {
        return ToolResult.error(
          toolCallId: '',
          message: 'Missing required parameter: $paramName',
        );
      }

      if (params.containsKey(paramName)) {
        final value = params[paramName];
        
        // Type validation
        if (!_isValidType(value, paramSchema.type)) {
          return ToolResult.error(
            toolCallId: '',
            message: 'Invalid type for parameter $paramName. Expected ${paramSchema.type.name}',
          );
        }

        // Enum validation
        if (paramSchema.allowedValues != null && 
            !paramSchema.allowedValues!.contains(value.toString())) {
          return ToolResult.error(
            toolCallId: '',
            message: 'Invalid value for parameter $paramName. Allowed values: ${paramSchema.allowedValues}',
          );
        }
      }
    }

    return ToolResult.success(
      toolCallId: '',
      message: 'Parameters valid',
    );
  }

  bool _isValidType(dynamic value, ParameterType type) {
    switch (type) {
      case ParameterType.string:
        return value is String;
      case ParameterType.number:
        return value is num;
      case ParameterType.boolean:
        return value is bool;
      case ParameterType.date:
        return value is String && DateTime.tryParse(value) != null;
    }
  }
}