import 'package:flutter/material.dart';
import '../models/chat_message.dart';

class ToolCallBubble extends StatefulWidget {
  final ChatMessage message;
  final VoidCallback? onRetry;

  const ToolCallBubble({
    Key? key,
    required this.message,
    this.onRetry,
  }) : super(key: key);

  @override
  State<ToolCallBubble> createState() => _ToolCallBubbleState();
}

class _ToolCallBubbleState extends State<ToolCallBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * 3.14159,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.linear,
    ));

    if (widget.message.status == MessageStatus.executing) {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(ToolCallBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message.status == MessageStatus.executing) {
      _animationController.repeat();
    } else {
      _animationController.stop();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getStatusColor() {
    switch (widget.message.status) {
      case MessageStatus.executing:
        return Colors.orange;
      case MessageStatus.success:
        return Colors.green;
      case MessageStatus.failed:
      case MessageStatus.error:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    if (widget.message.type == MessageType.toolCall) {
      if (widget.message.status == MessageStatus.executing) {
        return Icons.settings;
      }
      return Icons.build;
    } else {
      switch (widget.message.status) {
        case MessageStatus.success:
          return Icons.check_circle;
        case MessageStatus.failed:
        case MessageStatus.error:
          return Icons.error;
        default:
          return Icons.info;
      }
    }
  }

  String _getStatusText() {
    final toolName = widget.message.metadata?['toolName'] ?? 'Unknown Tool';
    
    if (widget.message.type == MessageType.toolCall) {
      switch (widget.message.status) {
        case MessageStatus.executing:
          return 'Executing $toolName...';
        default:
          return 'Tool Call: $toolName';
      }
    } else {
      switch (widget.message.status) {
        case MessageStatus.success:
          return '$toolName completed successfully';
        case MessageStatus.failed:
        case MessageStatus.error:
          return '$toolName failed';
        default:
          return '$toolName result';
      }
    }
  }

  Widget _buildParametersList() {
    final parameters = widget.message.metadata?['parameters'] as Map<String, dynamic>?;
    if (parameters == null || parameters.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Parameters:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          ...parameters.entries.map((entry) {
            final value = entry.value?.toString() ?? 'null';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ${entry.key}: ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildResultContent() {
    final result = widget.message.metadata?['result'];
    final errorMessage = widget.message.metadata?['errorMessage'];
    
    if (errorMessage != null) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Error:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              errorMessage,
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade800,
              ),
            ),
          ],
        ),
      );
    }
    
    if (result != null) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Result:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              result.toString(),
              style: TextStyle(
                fontSize: 12,
                color: Colors.green.shade800,
              ),
            ),
          ],
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: statusColor.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: widget.message.status == MessageStatus.executing
                      ? AnimatedBuilder(
                          animation: _rotationAnimation,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _rotationAnimation.value,
                              child: Icon(
                                _getStatusIcon(),
                                size: 16,
                                color: statusColor,
                              ),
                            );
                          },
                        )
                      : Icon(
                          _getStatusIcon(),
                          size: 16,
                          color: statusColor,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getStatusText(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      if (widget.message.timestamp != null)
                        Text(
                          '${widget.message.timestamp.hour.toString().padLeft(2, '0')}:${widget.message.timestamp.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.message.type == MessageType.toolCall &&
                    widget.message.metadata?['parameters'] != null)
                  IconButton(
                    icon: Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey.shade600,
                    ),
                    onPressed: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                  ),
                if (widget.message.status == MessageStatus.failed &&
                    widget.onRetry != null)
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    color: Colors.red,
                    onPressed: widget.onRetry,
                  ),
              ],
            ),
            if (_isExpanded && widget.message.type == MessageType.toolCall)
              _buildParametersList(),
            if (widget.message.type == MessageType.toolResult)
              _buildResultContent(),
          ],
        ),
      ),
    );
  }
}