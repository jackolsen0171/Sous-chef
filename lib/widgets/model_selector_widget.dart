import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../services/openrouter_service.dart';

class ModelSelectorWidget extends StatelessWidget {
  const ModelSelectorWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        return PopupMenuButton<String>(
          icon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getProviderIcon(chatProvider.currentProvider),
                size: 18,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 4),
              Text(
                _getProviderDisplayName(chatProvider.currentProvider),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                size: 16,
                color: Theme.of(context).primaryColor,
              ),
            ],
          ),
          tooltip: 'Switch AI Model',
          onSelected: (modelKey) {
            _switchModel(context, chatProvider, modelKey);
          },
          itemBuilder: (context) {
            final items = <PopupMenuEntry<String>>[];
            
            // All models now go through OpenRouter
            if (chatProvider.isOpenRouterAvailable) {
              items.add(
                PopupMenuItem<String>(
                  enabled: false,
                  child: Text(
                    'Available AI Models (via OpenRouter)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              );
              
              for (final entry in OpenRouterService.availableModels.entries) {
                items.add(
                  PopupMenuItem<String>(
                    value: entry.key,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _getModelIcon(entry.value.name),
                              size: 16,
                              color: Theme.of(context).primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              entry.value.name,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const Spacer(),
                            if (_isCurrentModel(entry.key, chatProvider))
                              Icon(
                                Icons.check_circle,
                                size: 16,
                                color: Theme.of(context).primaryColor,
                              ),
                          ],
                        ),
                        if (entry.value.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 24, top: 2),
                            child: Text(
                              entry.value.description,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }
            } else {
              // OpenRouter not available - show setup message
              items.add(
                PopupMenuItem<String>(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Setup Required',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add OPENROUTER_API_KEY to .env file',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Get your key from openrouter.ai',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            
            return items;
          },
        );
      },
    );
  }

  void _switchModel(BuildContext context, ChatProvider chatProvider, String modelKey) {
    final modelInfo = OpenRouterService.availableModels[modelKey];
    if (modelInfo != null) {
      chatProvider.switchModel(model: modelKey);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to ${modelInfo.name}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  bool _isCurrentModel(String modelKey, ChatProvider chatProvider) {
    final modelInfo = OpenRouterService.availableModels[modelKey];
    if (modelInfo == null) return false;
    
    // Check if this model ID matches the current model
    return chatProvider.currentProvider == 'openRouter' && 
           modelInfo.id == chatProvider.currentModel;
  }

  IconData _getProviderIcon(String provider) {
    switch (provider.toLowerCase()) {
      case 'openrouter':
        return Icons.hub;
      case 'gemini':
        return Icons.flash_on;
      default:
        return Icons.psychology;
    }
  }
  
  String _getProviderDisplayName(String provider) {
    // Since everything goes through OpenRouter now, show the actual model name
    // This will be updated to show the current model name dynamically
    return 'AI Models';
  }
  
  IconData _getModelIcon(String modelName) {
    if (modelName.contains('Claude')) {
      return Icons.psychology_outlined;
    } else if (modelName.contains('GPT')) {
      return Icons.smart_toy;
    } else if (modelName.contains('Gemini')) {
      return Icons.flash_on;
    }
    return Icons.computer;
  }
}