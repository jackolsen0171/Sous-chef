import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/logger_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({Key? key}) : super(key: key);

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final LoggerService _logger = LoggerService.instance;
  
  List<String> _generalLogs = [];
  List<Map<String, dynamic>> _llmLogs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLogs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    
    try {
      final generalLogs = await _logger.getRecentLogs(100);
      final llmLogs = await _logger.getRecentLLMLogs(50);
      
      setState(() {
        _generalLogs = generalLogs;
        _llmLogs = llmLogs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _generalLogs = ['Error loading logs: $e'];
        _llmLogs = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _clearLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Logs'),
        content: const Text('Are you sure you want to clear all logs? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _logger.clearLogs();
      await _loadLogs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logs cleared successfully')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearLogs,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'General Logs'),
            Tab(text: 'LLM Logs'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildGeneralLogsTab(),
                _buildLLMLogsTab(),
              ],
            ),
    );
  }

  Widget _buildGeneralLogsTab() {
    if (_generalLogs.isEmpty) {
      return const Center(
        child: Text('No logs available'),
      );
    }

    return ListView.builder(
      itemCount: _generalLogs.length,
      itemBuilder: (context, index) {
        final log = _generalLogs[index];
        final isError = log.contains('[ERROR]');
        final isWarning = log.contains('[WARNING]');
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          color: isError 
              ? Colors.red.shade50 
              : isWarning 
                  ? Colors.orange.shade50 
                  : null,
          child: ListTile(
            dense: true,
            leading: Icon(
              isError 
                  ? Icons.error_outline 
                  : isWarning 
                      ? Icons.warning_outlined 
                      : Icons.info_outline,
              color: isError 
                  ? Colors.red 
                  : isWarning 
                      ? Colors.orange 
                      : Colors.blue,
              size: 16,
            ),
            title: Text(
              log,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
            onTap: () => _copyToClipboard(log),
          ),
        );
      },
    );
  }

  Widget _buildLLMLogsTab() {
    if (_llmLogs.isEmpty) {
      return const Center(
        child: Text('No LLM logs available'),
      );
    }

    return ListView.builder(
      itemCount: _llmLogs.length,
      itemBuilder: (context, index) {
        final log = _llmLogs[index];
        final isError = log['level'] == 'error';
        final isRequest = log['tag'] == 'LLM_REQUEST';
        final isResponse = log['tag'] == 'LLM_RESPONSE';
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: isError ? Colors.red.shade50 : null,
          child: ExpansionTile(
            leading: Icon(
              isRequest 
                  ? Icons.arrow_upward 
                  : isResponse 
                      ? Icons.arrow_downward 
                      : Icons.settings,
              color: isError 
                  ? Colors.red 
                  : isRequest 
                      ? Colors.blue 
                      : Colors.green,
            ),
            title: Text(
              '${log['tag']} - ${log['message']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              DateTime.parse(log['timestamp']).toLocal().toString(),
              style: const TextStyle(fontSize: 12),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (log['metadata'] != null) ...[
                      const Text(
                        'Details:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _formatMetadata(log['metadata']),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _copyToClipboard(_formatLogForCopy(log)),
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy Full Log'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatMetadata(Map<String, dynamic> metadata) {
    final buffer = StringBuffer();
    metadata.forEach((key, value) {
      if (value is String && value.length > 100) {
        buffer.writeln('$key: ${value.substring(0, 100)}...');
      } else if (value is List && value.length > 5) {
        buffer.writeln('$key: [${value.take(5).join(', ')}...] (${value.length} items)');
      } else {
        buffer.writeln('$key: $value');
      }
    });
    return buffer.toString().trim();
  }

  String _formatLogForCopy(Map<String, dynamic> log) {
    final buffer = StringBuffer();
    buffer.writeln('Timestamp: ${log['timestamp']}');
    buffer.writeln('Level: ${log['level']}');
    buffer.writeln('Tag: ${log['tag']}');
    buffer.writeln('Message: ${log['message']}');
    
    if (log['metadata'] != null) {
      buffer.writeln('\nMetadata:');
      final metadata = log['metadata'] as Map<String, dynamic>;
      metadata.forEach((key, value) {
        buffer.writeln('  $key: $value');
      });
    }
    
    return buffer.toString();
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }
}