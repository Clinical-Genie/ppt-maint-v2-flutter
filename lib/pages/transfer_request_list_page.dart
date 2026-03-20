import 'package:flutter/material.dart';
import 'package:maintapp/api/api_controller.dart';
import 'package:maintapp/model/transfer_request.dart';
import 'package:maintapp/model/user_info.dart';
import 'package:maintapp/pages/shared/app_drawer.dart';
import 'package:maintapp/pages/work_order_detail_page.dart';
import 'package:maintapp/state/login_session_controller.dart';

class TransferRequestListPage extends StatefulWidget {
  const TransferRequestListPage({
    this.initialMode = TransferRequestPageMode.incoming,
    super.key,
  });

  final TransferRequestPageMode initialMode;

  @override
  State<TransferRequestListPage> createState() =>
      _TransferRequestListPageState();
}

enum TransferRequestPageMode { incoming, outgoing }

class _TransferRequestListPageState extends State<TransferRequestListPage> {
  static const int _pageSize = 20;
  static const List<String> _statuses = [
    'PENDING',
    'ACCEPTED',
    'REJECTED',
    'CANCELLED',
  ];

  bool _isLoading = true;
  String _selectedStatus = 'PENDING';
  TransferRequestListResponse _result = TransferRequestListResponse();
  late TransferRequestPageMode _mode;

  bool get _isIncoming => _mode == TransferRequestPageMode.incoming;
  String get _currentUserId => LoginSessionController.instance.userInfo.id;
  int get _currentPage => (_result.offset ~/ _pageSize) + 1;
  bool get _hasPreviousPage => _result.offset > 0;
  bool get _hasNextPage =>
      (_result.offset + _result.items.length) < _result.total;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _load(offset: 0);
  }

  Future<void> _load({int? offset}) async {
    setState(() => _isLoading = true);
    try {
      final result = _isIncoming
          ? await ApiController.listIncomingTransferRequests(
              status: _selectedStatus,
              limit: _pageSize,
              offset: offset ?? _result.offset,
            )
          : await ApiController.listOutgoingTransferRequests(
              status: _selectedStatus,
              limit: _pageSize,
              offset: offset ?? _result.offset,
            );
      if (!mounted) return;
      setState(() => _result = result);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _changeMode(TransferRequestPageMode mode) async {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _result = TransferRequestListResponse();
      _selectedStatus = 'PENDING';
    });
    await _load(offset: 0);
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

  String _requestTypeTitle(TransferRequest item) {
    return item.requestType == 'takeover_request'
        ? 'Takeover Request'
        : 'Transfer Request';
  }

  String _requestTypeMessage(TransferRequest item) {
    if (_isIncoming) {
      return item.requestType == 'takeover_request'
          ? 'Engineer wants you to pass this WO to them'
          : 'Engineer wants to hand this WO to you';
    }
    return item.requestType == 'takeover_request'
        ? 'You asked the current owner to pass this WO to you'
        : 'You asked another engineer to take this WO';
  }

  Widget _statusBadge(String status) {
    final normalized = status.toUpperCase();
    Color bg = const Color(0xFFE2E8F0);
    Color fg = const Color(0xFF334155);
    if (normalized == 'PENDING') {
      bg = const Color(0xFFDBEAFE);
      fg = const Color(0xFF1D4ED8);
    } else if (normalized == 'ACCEPTED') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF166534);
    } else if (normalized == 'REJECTED') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFF991B1B);
    } else if (normalized == 'CANCELLED') {
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF475569);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Future<String?> _promptReason(String title, {bool required = true}) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        bool submitting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: TextField(
                controller: controller,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () {
                          final value = controller.text.trim();
                          setDialogState(() => submitting = true);
                          if (required && value.isEmpty) {
                            setDialogState(() => submitting = false);
                            return;
                          }
                          Navigator.of(dialogContext).pop(value);
                        },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _acceptRequest(TransferRequest item) async {
    try {
      final result = await ApiController.acceptTransferRequest(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message.isEmpty
                ? 'Transfer request accepted.'
                : result.message,
          ),
        ),
      );
      await _load(offset: _result.offset);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _rejectRequest(TransferRequest item) async {
    final reason = await _promptReason(
      'Reject transfer request',
      required: false,
    );
    if (reason == null) return;
    try {
      final result = await ApiController.rejectTransferRequest(
        item.id,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message.isEmpty
                ? 'Transfer request rejected.'
                : result.message,
          ),
        ),
      );
      await _load(offset: _result.offset);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _cancelRequest(TransferRequest item) async {
    final reason = await _promptReason(
      'Cancel transfer request',
      required: false,
    );
    if (reason == null) return;
    try {
      final result = await ApiController.cancelTransferRequest(
        item.id,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message.isEmpty
                ? 'Transfer request cancelled.'
                : result.message,
          ),
        ),
      );
      await _load(offset: _result.offset);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Widget _buildRequestCard(TransferRequest item) {
    final wo = item.workOrder;
    final canCancel =
        !_isIncoming &&
        item.status.toUpperCase() == 'PENDING' &&
        item.requestedBy.trim() == _currentUserId;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _requestTypeTitle(item),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        wo.woNo.isEmpty
                            ? item.workOrderId
                            : '${wo.woNo} (${wo.woType})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _requestTypeMessage(item),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
                _statusBadge(item.status),
              ],
            ),
            const SizedBox(height: 10),
            SelectableText(
              'Location: ${wo.locationCode.isEmpty ? '-' : wo.locationCode}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 4),
            SelectableText(
              'Work order status: ${wo.status.isEmpty ? '-' : wo.status}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 4),
            if (item.requestedByName.trim().isNotEmpty)
              SelectableText(
                'Requester: ${item.requestedByName.trim()}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
              ),
            if (item.fromEngineerName.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              SelectableText(
                'Current owner: ${item.fromEngineerName.trim()}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
              ),
            ],
            if (item.toEngineerName.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              SelectableText(
                'Target engineer: ${item.toEngineerName.trim()}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
              ),
            ],
            if (item.reason.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectableText(
                'Reason: ${item.reason.trim()}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
              ),
            ],
            const SizedBox(height: 8),
            SelectableText(
              'Created: ${_formatDateTime(item.createdAt)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            if (item.decidedAt.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              SelectableText(
                'Decided: ${_formatDateTime(item.decidedAt)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            WorkOrderDetailPage(workOrderId: item.workOrderId),
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open work order'),
                ),
                if (_isIncoming && item.status.toUpperCase() == 'PENDING')
                  ElevatedButton.icon(
                    onPressed: () => _acceptRequest(item),
                    icon: const Icon(Icons.check),
                    label: const Text('Accept'),
                  ),
                if (_isIncoming && item.status.toUpperCase() == 'PENDING')
                  OutlinedButton.icon(
                    onPressed: () => _rejectRequest(item),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                  ),
                if (canCancel)
                  OutlinedButton.icon(
                    onPressed: () => _cancelRequest(item),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UserInfo user = LoginSessionController.instance.userInfo;
    final title = 'Transfer Requests';

    return Scaffold(
      drawer: AppDrawer(user: user),
      appBar: AppBar(
        title: Text(title),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SegmentedButton<TransferRequestPageMode>(
              segments: const [
                ButtonSegment<TransferRequestPageMode>(
                  value: TransferRequestPageMode.incoming,
                  icon: Icon(Icons.move_down_outlined, size: 18),
                  label: Text('Incoming'),
                ),
                ButtonSegment<TransferRequestPageMode>(
                  value: TransferRequestPageMode.outgoing,
                  icon: Icon(Icons.move_up_outlined, size: 18),
                  label: Text('Outgoing'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) {
                if (selection.isEmpty) return;
                _changeMode(selection.first);
              },
            ),
          ),
          const SizedBox(width: 20),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedStatus,
              items: _statuses
                  .map(
                    (status) =>
                        DropdownMenuItem(value: status, child: Text(status)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedStatus = value);
                _load(offset: 0);
              },
            ),
          ),
          IconButton(
            onPressed: () => _load(offset: _result.offset),
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _result.items.isEmpty
                ? const Center(
                    child: Text(
                      'No transfer requests.',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _result.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _buildRequestCard(_result.items[index]),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Text(
                    'Page $_currentPage · ${_result.offset + 1}-${_result.offset + _result.items.length} / ${_result.total}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _hasPreviousPage
                        ? () => _load(
                            offset: (_result.offset - _pageSize).clamp(
                              0,
                              _result.offset,
                            ),
                          )
                        : null,
                    child: const Text('Previous'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _hasNextPage
                        ? () => _load(offset: _result.offset + _pageSize)
                        : null,
                    child: const Text('Next'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
