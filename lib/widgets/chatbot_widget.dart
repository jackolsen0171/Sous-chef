import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../providers/chat_provider.dart';
import '../providers/inventory_provider.dart';
import 'chat_message_bubble.dart';
import 'ingredient_context_panel.dart';

class ChatbotWidget extends StatefulWidget {
  final VoidCallback? onClose;
  const ChatbotWidget({Key? key, this.onClose}) : super(key: key);

  @override
  State<ChatbotWidget> createState() => _ChatbotWidgetState();
}

class _ChatbotWidgetState extends State<ChatbotWidget> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isContextPanelExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      // Initialize tools with inventory provider
      final inventoryProvider = context.read<InventoryProvider>();
      final chatProvider = context.read<ChatProvider>();
      chatProvider.initializeTools(inventoryProvider);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final inventory = context.read<InventoryProvider>().ingredients;
    context.read<ChatProvider>().sendMessage(message, inventory);

    _messageController.clear();
    FocusScope.of(context).unfocus(); // Dismiss keyboard after sending

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _sendQuickReply(String message) {
    _messageController.text = message;
    _sendMessage();
  }

  void _retryLastMessage() {
    final inventory = context.read<InventoryProvider>().ingredients;
    context.read<ChatProvider>().retryLastMessage(inventory);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside of text field
        FocusScope.of(context).unfocus();
      },
      child: Consumer2<ChatProvider, InventoryProvider>(
        builder: (context, chatProvider, inventoryProvider, child) {
          final messages = chatProvider.messages;
          final ingredients = inventoryProvider.ingredients;
          final quickReplies = chatProvider.getQuickReplySuggestions(
            ingredients,
          );

          // Auto-scroll when new messages arrive
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollToBottom();
            }
          });

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Main chat content
              Column(
                children: [
                  // Ingredient context panel at the top
                  IngredientContextPanel(
                    ingredients: ingredients,
                    isExpanded: _isContextPanelExpanded,
                    onToggle: () {
                      setState(() {
                        _isContextPanelExpanded = !_isContextPanelExpanded;
                      });
                    },
                  ),

                  // Error banner
                  if (chatProvider.error != null)
                    _buildErrorBanner(context, chatProvider),

                  // Chat messages
                  Expanded(
                    child: Stack(
                      children: [
                        ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final showAvatar =
                                index == 0 ||
                                messages[index - 1].type != message.type;

                            return ChatMessageBubble(
                              message: message,
                              showAvatar: showAvatar,
                              onRetry:
                                  message.type == MessageType.user &&
                                      message.status == MessageStatus.error
                                  ? _retryLastMessage
                                  : null,
                            );
                          },
                        ),

                        // Typing indicator
                        if (chatProvider.isTyping)
                          Positioned(
                            bottom: 20,
                            left: 16,
                            child: _buildTypingIndicator(),
                          ),
                      ],
                    ),
                  ),

                  // Quick replies
                  if (!chatProvider.isTyping && quickReplies.isNotEmpty)
                    _buildQuickReplies(quickReplies),

                  // Input field
                  _buildInputField(context, chatProvider),
                ],
              ),

              // Close button positioned at the bottom of the input area
              if (widget.onClose != null)
                Positioned(
                  bottom: 8, // Position within the input area
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: widget.onClose,
                      child: Container(
                        width: 60,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: Theme.of(context).primaryColor,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context, ChatProvider chatProvider) {
    return Container(
      width: double.infinity,
      color: Colors.red.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              chatProvider.error!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: chatProvider.clearError,
            child: Text(
              'Dismiss',
              style: TextStyle(color: Colors.red.shade600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 8,
            backgroundColor: Colors.green.shade100,
            child: const Icon(
              Icons.restaurant_menu,
              size: 10,
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Sous Chef is typing...',
            style: TextStyle(
              color: Colors.grey,
              fontStyle: FontStyle.italic,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Colors.green.shade300),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickReplies(List<String> quickReplies) {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: quickReplies.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(
                quickReplies[index],
                style: const TextStyle(fontSize: 13),
              ),
              onPressed: () => _sendQuickReply(quickReplies[index]),
              backgroundColor: Colors.grey.shade100,
              side: BorderSide(color: Colors.grey.shade300),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputField(BuildContext context, ChatProvider chatProvider) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        40,
      ), // Extra bottom padding for close button
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      decoration: const InputDecoration(
                        hintText:
                            'Ask about recipes, ingredients, or cooking tips...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      onEditingComplete: () {
                        _sendMessage();
                        FocusScope.of(context).unfocus();
                      },
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'clear',
                        child: const Row(
                          children: [
                            Icon(Icons.clear_all, size: 20),
                            SizedBox(width: 8),
                            Text('Clear Chat'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'help',
                        child: const Row(
                          children: [
                            Icon(Icons.help_outline, size: 20),
                            SizedBox(width: 8),
                            Text('Help'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'debug_tools',
                        child: const Row(
                          children: [
                            Icon(Icons.bug_report, size: 20),
                            SizedBox(width: 8),
                            Text('Debug Tools'),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      switch (value) {
                        case 'clear':
                          _showClearChatDialog(context, chatProvider);
                          break;
                        case 'help':
                          _sendQuickReply('What can you help me with?');
                          break;
                        case 'debug_tools':
                          // Debug tools removed - tools are now managed internally
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'AI tools are active and managed automatically',
                              ),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          break;
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            mini: true,
            onPressed: chatProvider.isTyping ? null : _sendMessage,
            backgroundColor: Theme.of(context).primaryColor,
            child: chatProvider.isTyping
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Icon(Icons.send, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

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
}
