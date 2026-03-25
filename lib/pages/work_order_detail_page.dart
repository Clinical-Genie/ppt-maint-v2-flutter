import 'dart:developer';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:maintapp/api/api_controller.dart';
import 'package:maintapp/model/work_order_attachment.dart';
import 'package:maintapp/model/work_order.dart';
import 'package:maintapp/model/work_order_history.dart';
import 'package:maintapp/model/user_info.dart';
import 'package:maintapp/pages/edit_work_order_page.dart';
import 'package:maintapp/pages/transfer_request_list_page.dart';
import 'package:maintapp/pages/work_order_report_pages.dart';
import 'package:maintapp/state/app_state.dart';
import 'package:maintapp/state/login_session_controller.dart';
import 'package:maintapp/widgets/pdf_embed_view.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

class WorkOrderDetailPage extends StatefulWidget {
  const WorkOrderDetailPage({required this.workOrderId, super.key});

  final String workOrderId;

  @override
  State<WorkOrderDetailPage> createState() => _WorkOrderDetailPageState();
}

class _WorkOrderDetailPageState extends State<WorkOrderDetailPage> {
  bool _isLoading = true;
  bool _isLoadingHistory = true;
  bool _isLoadingAttachments = true;
  bool _isOpeningAttachment = false;
  WorkOrder _workOrder = WorkOrder();
  WorkOrderHistoryResponse _history = WorkOrderHistoryResponse();
  List<WorkOrderAttachment> _attachments = [];
  bool _showDesktopAttachment = false;
  String _desktopAttachmentUrl = '';
  String _desktopAttachmentTitle = '';
  String _desktopAttachmentContentType = '';
  Map<String, String> _desktopAttachmentHeaders = const {};
  Uint8List? _desktopAttachmentBytes;
  final Set<String> _expandedHistoryIds = <String>{};
  bool _showHistory = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _isLoadingHistory = true;
      _isLoadingAttachments = true;
    });
    try {
      final order = await ApiController.getWorkOrderById(widget.workOrderId);
      final history = await ApiController.getWorkOrderHistory(
        widget.workOrderId,
      );
      final attachments = await ApiController.getWorkOrderAttachments(
        widget.workOrderId,
      );
      if (!mounted) return;
      setState(() {
        _workOrder = order;
        _history = history;
        _attachments = attachments.items;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingHistory = false;
          _isLoadingAttachments = false;
        });
      }
    }
  }

  bool _isDesktopSplitLayout(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1200;
  }

  bool _hasRole(String role) {
    return LoginSessionController.instance.userInfo.roles.any(
      (item) => item.toUpperCase() == role.toUpperCase(),
    );
  }

  bool get _hasManagerActions => _hasRole('MANAGER') || _hasRole('ADMIN');

  bool get _hasEngineerRole => _hasRole('ENGINEER');

  bool _isMine(WorkOrder order) {
    final currentUserId = LoginSessionController.instance.userInfo.id.trim();
    return currentUserId.isNotEmpty &&
        order.ownerUserId.trim() == currentUserId;
  }

  bool _isUnassigned(WorkOrder order) {
    final status = order.status.trim().toLowerCase();
    return order.ownerUserId.trim().isEmpty || status == 'unassigned';
  }

  bool _isAssignedToOthers(WorkOrder order) {
    final ownerUserId = order.ownerUserId.trim();
    final currentUserId = LoginSessionController.instance.userInfo.id.trim();
    return ownerUserId.isNotEmpty &&
        currentUserId.isNotEmpty &&
        ownerUserId != currentUserId;
  }

  bool get _canCreateTransferRequest {
    const allowedStatuses = {
      'assigned',
      'planned',
      'working',
      'cannot_completed',
    };
    return _hasRole('ENGINEER') &&
        _workOrder.ownerUserId.trim().isNotEmpty &&
        !_workOrder.isTransferring &&
        allowedStatuses.contains(_workOrder.status.trim().toLowerCase());
  }

  bool get _isCurrentEngineerOwner {
    return _workOrder.ownerUserId.trim().isNotEmpty &&
        _workOrder.ownerUserId.trim() ==
            LoginSessionController.instance.userInfo.id;
  }

  List<MapEntry<String, String>> get _availableTransferTargets {
    final currentUserId = LoginSessionController.instance.userInfo.id;
    final engineers = AppState.instance.activeEngineers.isNotEmpty
        ? AppState.instance.activeEngineers
        : AppState.instance.allUsers
              .where(
                (user) =>
                    user.isActive &&
                    user.roles.any((role) => role.toUpperCase() == 'ENGINEER'),
              )
              .toList();
    final items = engineers
        .where((user) => user.id != currentUserId)
        .map(
          (user) => MapEntry(
            user.id,
            user.fullName.trim().isNotEmpty
                ? user.fullName.trim()
                : user.username,
          ),
        )
        .where((entry) => entry.key.isNotEmpty && entry.value.trim().isNotEmpty)
        .toList();
    items.sort(
      (a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()),
    );
    return items;
  }

  Future<void> _openTransferRequestDialog() async {
    final reasonController = TextEditingController();
    final isHandoff = _isCurrentEngineerOwner;
    final targets = isHandoff
        ? _availableTransferTargets
        : const <MapEntry<String, String>>[];
    if (isHandoff && targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active engineers available.')),
      );
      return;
    }

    String selectedEngineerId = isHandoff
        ? targets.first.key
        : LoginSessionController.instance.userInfo.id;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool submitting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                isHandoff ? 'Transfer / Hand Off' : 'Request Takeover',
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isHandoff)
                      DropdownButtonFormField<String>(
                        initialValue: selectedEngineerId,
                        items: targets
                            .map(
                              (entry) => DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() => selectedEngineerId = value);
                        },
                        decoration: const InputDecoration(
                          labelText: 'Target engineer',
                          border: OutlineInputBorder(),
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(12),
                          color: const Color(0xFFF8FAFC),
                        ),
                        child: Text(
                          'This request will be sent to the current owner and target you as the new engineer.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
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
                      : () async {
                          final reason = reasonController.text.trim();
                          if (reason.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Reason is required.'),
                              ),
                            );
                            return;
                          }
                          setDialogState(() => submitting = true);
                          try {
                            await ApiController.createTransferRequest(
                              _workOrder.id,
                              toEngineerId: selectedEngineerId,
                              reason: reason,
                            );
                            if (!mounted) return;
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isHandoff
                                      ? 'Transfer request created.'
                                      : 'Takeover request created.',
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
                            if (dialogContext.mounted) {
                              setDialogState(() => submitting = false);
                            }
                          }
                        },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String?> _promptReason(String title, {bool required = true}) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
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
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = controller.text.trim();
                if (required && value.isEmpty) {
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
  }

  Future<String?> _promptEngineerId({
    required String title,
    String? excludeUserId,
  }) async {
    List<UserInfo> allEngineers = AppState.instance.activeEngineers
        .where(
          (user) =>
              user.roles.any((role) => role.toUpperCase() == 'ENGINEER') &&
              (excludeUserId == null || user.id != excludeUserId),
        )
        .toList();

    if (allEngineers.isEmpty) {
      try {
        final fetched = await ApiController.listUsers(
          role: 'ENGINEER',
          limit: 100,
          offset: 0,
          includeInactive: false,
        ).then((list) => list.items);
        AppState.instance.setUsers(activeEngineers: fetched, allUsers: fetched);
        allEngineers = fetched
            .where((user) => excludeUserId == null || user.id != excludeUserId)
            .toList();
      } catch (_) {}
    }

    allEngineers.sort((a, b) {
      final aLabel = a.fullName.trim().isEmpty ? a.username : a.fullName;
      final bLabel = b.fullName.trim().isEmpty ? b.username : b.fullName;
      return aLabel.toLowerCase().compareTo(bLabel.toLowerCase());
    });

    if (allEngineers.isEmpty) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active engineer available.')),
      );
      return null;
    }

    String selectedUserId = allEngineers.first.id;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: DropdownButtonFormField<String>(
                initialValue: selectedUserId,
                items: allEngineers
                    .map(
                      (user) => DropdownMenuItem<String>(
                        value: user.id,
                        child: Text(
                          user.fullName.trim().isEmpty
                              ? (user.username.trim().isEmpty
                                    ? user.id
                                    : user.username)
                              : user.fullName,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null || value.isEmpty) return;
                  setDialogState(() => selectedUserId = value);
                },
                decoration: const InputDecoration(
                  labelText: 'Engineer',
                  border: OutlineInputBorder(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(selectedUserId),
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<({DateTime plannedDate, String plannedHalfDay})?> _promptSchedule(
    String title,
  ) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (pickedDate == null || !mounted) {
      return null;
    }

    String selectedHalfDay = 'am';
    if (!mounted) return null;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Schedule session'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('AM'),
                        selected: selectedHalfDay == 'am',
                        onSelected: (_) => setDialogState(() {
                          selectedHalfDay = 'am';
                        }),
                      ),
                      ChoiceChip(
                        label: const Text('PM'),
                        selected: selectedHalfDay == 'pm',
                        onSelected: (_) => setDialogState(() {
                          selectedHalfDay = 'pm';
                        }),
                      ),
                      ChoiceChip(
                        label: const Text('Full day'),
                        selected: selectedHalfDay == 'full_day',
                        onSelected: (_) => setDialogState(() {
                          selectedHalfDay = 'full_day';
                        }),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(selectedHalfDay),
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || result.isEmpty) return null;
    return (plannedDate: pickedDate, plannedHalfDay: result);
  }

  Future<void> _editWorkOrder() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditWorkOrderPage(workOrderId: widget.workOrderId),
      ),
    );
    if (updated == true && mounted) {
      await _load();
    }
  }

  Future<void> _cancelWorkOrder() async {
    final reason = await _promptReason('Cancel work order');
    if (reason == null || reason.isEmpty) return;
    try {
      final message = await ApiController.cancelWorkOrder(
        widget.workOrderId,
        reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _performWorkOrderAction(String action) async {
    try {
      String feedback = '';
      if (action == 'open_incoming_transfers') {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const TransferRequestListPage(
              initialMode: TransferRequestPageMode.outgoing,
            ),
          ),
        );
        if (!mounted) return;
        await _load();
        return;
      } else if (action == 'assign_to_engineer') {
        final engineerId = await _promptEngineerId(title: 'Assign to engineer');
        if (engineerId == null || engineerId.isEmpty) return;
        final result = await ApiController.assignWorkOrder(
          _workOrder.id,
          targetUserId: engineerId,
          reason: 'Assign on demand.',
        );
        feedback = result.message.isNotEmpty ? result.message : 'Assigned.';
      } else if (action == 'revoke_to_unassigned') {
        final reason = await _promptReason('Return to public pool');
        if (reason == null || reason.isEmpty) return;
        feedback = await ApiController.releaseWorkOrder(_workOrder.id, reason);
      } else if (action == 'take') {
        feedback = await ApiController.pickWorkOrder(_workOrder.id);
      } else if (action == 'transfer_away' || action == 'transfer_to_me') {
        await _openTransferRequestDialog();
        return;
      } else if (action == 'release_to_unassigned') {
        final reason = await _promptReason('Return to public pool');
        if (reason == null || reason.isEmpty) return;
        feedback = await ApiController.releaseWorkOrder(_workOrder.id, reason);
      } else if (action == 'plan') {
        final picked = await _promptSchedule('Schedule work order');
        if (picked == null) return;
        feedback = await ApiController.planWorkOrder(
          _workOrder.id,
          plannedDate:
              '${picked.plannedDate.year}-${picked.plannedDate.month.toString().padLeft(2, '0')}-${picked.plannedDate.day.toString().padLeft(2, '0')}',
          plannedHalfDay: picked.plannedHalfDay == 'full_day'
              ? null
              : picked.plannedHalfDay,
        );
      } else if (action == 'cannot_complete') {
        final reason = await _promptReason('Cannot complete reason');
        if (reason == null || reason.isEmpty) return;
        feedback = await ApiController.markWorkOrderCannotCompleted(
          _workOrder.id,
          reason,
        );
      } else if (action == 'fill_report') {
        if (_workOrder.woType.trim().toUpperCase() != 'CM') {
          feedback = 'Only CM report is wired now.';
        } else {
          final updated = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => WorkOrderReportFormPage(workOrder: _workOrder),
            ),
          );
          if (updated == true) {
            await _load();
          }
          return;
        }
      } else if (action == 'sign') {
        final updated = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => WorkOrderSignPage(workOrder: _workOrder),
          ),
        );
        if (updated == true) {
          await _load();
        }
        return;
      } else if (action == 'view_report') {
        feedback = 'View Report page is not wired yet.';
      } else if (action == 'send_email') {
        feedback = 'Multiple-select send email is not wired yet.';
      } else if (action == 'start') {
        feedback = await ApiController.startWorkOrder(_workOrder.id);
      } else {
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(feedback)));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Action failed: $e')));
    }
  }

  List<MapEntry<String, String>> _buildDetailActions() {
    if (_workOrder.isTransferring) {
      if (_isCurrentEngineerOwner) {
        return const [MapEntry('open_incoming_transfers', 'Manage transfer')];
      }
      return const [];
    }

    final items = <MapEntry<String, String>>[];
    final normalizedStatus = _workOrder.status.trim().toLowerCase();

    if (_hasManagerActions) {
      if (_isUnassigned(_workOrder) || normalizedStatus == 'unassigned') {
        items.add(const MapEntry('assign_to_engineer', 'Assign to engineer'));
      } else if (normalizedStatus == 'assigned' ||
          normalizedStatus == 'planned' ||
          normalizedStatus == 'cannot_completed') {
        items.add(const MapEntry('assign_to_engineer', 'Assign to engineer'));
        items.add(
          const MapEntry('revoke_to_unassigned', 'Return to public pool'),
        );
      } else if (normalizedStatus == 'signed' ||
          normalizedStatus == 'signed_edited') {
        items.add(const MapEntry('view_report', 'View Report'));
      } else if (normalizedStatus == 'approved') {
        items.add(const MapEntry('send_email', 'Send email'));
      }
    }

    if (_hasEngineerRole) {
      if (_isUnassigned(_workOrder)) {
        items.add(const MapEntry('take', 'Take it'));
      } else if (_isMine(_workOrder)) {
        if (normalizedStatus == 'assigned' ||
            normalizedStatus == 'cannot_completed') {
          items.add(const MapEntry('plan', 'Schedule'));
          items.add(const MapEntry('start', 'Start work'));
          items.add(const MapEntry('transfer_away', 'Hand off'));
          if (!_hasManagerActions) {
            items.add(
              const MapEntry('release_to_unassigned', 'Return to public pool'),
            );
          }
        } else if (normalizedStatus == 'planned') {
          items.add(const MapEntry('plan', 'Re-schedule'));
          items.add(const MapEntry('start', 'Start work'));
          items.add(const MapEntry('transfer_away', 'Hand off'));
          if (!_hasManagerActions) {
            items.add(
              const MapEntry('release_to_unassigned', 'Return to public pool'),
            );
          }
        } else if (normalizedStatus == 'working') {
          items.add(const MapEntry('fill_report', 'Fill report'));
          items.add(const MapEntry('cannot_complete', 'Cannot complete'));
        } else if (normalizedStatus == 'completed') {
          items.add(const MapEntry('sign', 'Sign'));
        }
      } else if (_isAssignedToOthers(_workOrder)) {
        if (normalizedStatus == 'assigned' || normalizedStatus == 'planned') {
          items.add(const MapEntry('transfer_to_me', 'Take over'));
        }
      }
    }

    return items;
  }

  IconData _iconForActionButton(String action) {
    switch (action) {
      case 'assign_to_engineer':
        return Icons.person_add_alt_1_outlined;
      case 'revoke_to_unassigned':
      case 'release_to_unassigned':
        return Icons.undo_outlined;
      case 'take':
        return Icons.pan_tool_alt_outlined;
      case 'plan':
        return Icons.event_outlined;
      case 'start':
        return Icons.play_arrow_outlined;
      case 'transfer_away':
        return Icons.forward_to_inbox_outlined;
      case 'transfer_to_me':
        return Icons.move_down_outlined;
      case 'cannot_complete':
        return Icons.report_problem_outlined;
      case 'fill_report':
        return Icons.description_outlined;
      case 'sign':
        return Icons.draw_outlined;
      case 'view_report':
        return Icons.visibility_outlined;
      case 'send_email':
        return Icons.send_outlined;
      case 'open_incoming_transfers':
        return Icons.open_in_new;
      default:
        return Icons.playlist_add_check_circle_outlined;
    }
  }

  Widget _buildPendingTransferChip() {
    return const Chip(
      label: Text('Pending transfer'),
      backgroundColor: Color(0xFFFFF7ED),
      side: BorderSide(color: Color(0xFFFED7AA)),
      labelStyle: TextStyle(
        color: Color(0xFF9A3412),
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  Future<void> _openAttachment(
    String url,
    String title, {
    String contentType = '',
    bool preload = false,
  }) async {
    final resolvedUrl = ApiController.resolveServerUrl(url);
    if (resolvedUrl.isEmpty) return;
    final uri = Uri.tryParse(resolvedUrl);
    if (uri == null) return;

    setState(() {
      _isOpeningAttachment = true;
    });

    try {
      await LoginSessionController.instance.refreshTokenIfNeeded();
      final token = LoginSessionController.instance.loginInfo.accessToken;
      if (token.isEmpty) {
        throw Exception('Login expired. Please sign in again.');
      }

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      log(
        "url: $url, resolvedUrl: $resolvedUrl, statusCode: ${response.statusCode}, contentType: ${response.headers['content-type']}",
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Open attachment failed (${response.statusCode}): ${response.reasonPhrase ?? 'Request error'}',
        );
      }
      if (response.bodyBytes.isEmpty) {
        throw Exception('Attachment returned empty data.');
      }

      final attachmentBytes = Uint8List.fromList(response.bodyBytes);

      if (_isDesktopSplitLayout(context)) {
        if (!mounted) return;
        setState(() {
          _showDesktopAttachment = true;
          _desktopAttachmentUrl = uri.toString();
          _desktopAttachmentTitle = title;
          _desktopAttachmentContentType = contentType;
          _desktopAttachmentHeaders = {'Authorization': 'Bearer $token'};
          _desktopAttachmentBytes = attachmentBytes;
        });
        return;
      }

      if (kIsWeb) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _WebAttachmentViewerPage(
              fileName: title,
              fileBytes: attachmentBytes,
              contentType: contentType,
            ),
          ),
        );
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _AttachmentViewerPage(
            pdfBytes: attachmentBytes,
            networkUrl: uri.toString(),
            networkHeaders: {'Authorization': 'Bearer $token'},
            fileName: title,
            contentType: contentType,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(preload ? 'Attachment preview unavailable.' : '$e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isOpeningAttachment = false);
      }
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

  bool _isOwnerInactive() {
    final ownerUserId = _workOrder.ownerUserId.trim();
    if (ownerUserId.isEmpty) return false;
    for (final user in AppState.instance.allUsers) {
      if (user.id == ownerUserId) {
        return !user.isActive;
      }
    }
    return false;
  }

  String _ownerDisplayName() {
    if (_workOrder.ownerFullName.trim().isNotEmpty) {
      return _workOrder.ownerFullName.trim();
    }
    final ownerUserId = _workOrder.ownerUserId.trim();
    if (ownerUserId.isEmpty) return '';
    for (final user in AppState.instance.allUsers) {
      if (user.id == ownerUserId) {
        if (user.fullName.trim().isNotEmpty) return user.fullName.trim();
        if (user.username.trim().isNotEmpty) return user.username.trim();
      }
    }
    return ownerUserId;
  }

  String _userNameById(String userId) {
    final trimmed = userId.trim();
    if (trimmed.isEmpty) return '';
    for (final user in AppState.instance.allUsers) {
      if (user.id == trimmed) {
        if (user.fullName.trim().isNotEmpty) return user.fullName.trim();
        if (user.username.trim().isNotEmpty) return user.username.trim();
      }
    }
    return trimmed;
  }

  Widget _buildField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
        if (label.isNotEmpty) const SizedBox(height: 4),
        SelectableText(
          value.trim().isEmpty ? '-' : value.trim(),
          style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
        ),
      ],
    );
  }

  String _contactDisplay() {
    final name = _workOrder.contactName.trim();
    final number = _workOrder.contactNumber.trim();
    if (name.isNotEmpty && number.isNotEmpty) {
      return '$name ($number)';
    }
    if (name.isNotEmpty) return name;
    if (number.isNotEmpty) return number;
    return '-';
  }

  String _issueDisplay() {
    final description = _workOrder.description.trim();
    final remark = _workOrder.remark.trim();
    if (description.isNotEmpty && remark.isNotEmpty) {
      return '$description\nRemark: $remark';
    }
    if (description.isNotEmpty) return description;
    if (remark.isNotEmpty) return 'Remark: $remark';
    return '-';
  }

  String _statusDisplay() {
    final status = _workOrder.status.trim();
    if (status.toLowerCase() != 'planned') {
      return status.isEmpty ? '-' : status;
    }

    final rawPlannedDate = _workOrder.plannedDate.trim();
    final plannedDate = rawPlannedDate.contains('T')
        ? rawPlannedDate.split('T').first.trim()
        : rawPlannedDate;
    final plannedHalfDay = _workOrder.plannedHalfDay.trim().toUpperCase();
    if (plannedDate.isEmpty) {
      return status;
    }
    final plannedLabel = plannedHalfDay == 'AM' || plannedHalfDay == 'PM'
        ? '$plannedDate $plannedHalfDay'
        : plannedDate;
    return '$status\n($plannedLabel)';
  }

  Widget _buildLocationField() {
    final locationCode = _workOrder.locationCode.trim();
    final idx = locationCode.indexOf('-');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Location',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 4),
        if (locationCode.isEmpty)
          const SelectableText(
            '-',
            style: TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
          )
        else if (idx <= 0)
          SelectableText(
            locationCode,
            style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
          )
        else
          SelectableText.rich(
            TextSpan(
              style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
              children: [
                TextSpan(
                  text: locationCode.substring(0, idx),
                  style: const TextStyle(
                    color: Color(0xFF1D4ED8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(text: locationCode.substring(idx)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildOverviewEngineerField() {
    final ownerName = _ownerDisplayName();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isOwnerInactive())
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(Icons.close, size: 14, color: Color(0xFFB91C1C)),
          ),
        Flexible(
          child: SelectableText(
            ownerName.isEmpty ? '-' : ownerName,
            style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      color: Colors.white,
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentsSection() {
    final attachmentButtons = <Widget>[
      if (_workOrder.sourceFileUrl.isNotEmpty)
        ElevatedButton(
          onPressed: _isOpeningAttachment
              ? null
              : () => _openAttachment(
                  _workOrder.sourceFileUrl,
                  _workOrder.sourceFileName.isEmpty
                      ? 'Source PDF'
                      : _workOrder.sourceFileName,
                  contentType: 'application/pdf',
                ),
          child: const Text('Source PDF'),
        ),
      if (_workOrder.mergedPdfUrl.isNotEmpty)
        ElevatedButton(
          onPressed: _isOpeningAttachment
              ? null
              : () => _openAttachment(
                  _workOrder.mergedPdfUrl,
                  '${_workOrder.referenceNumber} merged.pdf',
                  contentType: 'application/pdf',
                ),
          child: const Text('Merged PDF'),
        ),
      ..._attachments
          .where((attachment) => attachment.fileUrl.trim().isNotEmpty)
          .map(
            (attachment) => ElevatedButton(
              onPressed: _isOpeningAttachment
                  ? null
                  : () => _openAttachment(
                      attachment.fileUrl,
                      attachment.displayLabel,
                      contentType: attachment.contentType,
                    ),
              child: Text(attachment.displayLabel),
            ),
          ),
    ];

    return _buildSection(
      title: 'Attachments',
      children: [
        if (_isLoadingAttachments)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: CircularProgressIndicator(),
          )
        else if (attachmentButtons.isEmpty)
          const Text(
            'No attachments are available for this work order yet.',
            style: TextStyle(color: Color(0xFF64748B)),
          )
        else
          Wrap(spacing: 8, runSpacing: 8, children: attachmentButtons),
      ],
    );
  }

  IconData _iconForHistoryAction(String action) {
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
      case 'transfer_requested':
        return Icons.forward_to_inbox_outlined;
      case 'transfer_accepted':
        return Icons.assignment_turned_in_outlined;
      case 'transfer_rejected':
        return Icons.person_off_outlined;
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

  String _historyActionTitle(WorkOrderHistoryEntry item) {
    final action = item.action.trim();
    if (action.isEmpty) return 'History';
    switch (action) {
      case 'transfer_requested':
        return 'Transfer requested';
      case 'transfer_accepted':
        return 'Transfer accepted';
      case 'transfer_rejected':
        return 'Transfer rejected';
    }
    final words = action
        .split('_')
        .where((part) => part.trim().isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .toList();
    return words.join(' ');
  }

  String _historyActorAndTime(WorkOrderHistoryEntry item) {
    final timeText = _formatDateTime(item.createdAt);
    final actorName = item.actorNameSnapshot.trim();
    if (actorName.isEmpty) return timeText;
    return '$actorName • $timeText';
  }

  String _historyStatusChangeText(WorkOrderHistoryEntry item) {
    final fromStatus = item.fromStatus.trim();
    final toStatus = item.toStatus.trim();
    if (fromStatus.isEmpty || toStatus.isEmpty || fromStatus == toStatus) {
      return '';
    }
    return '$fromStatus -> $toStatus';
  }

  List<String> _historyDetailLines(WorkOrderHistoryEntry item) {
    final lines = <String>[];
    final details = item.detailsJson;

    if (item.action == 'created') {
      final woNumber =
          '${details['wo_no'] ?? details['reference_number'] ?? _workOrder.referenceNumber}'
              .trim();
      if (woNumber.isNotEmpty) {
        lines.add('WO Number: $woNumber');
      }
    }

    if (item.action == 'source_file_uploaded') {
      final sourceFileName =
          '${details['source_file_name'] ?? details['file_name'] ?? details['name'] ?? ''}'
              .trim();
      if (sourceFileName.isNotEmpty) {
        lines.add('Source file: $sourceFileName');
      }
    }

    if (item.action == 'assigned') {
      final assignedEngineerId =
          '${details['assigned_engineer_id'] ?? details['target_user_id'] ?? ''}'
              .trim();
      if (assignedEngineerId.isNotEmpty) {
        final assignedEngineerName = _userNameById(assignedEngineerId);
        if (assignedEngineerName.isNotEmpty) {
          lines.add('Assigned to: $assignedEngineerName');
        }
      }
    }

    if (item.action == 'transfer_requested') {
      final toEngineerId =
          '${details['to_engineer_id'] ?? details['toEngineerId'] ?? ''}'
              .trim();
      if (toEngineerId.isNotEmpty) {
        final name = _userNameById(toEngineerId);
        if (name.isNotEmpty) {
          lines.add('Requested to: $name');
        }
      }
    }

    final reason = '${details['reason'] ?? ''}'.trim();
    if (reason.isNotEmpty) {
      lines.add('Reason: $reason');
    }

    return lines;
  }

  Widget _buildHistorySection() {
    final items = _history.items;
    return _buildSection(
      title: 'History',
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() => _showHistory = !_showHistory);
            },
            icon: Icon(
              _showHistory
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
            ),
            label: Text(_showHistory ? 'Hide history' : 'Show history'),
          ),
        ),
        if (_showHistory) ...[
          const SizedBox(height: 12),
          if (_isLoadingHistory)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: CircularProgressIndicator(),
            )
          else if (items.isEmpty)
            const Text(
              'No history records.',
              style: TextStyle(color: Color(0xFF64748B)),
            )
          else ...[
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(height: 20),
              Builder(
                builder: (context) {
                  final item = items[i];
                  final detailLines = _historyDetailLines(item);
                  final statusChangeText = _historyStatusChangeText(item);
                  final hasRawDetails = item.detailsJson.isNotEmpty;
                  final isExpanded = _expandedHistoryIds.contains(item.id);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              _historyActionTitle(item),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (hasRawDetails)
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                tooltip: isExpanded
                                    ? 'Hide details'
                                    : 'Show details',
                                onPressed: () {
                                  setState(() {
                                    if (isExpanded) {
                                      _expandedHistoryIds.remove(item.id);
                                    } else {
                                      _expandedHistoryIds.add(item.id);
                                    }
                                  });
                                },
                                icon: Icon(
                                  isExpanded ? Icons.close : Icons.more_horiz,
                                  size: 18,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (item.displaySummary.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        SelectableText(
                          item.displaySummary,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        _historyActorAndTime(item),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      if (statusChangeText.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        SelectableText(
                          statusChangeText,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                      ],
                      for (final line in detailLines) ...[
                        const SizedBox(height: 6),
                        SelectableText(
                          line,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                      if (hasRawDetails && isExpanded) ...[
                        const SizedBox(height: 8),
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
                    ],
                  );
                },
              ),
            ],
          ],
        ],
      ],
    );
  }

  Widget _buildDesktopAttachmentPanel({required double height}) {
    return Card(
      color: Colors.white,
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        height: height,
        child: _showDesktopAttachment && _desktopAttachmentUrl.isNotEmpty
            ? Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _desktopAttachmentTitle.isEmpty
                                ? 'Attachment'
                                : _desktopAttachmentTitle,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _showDesktopAttachment = false;
                              _desktopAttachmentUrl = '';
                              _desktopAttachmentTitle = '';
                              _desktopAttachmentContentType = '';
                              _desktopAttachmentHeaders = const {};
                              _desktopAttachmentBytes = null;
                            });
                          },
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: kIsWeb
                          ? (_desktopAttachmentBytes == null
                                ? const Center(
                                    child: Text(
                                      'Unable to load attachment preview.',
                                    ),
                                  )
                                : _InlineAttachmentPreview(
                                    bytes: _desktopAttachmentBytes!,
                                    contentType: _desktopAttachmentContentType,
                                  ))
                          : _EmbeddedAttachmentViewer(
                              networkUrl: _desktopAttachmentUrl,
                              memoryBytes: _desktopAttachmentBytes,
                              contentType: _desktopAttachmentContentType,
                              networkHeaders: _desktopAttachmentHeaders,
                            ),
                    ),
                  ),
                ],
              )
            : const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Open an attachment to preview it here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
                  ),
                ),
              ),
      ),
    );
  }

  List<Widget> _buildSectionCards() {
    return [
      _buildSection(
        title: 'Overview',
        children: [
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              SizedBox(
                width: 160,
                child: _buildField('Status', _statusDisplay()),
              ),
              SizedBox(
                width: 160,
                child: _buildField('Priority', _workOrder.priority),
              ),
              SizedBox(
                width: 160,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Engineer',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildOverviewEngineerField(),
                  ],
                ),
              ),
            ],
          ),
          if (_workOrder.isTransferring) ...[
            const SizedBox(height: 14),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Transfer request pending',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9A3412),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: _buildPendingTransferChip(),
            ),
            const SizedBox(height: 8),
            if (_isCurrentEngineerOwner)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _performWorkOrderAction('open_incoming_transfers'),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Manage transfer'),
                ),
              ),
          ],
          if (_buildDetailActions().isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _buildDetailActions()
                  .map(
                    (item) => OutlinedButton.icon(
                      onPressed: () => _performWorkOrderAction(item.key),
                      icon: Icon(_iconForActionButton(item.key)),
                      label: Text(item.value),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (_hasManagerActions) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _editWorkOrder,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit Work Order'),
                ),
                OutlinedButton.icon(
                  onPressed: _cancelWorkOrder,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel WO'),
                ),
              ],
            ),
          ],
        ],
      ),
      _buildAttachmentsSection(),
      _buildSection(
        title: 'Location & Contact',
        children: [
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              SizedBox(width: 160, child: _buildLocationField()),
              SizedBox(
                width: 220,
                child: _buildField('Contact', _contactDisplay()),
              ),
            ],
          ),
        ],
      ),
      _buildSection(
        title: 'Device',
        children: [
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              SizedBox(
                width: 160,
                child: _buildField(
                  'Device',
                  [
                    if (_workOrder.deviceBrand.trim().isNotEmpty)
                      _workOrder.deviceBrand.trim(),
                    if (_workOrder.deviceModel.trim().isNotEmpty)
                      _workOrder.deviceModel.trim(),
                  ].join(' - '),
                ),
              ),
              SizedBox(
                width: 160,
                child: _buildField('Asset Number', _workOrder.assetNumber),
              ),
              SizedBox(
                width: 160,
                child: _buildField('Serial Number', _workOrder.serialNumber),
              ),
            ],
          ),
        ],
      ),
      _buildSection(
        title: 'Issue',
        children: [_buildField('', _issueDisplay())],
      ),
      _buildSection(
        title: 'Dates',
        children: [
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              if (_workOrder.woType.toUpperCase() == 'CM')
                SizedBox(
                  width: 160,
                  child: _buildField(
                    'Breakdown',
                    _formatDateTime(_workOrder.cmBreakdownAt),
                  ),
                ),
              SizedBox(
                width: 160,
                child: _buildField(
                  'HA Created',
                  _formatDateTime(_workOrder.haCreatedAt),
                ),
              ),
              SizedBox(
                width: 160,
                child: _buildField(
                  'HA Outbound',
                  _formatDateTime(_workOrder.haOutboundAt),
                ),
              ),
              if (_workOrder.woType.toUpperCase() == 'PM')
                SizedBox(
                  width: 200,
                  child: _buildField(
                    'PM Deadline',
                    _formatDateTime(_workOrder.pmDeadlineAt),
                  ),
                ),
            ],
          ),
        ],
      ),
      _buildHistorySection(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _workOrder.referenceNumber.isEmpty
              ? 'Work Order Detail'
              : _workOrder.woType.trim().isEmpty
              ? _workOrder.referenceNumber
              : '${_workOrder.referenceNumber} (${_workOrder.woType.trim().toUpperCase()})',
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final sections = _buildSectionCards();
                final useDesktopSplit =
                    _isDesktopSplitLayout(context) && _showDesktopAttachment;

                Widget detailContent = RefreshIndicator(
                  onRefresh: _load,
                  child: LayoutBuilder(
                    builder: (context, innerConstraints) {
                      final useTwoColumns = innerConstraints.maxWidth >= 1100;

                      if (!useTwoColumns) {
                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: sections.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 16),
                          itemBuilder: (_, index) => sections[index],
                        );
                      }

                      final leftColumn = <Widget>[
                        sections[0],
                        sections[1],
                        sections[2],
                        sections[3],
                      ];
                      final rightColumn = <Widget>[
                        sections[4],
                        sections[5],
                        sections[6],
                      ];

                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (
                                    int i = 0;
                                    i < leftColumn.length;
                                    i++
                                  ) ...[
                                    if (i > 0) const SizedBox(height: 16),
                                    leftColumn[i],
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (
                                    int i = 0;
                                    i < rightColumn.length;
                                    i++
                                  ) ...[
                                    if (i > 0) const SizedBox(height: 16),
                                    rightColumn[i],
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );

                if (!useDesktopSplit) {
                  return detailContent;
                }

                final panelHeight = constraints.maxHeight;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: panelHeight > 0 ? panelHeight : null,
                        child: detailContent,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDesktopAttachmentPanel(
                        height: panelHeight > 0 ? panelHeight : 860,
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _EmbeddedAttachmentViewer extends StatefulWidget {
  const _EmbeddedAttachmentViewer({
    required this.networkUrl,
    required this.contentType,
    this.memoryBytes,
    required this.networkHeaders,
  });

  final String networkUrl;
  final String contentType;
  final Uint8List? memoryBytes;
  final Map<String, String> networkHeaders;

  @override
  State<_EmbeddedAttachmentViewer> createState() =>
      _EmbeddedAttachmentViewerState();
}

class _EmbeddedAttachmentViewerState extends State<_EmbeddedAttachmentViewer> {
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final isImage = widget.contentType.toLowerCase().startsWith('image/');
    final hasMemorySource =
        widget.memoryBytes != null && widget.memoryBytes!.isNotEmpty;
    return SfTheme(
      data: SfThemeData(
        pdfViewerThemeData: SfPdfViewerThemeData(backgroundColor: Colors.white),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: Colors.white,
          child: _errorMessage == null
              ? isImage
                    ? Center(
                        child: InteractiveViewer(
                          child: hasMemorySource
                              ? Image.memory(widget.memoryBytes!)
                              : Image.network(
                                  widget.networkUrl,
                                  headers: widget.networkHeaders,
                                  errorBuilder: (_, __, ___) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (!mounted) return;
                                          setState(() {
                                            _errorMessage =
                                                'Unable to load attachment.';
                                          });
                                        });
                                    return const SizedBox.shrink();
                                  },
                                ),
                        ),
                      )
                    : (hasMemorySource
                          ? SfPdfViewer.memory(
                              widget.memoryBytes!,
                              onDocumentLoadFailed: (details) {
                                setState(() {
                                  final rawMessage =
                                      '${details.error} ${details.description}'
                                          .trim();
                                  _errorMessage = rawMessage.isEmpty
                                      ? 'Unable to load attachment.'
                                      : rawMessage;
                                });
                              },
                            )
                          : SfPdfViewer.network(
                              widget.networkUrl,
                              headers: widget.networkHeaders,
                              onDocumentLoadFailed: (details) {
                                setState(() {
                                  final rawMessage =
                                      '${details.error} ${details.description}'
                                          .trim();
                                  _errorMessage = rawMessage.isEmpty
                                      ? 'Unable to load attachment.'
                                      : rawMessage;
                                });
                              },
                            ))
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _WebAttachmentViewerPage extends StatelessWidget {
  const _WebAttachmentViewerPage({
    required this.fileName,
    required this.fileBytes,
    required this.contentType,
  });

  final String fileName;
  final Uint8List fileBytes;
  final String contentType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(fileName.isEmpty ? 'View Attachment' : fileName),
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            color: Colors.white,
            child: _InlineAttachmentPreview(
              bytes: fileBytes,
              contentType: contentType,
            ),
          ),
        ),
      ),
    );
  }
}

class _AttachmentViewerPage extends StatefulWidget {
  const _AttachmentViewerPage({
    this.pdfBytes,
    this.networkUrl,
    this.networkHeaders,
    required this.fileName,
    required this.contentType,
  });

  final Uint8List? pdfBytes;
  final String? networkUrl;
  final Map<String, String>? networkHeaders;
  final String fileName;
  final String contentType;
  bool get hasNetworkSource => networkUrl != null && networkUrl!.isNotEmpty;
  bool get hasMemorySource => pdfBytes != null && pdfBytes!.isNotEmpty;

  @override
  State<_AttachmentViewerPage> createState() => _AttachmentViewerPageState();
}

class _AttachmentViewerPageState extends State<_AttachmentViewerPage> {
  String? _errorMessage;
  bool _openingFallback = false;

  @override
  Widget build(BuildContext context) {
    Widget viewer = const SizedBox.shrink();
    final isImage = widget.contentType.toLowerCase().startsWith('image/');
    if (_errorMessage == null) {
      if (isImage && widget.hasMemorySource) {
        viewer = Center(
          child: InteractiveViewer(child: Image.memory(widget.pdfBytes!)),
        );
      } else if (widget.hasMemorySource && !isImage) {
        viewer = SfPdfViewer.memory(
          widget.pdfBytes!,
          onDocumentLoadFailed: (details) {
            setState(() {
              final rawMessage = '${details.error} ${details.description}'
                  .trim();
              _errorMessage = rawMessage.isEmpty
                  ? 'Unable to load attachment.'
                  : rawMessage;
            });
          },
        );
      } else if (widget.hasNetworkSource && !kIsWeb && !isImage) {
        viewer = SfPdfViewer.network(
          widget.networkUrl!,
          headers: widget.networkHeaders,
          onDocumentLoadFailed: (details) {
            setState(() {
              final rawMessage = '${details.error} ${details.description}'
                  .trim();
              _errorMessage = rawMessage.isEmpty
                  ? 'Unable to load attachment.'
                  : rawMessage;
            });
          },
        );
      } else {
        viewer = const Center(
          child: Text('No attachment source is available.'),
        );
      }
    } else {
      viewer = Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SelectableText(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _openingFallback ? null : _openWithSystemViewer,
                icon: _openingFallback
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.launch),
                label: const Text('Open file in system viewer'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.fileName.isEmpty ? 'View Attachment' : widget.fileName,
        ),
      ),
      backgroundColor: Colors.white,
      body: SfTheme(
        data: SfThemeData(
          pdfViewerThemeData: SfPdfViewerThemeData(
            backgroundColor: Colors.white,
          ),
        ),
        child: Container(color: Colors.white, child: viewer),
      ),
      floatingActionButton: _errorMessage == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
    );
  }

  Future<void> _openWithSystemViewer() async {
    setState(() {
      _openingFallback = true;
    });
    try {
      Uint8List? sourceBytes = widget.pdfBytes;

      if (kIsWeb) {
        if (sourceBytes == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No file bytes available to open locally.'),
            ),
          );
          return;
        }
        final dataUri = Uri.dataFromBytes(
          sourceBytes,
          mimeType: widget.contentType.isEmpty
              ? 'application/octet-stream'
              : widget.contentType,
        );
        final launched = await launchUrl(
          dataUri,
          mode: LaunchMode.platformDefault,
        );
        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No app found to open file.')),
          );
        }
        return;
      }

      if (widget.pdfBytes == null && widget.hasNetworkSource) {
        final uri = Uri.parse(widget.networkUrl!);
        final response = await http.get(uri, headers: widget.networkHeaders);
        if (response.statusCode != 200) {
          throw Exception(
            'Open attachment failed (${response.statusCode}): ${response.reasonPhrase ?? 'Request error'}',
          );
        }
        sourceBytes = Uint8List.fromList(response.bodyBytes);
      } else if (widget.pdfBytes != null) {
        sourceBytes = widget.pdfBytes;
      }

      if (sourceBytes == null || sourceBytes.isEmpty) {
        throw Exception('No attachment content available.');
      }

      final dataUri = Uri.dataFromBytes(
        sourceBytes,
        mimeType: widget.contentType.isEmpty
            ? 'application/octet-stream'
            : widget.contentType,
      );
      final launched = await launchUrl(
        dataUri,
        mode: LaunchMode.platformDefault,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No app found to open file.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open file locally: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _openingFallback = false;
        });
      }
    }
  }
}

class _InlineAttachmentPreview extends StatelessWidget {
  const _InlineAttachmentPreview({
    required this.bytes,
    required this.contentType,
  });

  final Uint8List bytes;
  final String contentType;

  @override
  Widget build(BuildContext context) {
    if (contentType.toLowerCase().startsWith('image/')) {
      return Center(child: InteractiveViewer(child: Image.memory(bytes)));
    }
    return PdfEmbedView(bytes: bytes);
  }
}
