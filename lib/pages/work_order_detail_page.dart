import 'dart:developer';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:maintapp/api/api_controller.dart';
import 'package:maintapp/model/work_order_attachment.dart';
import 'package:maintapp/model/work_order.dart';
import 'package:maintapp/model/work_order_form.dart';
import 'package:maintapp/model/work_order_history.dart';
import 'package:maintapp/model/user_info.dart';
import 'package:maintapp/pages/edit_work_order_page.dart';
import 'package:maintapp/pages/transfer_request_list_page.dart';
import 'package:maintapp/pages/work_order_report_pages.dart';
import 'package:maintapp/pages/work_order_report_sign_page.dart';
import 'package:maintapp/state/app_state.dart';
import 'package:maintapp/state/login_session_controller.dart';
import 'package:maintapp/widgets/work_order_pdf_viewer.dart';

class WorkOrderDetailPage extends StatefulWidget {
  const WorkOrderDetailPage({required this.workOrderId, super.key});

  final String workOrderId;

  @override
  State<WorkOrderDetailPage> createState() => _WorkOrderDetailPageState();
}

class _WorkOrderDetailPageState extends State<WorkOrderDetailPage> {
  static const List<String> _allowedAttachmentExtensions = [
    'pdf',
    'png',
    'jpg',
    'jpeg',
    'gif',
    'webp',
    'heic',
    'heif',
  ];
  bool _isLoading = true;
  bool _isLoadingHistory = true;
  bool _isLoadingAttachments = true;
  bool _isOpeningAttachment = false;
  bool _isMutatingAttachment = false;
  WorkOrder _workOrder = WorkOrder();
  WorkOrderForm _workOrderForm = WorkOrderForm();
  WorkOrderHistoryResponse _history = WorkOrderHistoryResponse();
  List<WorkOrderAttachment> _attachments = [];
  String _attachmentAccessMessage = '';
  bool _showDesktopAttachment = false;
  String _desktopAttachmentUrl = '';
  String _desktopAttachmentTitle = '';
  String _desktopAttachmentDescription = '';
  String _desktopAttachmentContentType = '';
  Map<String, String> _desktopAttachmentHeaders = const {};
  Uint8List? _desktopAttachmentBytes;
  final Set<String> _expandedHistoryIds = <String>{};
  bool _showHistory = false;
  int _overlaySuspendDepth = 0;

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
      _attachmentAccessMessage = '';
    });
    try {
      final order = await ApiController.getWorkOrderById(widget.workOrderId);
      final history = await ApiController.getWorkOrderHistory(
        widget.workOrderId,
      );
      final canViewAttachments = _canViewAttachments(order);
      final attachments = canViewAttachments
          ? await ApiController.getWorkOrderAttachments(
              widget.workOrderId,
              showError: false,
            )
          : WorkOrderAttachmentList();
      WorkOrderForm form = WorkOrderForm();
      try {
        form = await ApiController.getWorkOrderForm(widget.workOrderId);
      } catch (_) {
        form = WorkOrderForm();
      }
      if (!mounted) return;
      setState(() {
        _workOrder = order;
        _workOrderForm = form;
        _history = history;
        _attachments = attachments.items;
        _attachmentAccessMessage = canViewAttachments
            ? ''
            : 'You do not have permission to view attachments for this work order.';
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

  Future<void> _reloadAttachmentAndHistory() async {
    if (!mounted) return;
    setState(() {
      _isLoadingHistory = true;
      _isLoadingAttachments = true;
      _attachmentAccessMessage = '';
    });

    try {
      final history = await ApiController.getWorkOrderHistory(
        widget.workOrderId,
      );
      final canViewAttachments = _canViewAttachments(_workOrder);
      final attachments = canViewAttachments
          ? await ApiController.getWorkOrderAttachments(
              widget.workOrderId,
              showError: false,
            )
          : WorkOrderAttachmentList();

      if (!mounted) return;
      setState(() {
        _history = history;
        _attachments = attachments.items;
        _attachmentAccessMessage = canViewAttachments
            ? ''
            : 'You do not have permission to view attachments for this work order.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
          _isLoadingAttachments = false;
        });
      }
    }
  }

  bool _isDesktopSplitLayout(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1200;
  }

  void _closeDesktopAttachmentViewer() {
    _showDesktopAttachment = false;
    _desktopAttachmentUrl = '';
    _desktopAttachmentTitle = '';
    _desktopAttachmentDescription = '';
    _desktopAttachmentContentType = '';
    _desktopAttachmentHeaders = const {};
    _desktopAttachmentBytes = null;
  }

  bool get _suspendWebPdfPreview => kIsWeb && _overlaySuspendDepth > 0;

  Future<T?> _runWithOverlaySuspended<T>(Future<T?> Function() action) async {
    if (!kIsWeb) {
      return action();
    }
    if (mounted) {
      setState(() {
        _overlaySuspendDepth += 1;
      });
    }
    try {
      return await action();
    } finally {
      if (mounted) {
        setState(() {
          _overlaySuspendDepth = (_overlaySuspendDepth - 1).clamp(0, 9999);
        });
      }
    }
  }

  bool _hasRole(String role) {
    return LoginSessionController.instance.userInfo.roles.any(
      (item) => item.toUpperCase() == role.toUpperCase(),
    );
  }

  bool get _hasManagerActions => _hasRole('MANAGER') || _hasRole('ADMIN');

  bool get _hasOfficeAdminRole => _hasRole('MANAGER');

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

  bool get _isCurrentEngineerOwner {
    return _workOrder.ownerUserId.trim().isNotEmpty &&
        _workOrder.ownerUserId.trim() ==
            LoginSessionController.instance.userInfo.id;
  }

  bool _canViewAttachments(WorkOrder order) {
    if (_hasManagerActions) {
      return order.status.trim().toLowerCase() != 'cancelled';
    }
    return _hasEngineerRole && _isMine(order);
  }

  bool get _managerCanMutateAttachments =>
      _hasManagerActions &&
      _workOrder.status.trim().toLowerCase() != 'cancelled';

  bool get _engineerOwnerCanAddAttachmentWithoutReason {
    const allowedStatuses = {
      'assigned',
      'planned',
      'working',
      'completed',
      'cannot_completed',
    };
    return _hasEngineerRole &&
        _isMine(_workOrder) &&
        allowedStatuses.contains(_workOrder.status.trim().toLowerCase());
  }

  bool get _engineerOwnerCanAddAttachmentWithReason {
    return _hasEngineerRole &&
        _isMine(_workOrder) &&
        _workOrder.status.trim().toLowerCase() == 'signed';
  }

  bool get _canAddAttachment =>
      _managerCanMutateAttachments ||
      _engineerOwnerCanAddAttachmentWithoutReason ||
      _engineerOwnerCanAddAttachmentWithReason;

  bool get _addAttachmentRequiresReason =>
      !_managerCanMutateAttachments && _engineerOwnerCanAddAttachmentWithReason;

  bool get _engineerOwnerCanDeleteAttachment {
    const allowedStatuses = {
      'assigned',
      'planned',
      'working',
      'cannot_completed',
      'completed',
      'signed',
    };
    return _hasEngineerRole &&
        _isMine(_workOrder) &&
        allowedStatuses.contains(_workOrder.status.trim().toLowerCase());
  }

  bool get _canDeleteAttachment =>
      _managerCanMutateAttachments || _engineerOwnerCanDeleteAttachment;

  bool get _deleteAttachmentRequiresReason =>
      !_managerCanMutateAttachments && _engineerOwnerCanDeleteAttachment;

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

    await _runWithOverlaySuspended(
      () => showDialog<void>(
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
      ),
    );
  }

  Future<String?> _promptReason(String title, {bool required = true}) async {
    final controller = TextEditingController();
    return _runWithOverlaySuspended(
      () => showDialog<String>(
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
      ),
    );
  }

  String _contentTypeForAttachmentName(String filename) {
    final normalized = filename.trim().toLowerCase();
    if (normalized.endsWith('.pdf')) return 'application/pdf';
    if (normalized.endsWith('.png')) return 'image/png';
    if (normalized.endsWith('.jpg') || normalized.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (normalized.endsWith('.gif')) return 'image/gif';
    if (normalized.endsWith('.webp')) return 'image/webp';
    if (normalized.endsWith('.heic')) return 'image/heic';
    if (normalized.endsWith('.heif')) return 'image/heif';
    return 'application/octet-stream';
  }

  bool get _useMobileAttachmentSourcePicker {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  Future<String?> _promptAttachmentSource() async {
    return _runWithOverlaySuspended(
      () => showModalBottomSheet<String>(
        context: context,
        builder: (sheetContext) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Photo Album'),
                  onTap: () => Navigator.of(sheetContext).pop('photo_album'),
                ),
                ListTile(
                  leading: const Icon(Icons.folder_open_outlined),
                  title: const Text('Files'),
                  onTap: () => Navigator.of(sheetContext).pop('files'),
                ),
                ListTile(
                  leading: const Icon(Icons.close),
                  title: const Text('Cancel'),
                  onTap: () => Navigator.of(sheetContext).pop(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<({Uint8List bytes, String filename, String contentType})?>
  _pickAttachmentFromPhotoAlbum() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;

    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty) return null;

    final filename = picked.name.trim().isEmpty
        ? 'attachment.jpg'
        : picked.name;
    return (
      bytes: bytes,
      filename: filename,
      contentType: _contentTypeForAttachmentName(filename),
    );
  }

  Future<({Uint8List bytes, String filename, String contentType})?>
  _pickAttachmentFromFiles() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedAttachmentExtensions,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return null;
    final file = picked.files.first;
    if (file.bytes == null || file.bytes!.isEmpty) return null;

    final filename = file.name.trim().isEmpty ? 'attachment' : file.name;
    return (
      bytes: file.bytes!,
      filename: filename,
      contentType: _contentTypeForAttachmentName(filename),
    );
  }

  Future<({String reason, String description})?> _promptAttachmentMetadata({
    required bool requireReason,
  }) async {
    return _runWithOverlaySuspended(
      () => showDialog<({String reason, String description})>(
        context: context,
        builder: (dialogContext) {
          return _AttachmentMetadataDialog(requireReason: requireReason);
        },
      ),
    );
  }

  Future<void> _addAttachment() async {
    if (!_canAddAttachment || _isMutatingAttachment) return;

    try {
      final source = _useMobileAttachmentSourcePicker
          ? await _promptAttachmentSource()
          : 'files';
      if (source == null || source.isEmpty) return;

      final picked = source == 'photo_album'
          ? await _pickAttachmentFromPhotoAlbum()
          : await _pickAttachmentFromFiles();
      if (picked == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected attachment has no content.')),
        );
        return;
      }

      if (_showDesktopAttachment && mounted) {
        setState(_closeDesktopAttachmentViewer);
      }

      final metadata = await _promptAttachmentMetadata(
        requireReason: _addAttachmentRequiresReason,
      );
      if (metadata == null) return;

      setState(() => _isMutatingAttachment = true);
      final message = await ApiController.uploadWorkOrderAttachment(
        _workOrder.id,
        fileBytes: picked.bytes,
        filename: picked.filename,
        contentType: picked.contentType,
        reason: metadata.reason,
        description: metadata.description,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      await _reloadAttachmentAndHistory();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Add attachment failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _isMutatingAttachment = false);
      }
    }
  }

  Future<void> _deleteAttachment(WorkOrderAttachment attachment) async {
    if (!_canDeleteAttachment || _isMutatingAttachment) return;

    final displayLabel = _attachmentDisplayLabel(attachment);

    final confirmed = await _runWithOverlaySuspended(
      () => showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Delete attachment'),
            content: Text('Delete "$displayLabel" from this work order?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;

    String reason = '';
    if (_deleteAttachmentRequiresReason) {
      final input = await _promptReason('Delete attachment reason');
      if (input == null || input.trim().isEmpty) return;
      reason = input.trim();
    }

    try {
      setState(() => _isMutatingAttachment = true);
      final message = await ApiController.deleteWorkOrderAttachment(
        _workOrder.id,
        attachment.id,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      await _reloadAttachmentAndHistory();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete attachment failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _isMutatingAttachment = false);
      }
    }
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
    return _runWithOverlaySuspended(
      () => showDialog<String>(
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
      ),
    );
  }

  Future<({DateTime plannedDate, String plannedHalfDay})?> _promptSchedule(
    String title,
  ) async {
    final pickedDate = await _runWithOverlaySuspended(
      () => showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 3650)),
      ),
    );
    if (pickedDate == null || !mounted) {
      return null;
    }

    String selectedHalfDay = 'am';
    if (!mounted) return null;
    final result = await _runWithOverlaySuspended(
      () => showDialog<String>(
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
      ),
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
            builder: (_) => WorkOrderReportSignPage(workOrder: _workOrder),
          ),
        );
        if (updated == true) {
          await _load();
        }
        return;
      } else if (action == 'edit_report') {
        final updated = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => WorkOrderReportFormPage(workOrder: _workOrder),
          ),
        );
        if (updated == true) {
          await _load();
        }
        return;
      } else if (action == 'add_remarks') {
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => WorkOrderReportFormPage(workOrder: _workOrder),
          ),
        );
        if (!mounted) return;
        await _load();
        return;
      } else if (action == 'add_attachment') {
        await _addAttachment();
        return;
      } else if (action == 'view_report') {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WorkOrderReportPdfPage(workOrder: _workOrder),
          ),
        );
        return;
      } else if (action == 'approve') {
        feedback = await ApiController.approveWorkOrder(_workOrder.id);
      } else if (action == 'reject') {
        final reason = await _promptReason('Reject work order');
        if (reason == null || reason.isEmpty) return;
        feedback = await ApiController.rejectWorkOrder(
          _workOrder.id,
          reason: reason,
        );
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
          normalizedStatus == 'cannot_completed' ||
          normalizedStatus == 'rejected') {
        items.add(const MapEntry('assign_to_engineer', 'Assign to engineer'));
        items.add(
          const MapEntry('revoke_to_unassigned', 'Return to public pool'),
        );
      } else if (_hasOfficeAdminRole &&
          (normalizedStatus == 'signed' ||
              normalizedStatus == 'signed_edited')) {
        items.add(const MapEntry('view_report', 'View Report'));
        items.add(const MapEntry('edit_report', 'Edit Report'));
        items.add(const MapEntry('add_remarks', 'Add remarks'));
        items.add(const MapEntry('approve', 'Accept'));
        items.add(const MapEntry('reject', 'Reject'));
      } else if (normalizedStatus == 'approved') {
        items.add(const MapEntry('view_report', 'View Report'));
        items.add(const MapEntry('send_email', 'Send email'));
      }
    }

    // if (_canAddAttachment) {
    //   items.add(const MapEntry('add_attachment', 'Add Attachment'));
    // }

    if (_hasEngineerRole) {
      if (_isUnassigned(_workOrder)) {
        items.add(const MapEntry('take', 'Take it'));
      } else if (_isMine(_workOrder)) {
        if (normalizedStatus == 'assigned' ||
            normalizedStatus == 'cannot_completed' ||
            normalizedStatus == 'rejected') {
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
          items.add(const MapEntry('sign', 'Review and Sign'));
          items.add(const MapEntry('edit_report', 'Edit Report'));
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
      case 'edit_report':
        return Icons.edit_outlined;
      case 'add_remarks':
        return Icons.rate_review_outlined;
      case 'view_report':
        return Icons.visibility_outlined;
      case 'approve':
        return Icons.check_circle_outline;
      case 'reject':
        return Icons.cancel_outlined;
      case 'add_attachment':
        return Icons.attach_file_outlined;
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
    String description = '',
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
          _desktopAttachmentDescription = description.trim();
          _desktopAttachmentContentType = contentType;
          _desktopAttachmentHeaders = {'Authorization': 'Bearer $token'};
          _desktopAttachmentBytes = attachmentBytes;
        });
        return;
      }

      if (kIsWeb) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WorkOrderWebAttachmentViewerPage(
              fileName: title,
              fileBytes: attachmentBytes,
              contentType: contentType,
              description: description,
            ),
          ),
        );
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WorkOrderAttachmentViewerPage(
            pdfBytes: attachmentBytes,
            networkUrl: uri.toString(),
            networkHeaders: {'Authorization': 'Bearer $token'},
            fileName: title,
            contentType: contentType,
            description: description,
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
    final reportPdfUrl = _resolvedReportPdfUrl();
    final reportPdfName = _resolvedReportPdfName();
    final systemAttachments = <({String url, String title})>[
      if (_workOrder.sourceFileUrl.isNotEmpty)
        (url: _workOrder.sourceFileUrl, title: 'Work Order PDF'),
      if (reportPdfUrl.isNotEmpty) (url: reportPdfUrl, title: reportPdfName),
      if (_workOrder.mergedPdfUrl.isNotEmpty)
        (url: _workOrder.mergedPdfUrl, title: 'Merged PDF'),
    ];
    final userAttachments = _attachments
        .where((attachment) => attachment.fileUrl.trim().isNotEmpty)
        .toList();

    Widget buildAttachmentTile({
      required String title,
      required String contentType,
      String subtitle = '',
      required VoidCallback? onTap,
      VoidCallback? onDelete,
    }) {
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          color: const Color(0xFFF8FAFC),
        ),
        child: ListTile(
          dense: true,
          visualDensity: const VisualDensity(vertical: -2),
          minVerticalPadding: 2,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 2,
          ),
          leading: Icon(
            contentType.toLowerCase().startsWith('image/')
                ? Icons.image_outlined
                : Icons.picture_as_pdf_outlined,
            size: 18,
          ),
          title: Text(title, style: const TextStyle(fontSize: 13.5)),
          subtitle: subtitle.trim().isEmpty
              ? null
              : Text(subtitle, style: const TextStyle(fontSize: 12)),
          onTap: onTap,
          trailing: onDelete == null
              ? null
              : IconButton(
                  onPressed: onDelete,
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline, size: 18),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
        ),
      );
    }

    return Card(
      color: Colors.white,
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Attachments',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                if (_canAddAttachment)
                  IconButton(
                    onPressed: _isMutatingAttachment ? null : _addAttachment,
                    tooltip: _isMutatingAttachment
                        ? 'Processing...'
                        : 'Add Attachment',
                    icon: _isMutatingAttachment
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (_isLoadingAttachments)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: CircularProgressIndicator(),
              )
            else if (_attachmentAccessMessage.isNotEmpty)
              Text(
                _attachmentAccessMessage,
                style: const TextStyle(color: Color(0xFF64748B)),
              )
            else if (systemAttachments.isEmpty && userAttachments.isEmpty)
              const Text(
                'No attachments are available for this work order yet.',
                style: TextStyle(color: Color(0xFF64748B)),
              )
            else ...[
              if (systemAttachments.isNotEmpty)
                Column(
                  children: systemAttachments
                      .map(
                        (item) => buildAttachmentTile(
                          title: item.title,
                          contentType: 'application/pdf',
                          onTap: _isOpeningAttachment || _isMutatingAttachment
                              ? null
                              : () => _openAttachment(
                                  item.url,
                                  item.title,
                                  contentType: 'application/pdf',
                                ),
                        ),
                      )
                      .toList(),
                ),
              if (systemAttachments.isNotEmpty && userAttachments.isNotEmpty)
                const SizedBox(height: 12),
              if (userAttachments.isNotEmpty)
                Column(
                  children: userAttachments.map((attachment) {
                    final fallbackLabel = _attachmentDisplayLabel(
                      attachment,
                      attachments: userAttachments,
                    );
                    final title = attachment.description.trim().isNotEmpty
                        ? attachment.description.trim()
                        : fallbackLabel;
                    final subtitleParts = <String>[
                      if (attachment.createdAt.trim().isNotEmpty)
                        _formatDateTime(attachment.createdAt),
                    ];
                    return buildAttachmentTile(
                      title: title,
                      contentType: attachment.contentType,
                      subtitle: subtitleParts.join(' • '),
                      onTap: _isOpeningAttachment || _isMutatingAttachment
                          ? null
                          : () => _openAttachment(
                              attachment.fileUrl,
                              title,
                              contentType: attachment.contentType,
                              description: attachment.description,
                            ),
                      onDelete: _canDeleteAttachment && !_isMutatingAttachment
                          ? () => _deleteAttachment(attachment)
                          : null,
                    );
                  }).toList(),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _resolvedReportPdfUrl() {
    final formPdfUrl = _workOrderForm.pdfUrl.trim();
    if (formPdfUrl.isNotEmpty) return formPdfUrl;

    final candidates = <String>[
      '${_workOrder.raw['report_pdf_url'] ?? ''}'.trim(),
      '${_workOrder.raw['form_pdf_url'] ?? ''}'.trim(),
      '${_workOrder.raw['pdf_url'] ?? ''}'.trim(),
    ];
    for (final value in candidates) {
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _resolvedReportPdfName() {
    return 'Report PDF';
  }

  String _attachmentDisplayLabel(
    WorkOrderAttachment target, {
    List<WorkOrderAttachment>? attachments,
  }) {
    final items =
        attachments ??
        _attachments
            .where((attachment) => attachment.fileUrl.trim().isNotEmpty)
            .toList();
    var photoCount = 0;
    var pdfCount = 0;
    var otherCount = 0;

    for (final attachment in items) {
      final contentType = attachment.contentType.trim().toLowerCase();
      final fileName = attachment.fileName.trim().toLowerCase();

      late final String label;
      if (contentType.startsWith('image/') ||
          fileName.endsWith('.png') ||
          fileName.endsWith('.jpg') ||
          fileName.endsWith('.jpeg') ||
          fileName.endsWith('.gif') ||
          fileName.endsWith('.webp') ||
          fileName.endsWith('.heic') ||
          fileName.endsWith('.heif')) {
        photoCount += 1;
        label = 'Photo $photoCount';
      } else if (contentType == 'application/pdf' ||
          fileName.endsWith('.pdf')) {
        pdfCount += 1;
        label = 'PDF $pdfCount';
      } else {
        otherCount += 1;
        label = 'Attachment $otherCount';
      }

      if (attachment.id == target.id) {
        return label;
      }
    }

    return 'Attachment';
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
      case 'attachment_added':
      case 'attachment_uploaded':
        return 'Attachment added';
      case 'attachment_deleted':
        return 'Attachment deleted';
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
                              _closeDesktopAttachmentViewer();
                            });
                          },
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  if (_desktopAttachmentDescription.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          _desktopAttachmentDescription.trim(),
                          style: const TextStyle(color: Color(0xFF334155)),
                        ),
                      ),
                    ),
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
                                : WorkOrderInlineAttachmentPreview(
                                    bytes: _desktopAttachmentBytes!,
                                    contentType: _desktopAttachmentContentType,
                                    suspendOnOverlay: _suspendWebPdfPreview,
                                  ))
                          : WorkOrderPdfViewer(
                              networkUrl: _desktopAttachmentUrl,
                              memoryBytes: _desktopAttachmentBytes,
                              contentType: _desktopAttachmentContentType,
                              networkHeaders: _desktopAttachmentHeaders,
                              suspendOnOverlay: _suspendWebPdfPreview,
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

  bool get _isActiveWorkingAssignment {
    final status = _workOrder.status.trim().toLowerCase();
    return status == 'working' && _isMine(_workOrder);
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
          const SizedBox(height: 14),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              SizedBox(width: 220, child: _buildLocationField()),
              SizedBox(
                width: 260,
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
          const SizedBox(height: 14),
          _buildField('Issue', _issueDisplay()),
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
          if (_isActiveWorkingAssignment) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981)),
              ),
              child: const Text(
                'You have an active work order in progress. You must stay on this page until the work is completed.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF065F46),
                ),
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
        title: 'Other Information',
        children: [
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              SizedBox(
                width: 220,
                child: _buildField('Contact', _contactDisplay()),
              ),
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
    final isLocked = _isActiveWorkingAssignment;
    return PopScope(
      canPop: !isLocked,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !isLocked,
          leading: isLocked ? const SizedBox.shrink() : null,
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

                        final splitIndex = (sections.length / 2).ceil();
                        final leftColumn = sections.take(splitIndex).toList();
                        final rightColumn = sections.skip(splitIndex).toList();

                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
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
      ),
    );
  }
}

class _AttachmentMetadataDialog extends StatefulWidget {
  const _AttachmentMetadataDialog({required this.requireReason});

  final bool requireReason;

  @override
  State<_AttachmentMetadataDialog> createState() =>
      _AttachmentMetadataDialogState();
}

class _AttachmentMetadataDialogState extends State<_AttachmentMetadataDialog> {
  final _reasonController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _reasonController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop((
      reason: _reasonController.text.trim(),
      description: _descriptionController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Attachment Details'),
      scrollable: true,
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (widget.requireReason) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reasonController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Reason is required';
                    }
                    return null;
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('OK')),
      ],
    );
  }
}
