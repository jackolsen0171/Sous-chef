import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/chatbot_widget.dart';
import '../providers/chat_provider.dart';

class AIChefScreen extends StatelessWidget {
  const AIChefScreen({Key? key}) : super(key: key);

  void _showClearChatDialog(BuildContext context, ChatProvider chatProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text(
          'This will clear all messages in the current conversation. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              chatProvider.clearChat();
              Navigator.of(context).pop();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.restaurant, size: 24),
            SizedBox(width: 8),
            Text('AI Chef Assistant'),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          Consumer<ChatProvider>(
            builder: (context, chatProvider, child) {
              return IconButton(
                icon: const Icon(Icons.clear_all),
                tooltip: 'Clear Chat',
                onPressed: () => _showClearChatDialog(context, chatProvider),
              );
            },
          ),
        ],
      ),
      body: const ChatbotWidget(),
    );
  }
}
