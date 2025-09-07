import 'package:flutter/material.dart';
import '../services/tool_registry.dart';

class ToolsStatusWidget extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback? onToggle;

  const ToolsStatusWidget({
    Key? key,
    this.isExpanded = false,
    this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final toolRegistry = ToolRegistry.instance;
    final allTools = toolRegistry.getAllTools();
    final inventoryTools = allTools; // All tools are now inventory tools

    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.blue.shade200),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context, allTools.length, inventoryTools.length),
          if (isExpanded) _buildToolsList(context, allTools),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int totalTools, int inventoryTools) {
    return InkWell(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.build_circle,
                size: 16,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Tools Available',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  Text(
                    '$totalTools total • $inventoryTools inventory tools',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: totalTools > 0 ? Colors.green.shade100 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: totalTools > 0 ? Colors.green.shade300 : Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    totalTools > 0 ? Icons.check_circle : Icons.error_outline,
                    size: 12,
                    color: totalTools > 0 ? Colors.green.shade700 : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    totalTools > 0 ? 'Active' : 'None',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: totalTools > 0 ? Colors.green.shade700 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 16,
              color: Colors.blue.shade600,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolsList(BuildContext context, List<Map<String, dynamic>> tools) {
    if (tools.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No AI tools available. Tools may not be initialized yet.',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 150),
      child: SingleChildScrollView(
        child: Column(
          children: tools.map((tool) => _buildToolItem(context, tool)).toList(),
        ),
      ),
    );
  }

  Widget _buildToolItem(BuildContext context, Map<String, dynamic> tool) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _getCategoryColor('inventory').withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Icon(
                _getCategoryIcon('inventory'),
                size: 14,
                color: _getCategoryColor('inventory'),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (tool['function']?['name'] ?? 'Unknown Tool').toString().replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // No confirmation flag in new format
                  ],
                ),
                Text(
                  tool['function']?['description'] ?? 'No description available',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${(tool['function']?['parameters']?['properties'] as Map<String, dynamic>?)?.length ?? 0}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'inventory':
        return Colors.green;
      case 'recipe':
        return Colors.orange;
      case 'cooking':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'inventory':
        return Icons.inventory_2;
      case 'recipe':
        return Icons.restaurant_menu;
      case 'cooking':
        return Icons.local_fire_department;
      default:
        return Icons.build;
    }
  }
}

class ToolsDebugSheet extends StatelessWidget {
  const ToolsDebugSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final toolRegistry = ToolRegistry.instance;
    final allTools = toolRegistry.getAllTools();
    final toolSchemas = toolRegistry.getToolSchemas();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.bug_report, color: Colors.blue.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'AI Tools Debug Info',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              
              const Divider(),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryCard(allTools),
                      const SizedBox(height: 16),
                      _buildDebugToolsList(allTools),
                      const SizedBox(height: 16),
                      _buildSchemasSection(toolSchemas),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(List<Map<String, dynamic>> tools) {
    final inventoryTools = tools.length; // All tools are inventory tools
    final confirmedTools = 0; // No confirmation in new format
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Summary',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildStatChip('Total Tools', tools.length.toString(), Colors.blue),
                const SizedBox(width: 8),
                _buildStatChip('Inventory', inventoryTools.toString(), Colors.green),
                const SizedBox(width: 8),
                _buildStatChip('Require Confirm', confirmedTools.toString(), Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _getDarkerColor(color),
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: _getLighterColor(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugToolsList(List<Map<String, dynamic>> tools) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Registered Tools',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...tools.map((tool) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(Icons.check, size: 12, color: Colors.green.shade700),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tool['function']?['name'] ?? 'Unknown Tool',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                  Text(
                    '${(tool['function']?['parameters']?['properties'] as Map<String, dynamic>?)?.length ?? 0} params',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildSchemasSection(List<Map<String, dynamic>> schemas) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tool Schemas (What AI Sees)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                schemas.map((schema) => '• ${schema['function']?['name'] ?? 'Unknown'}: ${schema['function']?['description'] ?? 'No description'}').join('\n'),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getDarkerColor(Color color) {
    return Color.lerp(color, Colors.black, 0.3) ?? color;
  }

  Color _getLighterColor(Color color) {
    return Color.lerp(color, Colors.black, 0.2) ?? color;
  }
}