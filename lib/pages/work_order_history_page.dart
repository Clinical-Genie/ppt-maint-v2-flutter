import 'package:flutter/material.dart';
import 'package:maintapp/api/api_controller.dart';
import 'package:maintapp/model/work_order.dart';
import 'package:maintapp/model/work_order_history.dart';

class WorkOrderHistoryPage extends StatefulWidget {
  const WorkOrderHistoryPage({required this.workOrder, super.key});

  final WorkOrder workOrder;

  @override
  State<WorkOrderHistoryPage> createState() => _WorkOrderHistoryPageState();
}

class _WorkOrderHistoryPageState extends State<WorkOrderHistoryPage> {
  bool _isLoading = true;
  WorkOrderHistoryResponse _history = WorkOrderHistoryResponse();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final history = await ApiController.getWorkOrderHistory(
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

  IconData _iconForAction(String action) {
    switch (action) {
      case 'created':
        return Icons.add_task_outlined;
      case 'picked':
        return Icons.back_hand_outlined;
      case 'assigned':
        return Icons.assignment_ind_outlined;
      case 'released_to_pool':
        return Icons.move_to_inbox_outlined;
      case 'planned':
        return Icons.event_note_outlined;
      case 'started':
        return Icons.play_circle_outline;
      case 'cannot_completed':
        return Icons.error_outline;
      case 'completed':
        return Icons.task_alt_outlined;
      case 'form_created':
      case 'form_saved':
      case 'form_submitted':
      case 'form_signed':
      case 'form_admin_edited':
      case 'form_remark_added':
        return Icons.description_outlined;
      case 'approved':
        return Icons.verified_outlined;
      case 'merged_pdf_regenerated':
      case 'source_file_uploaded':
      case 'source_file_deleted':
        return Icons.picture_as_pdf_outlined;
      case 'email_batch_added':
      case 'email_sent':
      case 'email_failed':
        return Icons.send_outlined;
      default:
        return Icons.history;
    }
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

  bool _isActorInactive(Map<String, dynamic> details) {
    final activeValue = details['actor_is_active'] ?? details['is_active'];
    if (activeValue is bool) {
      return !activeValue;
    }
    if (activeValue is String) {
      final lowered = activeValue.toLowerCase();
      if (lowered == 'false' || lowered == '0') return true;
      if (lowered == 'true' || lowered == '1') return false;
    }
    if (details['actor_status'] is String) {
      return details['actor_status'].toString().toLowerCase() == 'inactive';
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.workOrder.referenceNumber} History'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.items.isEmpty
          ? const Center(child: Text('No history records'))
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _iconForAction(item.action),
                              color: const Color(0xFF0F766E),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.displaySummary,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (item.actorNameSnapshot.isEmpty)
                                    Text(
                                      _formatDateTime(item.createdAt),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    )
                                  else
                                    _buildActorInfoLine(
                                      actorName: item.actorNameSnapshot,
                                      details: item.detailsJson,
                                      createdAt: item.createdAt,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (item.fromStatus.isNotEmpty ||
                            item.toStatus.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Status: ${item.fromStatus.isEmpty ? '-' : item.fromStatus} -> ${item.toStatus.isEmpty ? '-' : item.toStatus}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        if (item.detailsJson.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              childrenPadding: EdgeInsets.zero,
                              title: const Text(
                                'Details',
                                style: TextStyle(fontSize: 13),
                              ),
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: SelectableText(
                                    item.prettyDetails,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildActorInfoLine({
    required String actorName,
    required Map<String, dynamic> details,
    required String createdAt,
    required TextStyle style,
  }) {
    return DefaultTextStyle(
      style: style,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isActorInactive(details)) ...[
            const Icon(Icons.close, size: 14, color: Color(0xFFB91C1C)),
            const SizedBox(width: 4),
          ],
          Text('$actorName • ${_formatDateTime(createdAt)}'),
        ],
      ),
    );
  }
}
