import 'package:flutter/material.dart';

class ToolActionCard extends StatelessWidget {
  final String toolName;
  final Map<String, dynamic> args;
  final dynamic result;

  const ToolActionCard({
    super.key,
    required this.toolName,
    required this.args,
    this.result,
  });

  @override
  Widget build(BuildContext methodContext) {
    return Card(
      color: Colors.blueGrey.shade50,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.settings_suggest, size: 20, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Text(
                  'AI Action: $toolName',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
                ),
              ],
            ),
            const Divider(),
            Text('Args: $args', style: const TextStyle(fontSize: 12)),
            if (result != null) ...[
              const SizedBox(height: 4),
              Text(
                'Result: ${result['status'] ?? 'Success'}',
                style: const TextStyle(fontSize: 12, color: Colors.green),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
