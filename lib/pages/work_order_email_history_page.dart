import 'package:flutter/material.dart';
import 'package:maintapp/model/email_batch.dart';
import 'package:maintapp/model/work_order.dart';
import 'package:maintapp/api/api_controller.dart';

class WorkOrderEmailHistoryPage extends StatefulWidget {
  const WorkOrderEmailHistoryPage({required this.workOrder, super.key});

  final WorkOrder workOrder;

  @override
  State<WorkOrderEmailHistoryPage> createState() =>
      _WorkOrderEmailHistoryPageState();
}

class _WorkOrderEmailHistoryPageState extends State<WorkOrderEmailHistoryPage> {
  bool _isLoading = true;
  WorkOrderEmailHistoryResult _history = WorkOrderEmailHistoryResult();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final history = await ApiController.getWorkOrderEmailHistory(
        widget.workOrder.id,
      );
      if (!mounted) return;
      setState(() => _history = history);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _badge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Widget _statusBadge(String value) {
    final normalized = value.toLowerCase();
    if (normalized == 'sent') {
      return _badge('sent', const Color(0xFFDCFCE7), const Color(0xFF166534));
    }
    if (normalized == 'failed') {
      return _badge('failed', const Color(0xFFFEE2E2), const Color(0xFF991B1B));
    }
    if (normalized == 'draft') {
      return _badge('draft', const Color(0xFFDBEAFE), const Color(0xFF1D4ED8));
    }
    if (normalized == 'sending') {
      return _badge(
        'sending',
        const Color(0xFFFFF7ED),
        const Color(0xFF9A3412),
      );
    }
    return _badge(value, const Color(0xFFE2E8F0), const Color(0xFF334155));
  }

  String _formatDateTime(String value) {
    if (value.isEmpty) return '-';
    try {
      final dt = DateTime.parse(value).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.workOrder.referenceNumber} Emails')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.items.isEmpty
          ? const Center(child: Text('No email history'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _history.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = _history.items[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.subject.isEmpty ? 'No subject' : item.subject,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            _statusBadge(item.status),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SelectableText('Batch ID: ${item.emailBatchId}'),
                        const SizedBox(height: 4),
                        SelectableText(
                          'Recipients: ${item.toEmails.isEmpty ? '-' : item.toEmails.join(', ')}',
                        ),
                        const SizedBox(height: 4),
                        Text('Batch status: ${item.batchStatus}'),
                        const SizedBox(height: 4),
                        Text('Sent at: ${_formatDateTime(item.sentAt)}'),
                        const SizedBox(height: 4),
                        Text('Linked at: ${_formatDateTime(item.linkedAt)}'),
                        if (item.error.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Error: ${item.error}',
                            style: const TextStyle(color: Color(0xFFB91C1C)),
                          ),
                        ],
                        if (item.mergedPdfUrl.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          SelectableText('Merged PDF: ${item.mergedPdfUrl}'),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
