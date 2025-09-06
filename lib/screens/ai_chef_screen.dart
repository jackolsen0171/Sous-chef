import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/chatbot_widget.dart';
import '../providers/chat_provider.dart';

class AIChefScreen extends StatelessWidget {
  final VoidCallback? onClose;
  const AIChefScreen({Key? key, this.onClose}) : super(key: key);

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
    return Column(
      children: [
        // Menu actions in a subtle bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
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
        ),
        // Chat content
        Expanded(
          child: ChatbotWidget(onClose: onClose),
        ),
      ],
    );
  }
}
