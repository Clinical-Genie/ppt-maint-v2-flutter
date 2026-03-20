import 'package:flutter/material.dart';
import 'package:maintapp/api/api_controller.dart';
import 'package:maintapp/model/email_batch.dart';

class EmailBatchDetailPage extends StatefulWidget {
  const EmailBatchDetailPage({required this.batchId, super.key});

  final String batchId;

  @override
  State<EmailBatchDetailPage> createState() => _EmailBatchDetailPageState();
}

class _EmailBatchDetailPageState extends State<EmailBatchDetailPage> {
  bool _isLoading = true;
  bool _isSending = false;
  EmailBatchDetail _detail = EmailBatchDetail();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final detail = await ApiController.getEmailBatchById(widget.batchId);
      if (!mounted) return;
      setState(() => _detail = detail);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendBatch() async {
    setState(() => _isSending = true);
    try {
      final result = await ApiController.sendEmailBatch(widget.batchId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.message} Sent: ${result.sentCount}, Failed: ${result.failedCount}',
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _removeItem(EmailBatchWorkOrderItem item) async {
    await ApiController.removeEmailBatchItem(widget.batchId, item.workOrderId);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Item removed')));
    await _load();
  }

  Widget _batchStatusBadge(String status) {
    final normalized = status.toLowerCase();
    Color bg = const Color(0xFFE2E8F0);
    Color fg = const Color(0xFF334155);
    if (normalized == 'draft') {
      bg = const Color(0xFFDBEAFE);
      fg = const Color(0xFF1D4ED8);
    } else if (normalized == 'sending') {
      bg = const Color(0xFFFFF7ED);
      fg = const Color(0xFF9A3412);
    } else if (normalized == 'sent') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF166534);
    } else if (normalized == 'failed') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFF991B1B);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        status,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700),
      ),
    );
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
    final canSend =
        _detail.status == 'draft' || _detail.status.toLowerCase() == 'failed';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Batch Detail'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _detail.subject.isEmpty ? 'No subject' : _detail.subject,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _batchStatusBadge(_detail.status.isEmpty ? '-' : _detail.status),
                  ],
                ),
                const SizedBox(height: 10),
                SelectableText('Batch ID: ${_detail.id}'),
                const SizedBox(height: 4),
                SelectableText(
                  'Recipients: ${_detail.toEmails.isEmpty ? '-' : _detail.toEmails.join(', ')}',
                ),
                const SizedBox(height: 4),
                Text('Updated: ${_formatDateTime(_detail.updatedAt)}'),
                const SizedBox(height: 4),
                Text('Sent at: ${_formatDateTime(_detail.sentAt)}'),
                if (_detail.error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Error: ${_detail.error}',
                    style: const TextStyle(color: Color(0xFFB91C1C)),
                  ),
                ],
                const SizedBox(height: 14),
                if (canSend)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton.icon(
                      onPressed: _isSending ? null : _sendBatch,
                      icon: const Icon(Icons.send_outlined),
                      label: Text(_isSending ? 'Sending...' : 'Send Batch'),
                    ),
                  ),
                const SizedBox(height: 18),
                const Text(
                  'Work Orders',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                ..._detail.workOrders.map((item) {
                  return Card(
                    child: ListTile(
                      title: Text(item.woNo.isEmpty ? item.workOrderId : item.woNo),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Status: ${item.status.isEmpty ? '-' : item.status}'),
                          Text('Sent at: ${_formatDateTime(item.sentAt)}'),
                          if (item.error.isNotEmpty)
                            Text(
                              'Error: ${item.error}',
                              style: const TextStyle(color: Color(0xFFB91C1C)),
                            ),
                          if (item.mergedPdfUrl.isNotEmpty)
                            SelectableText('Merged PDF: ${item.mergedPdfUrl}'),
                        ],
                      ),
                      trailing: _detail.status == 'draft'
                          ? IconButton(
                              tooltip: 'Remove item',
                              onPressed: () => _removeItem(item),
                              icon: const Icon(Icons.delete_outline),
                            )
                          : null,
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
