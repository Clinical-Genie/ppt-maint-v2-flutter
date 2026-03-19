import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:maintapp/api/api_controller.dart';
import 'package:maintapp/model/user_info.dart';
import 'package:maintapp/model/work_order.dart';
import 'package:maintapp/pages/shared/app_drawer.dart';
import 'package:maintapp/state/app_state.dart';
import 'package:maintapp/state/login_session_controller.dart';

class WorkOrderListPage extends StatefulWidget {
  const WorkOrderListPage({super.key});

  @override
  State<WorkOrderListPage> createState() => _WorkOrderListPageState();
}

class _WorkOrderListPageState extends State<WorkOrderListPage> {
  final _searchController = TextEditingController();
  final _institutionController = TextEditingController();
  final _listHeaderScrollController = ScrollController();
  final _listBodyScrollController = ScrollController();
  bool _syncingHorizontalTableScroll = false;

  final List<String> _workOrderTypes = const ['CM', 'PM'];
  final List<String> _statusOptions = const [
    'unassigned',
    'assigned',
    'planned',
    'working',
    'completed',
    'cannot_completed',
    'signed',
    'signed_edited',
    'approved',
    'email_sent',
    'cancelled',
  ];
  int _activeTypeIndex = 0;
  final List<WorkOrder> _items = [];
  List<UserInfo> _activeEngineers = [];
  List<UserInfo> _allUsers = [];

  bool _isLoading = false;
  bool _isLoadingUsers = false;
  bool _useCardView = true;
  bool _includeInactiveEngineers = false;
  bool _showCompactEngineerFilters = false;
  static const double _cardModeWidthBreakpoint = 680.0;
  static const int _pageSize = 20;
  String _searchQuery = '';
  String _selectedInstitutionCode = '';
  String _engineerTab = 'unassigned';
  String? _selectedEngineerId;
  List<String> _selectedStatuses = [];
  DateTime? _plannedDateFilter;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  int _currentPage = 1;
  int _totalItems = 0;
  int _currentOffset = 0;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadWorkOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _institutionController.dispose();
    _listHeaderScrollController.dispose();
    _listBodyScrollController.dispose();
    super.dispose();
  }

  String get _activeType => _workOrderTypes[_activeTypeIndex];
  String get _userId => LoginSessionController.instance.userInfo.id;

  bool _isEngineer(UserInfo user) {
    return user.roles.any((role) => role.toUpperCase() == 'ENGINEER');
  }

  Future<void> _loadUsers() async {
    final cachedActive = AppState.instance.activeEngineers;
    final cachedAll = AppState.instance.allUsers;

    if (cachedActive.isNotEmpty || cachedAll.isNotEmpty) {
      setState(() {
        _activeEngineers = List<UserInfo>.from(cachedActive);
        _allUsers = List<UserInfo>.from(cachedAll);
      });

      _activeEngineers.sort(
        (a, b) => _displayName(
          a,
        ).toLowerCase().compareTo(_displayName(b).toLowerCase()),
      );
      _allUsers.sort(
        (a, b) => _displayName(
          a,
        ).toLowerCase().compareTo(_displayName(b).toLowerCase()),
      );

      if (cachedActive.isNotEmpty && cachedAll.isNotEmpty) {
        return;
      }
    }

    setState(() => _isLoadingUsers = true);
    try {
      List<UserInfo> activeEngineers = await ApiController.listUsers(
        role: 'ENGINEER',
        limit: 100,
        offset: 0,
        includeInactive: false,
      ).then((list) => list.items);
      if (activeEngineers.isEmpty) {
        activeEngineers = await ApiController.listUsers(
          limit: 100,
          offset: 0,
          includeInactive: false,
        ).then((list) => list.items.where(_isEngineer).toList());
      }
      final List<UserInfo> allUsers = await ApiController.listUsers(
        role: 'ENGINEER',
        limit: 100,
        offset: 0,
        includeInactive: true,
      ).then((list) => list.items);

      if (!mounted) return;

      activeEngineers.sort(
        (a, b) => _displayName(
          a,
        ).toLowerCase().compareTo(_displayName(b).toLowerCase()),
      );
      allUsers.sort(
        (a, b) => _displayName(
          a,
        ).toLowerCase().compareTo(_displayName(b).toLowerCase()),
      );

      if (!mounted) return;

      setState(() {
        _activeEngineers = activeEngineers;
        _allUsers = allUsers;
      });
      AppState.instance.setUsers(
        activeEngineers: activeEngineers,
        allUsers: allUsers,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingUsers = false);
      }
    }
  }

  Future<void> _loadWorkOrders() async {
    setState(() => _isLoading = true);
    final currentUser = LoginSessionController.instance.userInfo;
    final hasEngineerRole = _hasRole(currentUser, 'ENGINEER');
    final hasManagerRole =
        _hasRole(currentUser, 'MANAGER') || _hasRole(currentUser, 'ADMIN');
    String? tabFilter;
    String? ownerFilter;
    String? plannedDateFilter;

    if (hasEngineerRole) {
      tabFilter = _engineerTab;
      if (_engineerTab == 'picked_by_others' &&
          _selectedEngineerId != null &&
          _selectedEngineerId!.isNotEmpty) {
        ownerFilter = _selectedEngineerId;
      }
      if (_engineerTab == 'planned' && _plannedDateFilter != null) {
        plannedDateFilter = _dateText(_plannedDateFilter);
      }
    } else if (hasManagerRole) {
      if (_selectedEngineerId != null && _selectedEngineerId!.isNotEmpty) {
        ownerFilter = _selectedEngineerId;
      }
    }

    final statusFilter = _selectedStatuses.join(',');

    try {
      final payload = await ApiController.listWorkOrders(
        woType: _activeType,
        tab: tabFilter,
        page: _currentPage,
        pageSize: _pageSize,
        institution: _selectedInstitutionCode.isEmpty
            ? null
            : _selectedInstitutionCode,
        ownerUserId: ownerFilter,
        plannedDate: plannedDateFilter,
        status: statusFilter.isEmpty ? null : statusFilter,
      );
      if (!mounted) return;
      final loadedItems = hasEngineerRole && _engineerTab == 'picked_by_others'
          ? payload.items.where((item) => item.ownerUserId != _userId).toList()
          : payload.items;
      setState(() {
        _items
          ..clear()
          ..addAll(loadedItems);
        _totalItems = payload.total;
        _currentOffset = payload.offset;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onWorkOrderTypeChanged(int index) {
    if (index == _activeTypeIndex) return;
    setState(() {
      _activeTypeIndex = index;
      _currentPage = 1;
    });
    _loadWorkOrders();
  }

  Future<void> _pickDateFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFrom ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null && mounted) {
      setState(() {
        _dateFrom = picked;
      });
      _loadWorkOrders();
    }
  }

  Future<void> _pickDateTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateTo ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null && mounted) {
      setState(() {
        _dateTo = picked;
      });
      _loadWorkOrders();
    }
  }

  void _onSearch() {
    setState(() => _searchQuery = _searchController.text);
    _loadWorkOrders();
  }

  void _onEngineerChanged(String? engineerId) {
    final normalizedId = engineerId == null || engineerId.isEmpty
        ? null
        : engineerId;
    setState(() {
      _selectedEngineerId = normalizedId;
      _currentPage = 1;
    });
    _loadWorkOrders();
  }

  void _onIncludeInactiveEngineersChanged(bool value) {
    setState(() {
      _includeInactiveEngineers = value;
      if (!value &&
          _selectedEngineerId != null &&
          _selectedEngineerId!.isNotEmpty &&
          !_activeEngineers.any(
            (engineer) => engineer.id == _selectedEngineerId,
          )) {
        _selectedEngineerId = null;
      }
    });
  }

  void _applyStatusFilter() {
    setState(() {
      _currentPage = 1;
    });
    _loadWorkOrders();
  }

  String _statusFilterSummary() {
    if (_selectedStatuses.isEmpty) return 'All statuses';
    return _selectedStatuses.join(', ');
  }

  Future<void> _openStatusFilterDialog() async {
    final selected = Set<String>.from(_selectedStatuses);
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select statuses'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _statusOptions.map((status) {
                      final isSelected = selected.contains(status);
                      return FilterChip(
                        label: Text(status),
                        selected: isSelected,
                        onSelected: (value) {
                          setDialogState(() {
                            if (value) {
                              selected.add(status);
                            } else {
                              selected.remove(status);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(<String>[]);
                  },
                  child: const Text('Clear'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(selected.toList()..sort());
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || result == null) return;
    setState(() {
      _selectedStatuses = result;
      _currentPage = 1;
    });
    _loadWorkOrders();
  }

  void _applyInstitutionFilter(InstitutionOption? option) {
    setState(() {
      _selectedInstitutionCode = option?.code ?? '';
      _institutionController.text = option?.displayLabel ?? '';
      _currentPage = 1;
    });
    _loadWorkOrders();
  }

  void _clearInstitutionFilter() {
    _applyInstitutionFilter(null);
  }

  void _onEngineerTabChanged(String value) {
    if (_engineerTab == value) return;
    setState(() {
      _engineerTab = value;
      if (value != 'picked_by_others') {
        _selectedEngineerId = null;
      }
      if (value != 'planned') {
        _plannedDateFilter = null;
      }
      _currentPage = 1;
    });
    _loadWorkOrders();
  }

  void _toggleCompactEngineerFilters() {
    setState(() {
      _showCompactEngineerFilters = !_showCompactEngineerFilters;
    });
  }

  Future<void> _pickPlannedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _plannedDateFilter ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _plannedDateFilter = picked;
      _currentPage = 1;
    });
    _loadWorkOrders();
  }

  void _clearPlannedDate() {
    setState(() {
      _plannedDateFilter = null;
      _currentPage = 1;
    });
    _loadWorkOrders();
  }

  int get _totalPages {
    if (_totalItems <= 0) return 1;
    return ((_totalItems - 1) ~/ _pageSize) + 1;
  }

  String get _paginationLabel {
    if (_totalItems == 0 || _items.isEmpty) {
      return '0 of 0';
    }
    log(
      "Current offset: $_currentOffset, page size: $_pageSize, total items: $_totalItems",
    );
    final start = _currentOffset + 1;
    final end = (_currentOffset + _pageSize).clamp(1, _totalItems);
    return '$start-$end of $_totalItems';
  }

  void _goToPage(int page) {
    final target = page.clamp(1, _totalPages);
    if (target == _currentPage) return;
    setState(() => _currentPage = target);
    _loadWorkOrders();
  }

  Widget _buildPaginationBar({required bool hasFloatingButton}) {
    final canGoPrevious = !_isLoading && _currentPage > 1;
    final canGoNext = !_isLoading && _currentPage < _totalPages;
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          hasFloatingButton ? 16 : 16,
          hasFloatingButton ? 16 : 16,
        ),
        color: const Color(0xFFF4F7FB),
        child: Row(
          children: [
            Text(
              'Page $_currentPage / $_totalPages',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF334155),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _paginationLabel,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: canGoPrevious
                  ? () => _goToPage(_currentPage - 1)
                  : null,
              icon: const Icon(Icons.chevron_left),
              label: const Text('Previous'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: canGoNext ? () => _goToPage(_currentPage + 1) : null,
              icon: const Icon(Icons.chevron_right),
              label: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }

  String _displayName(UserInfo user) {
    if (user.fullName.isNotEmpty) return user.fullName;
    if (user.username.isNotEmpty) return user.username;
    return user.id;
  }

  List<UserInfo> get _engineersForFilter {
    final Map<String, UserInfo> usersById = _includeInactiveEngineers
        ? {for (final engineer in _allUsers) engineer.id: engineer}
        : {for (final engineer in _activeEngineers) engineer.id: engineer};

    final users = usersById.values.toList();
    users.sort(
      (a, b) => _displayName(
        a,
      ).toLowerCase().compareTo(_displayName(b).toLowerCase()),
    );
    return users;
  }

  bool _isUnassigned(WorkOrder order) => order.ownerUserId.isEmpty;
  bool _isMine(WorkOrder order) => order.ownerUserId == _userId;
  bool _isAssignedToOthers(WorkOrder order) =>
      order.ownerUserId.isNotEmpty && order.ownerUserId != _userId;
  String _lookupOwnerNameById(String ownerUserId) {
    if (ownerUserId.isEmpty) return '';
    for (final user in _allUsers) {
      if (user.id == ownerUserId) {
        return _displayName(user);
      }
    }
    return '';
  }

  String _ownerDisplayName(WorkOrder order) {
    if (order.ownerFullName.isNotEmpty) {
      return order.ownerFullName;
    }
    final fromEngineers = _lookupOwnerNameById(order.ownerUserId);
    return fromEngineers.isNotEmpty ? fromEngineers : order.ownerUserId;
  }

  String _createdDisplayDate(WorkOrder order) {
    return _formatDateTime(_effectiveCreatedAt(order));
  }

  String _effectiveCreatedAt(WorkOrder order) {
    return order.haCreatedAt.isNotEmpty ? order.haCreatedAt : order.createdAt;
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeStr;
    }
  }

  String _buildDescriptionWithRemark(WorkOrder order) {
    final String description = order.description.trim();
    final String remark = order.remark.trim();
    if (description.isNotEmpty && remark.isNotEmpty) {
      return '$description\nRemark: $remark';
    }
    if (description.isNotEmpty) return description;
    if (remark.isNotEmpty) return 'Remark: $remark';
    return 'No description';
  }

  String _institutionFromLocation(String locationCode) {
    final trimmed = locationCode.trim();
    if (trimmed.isEmpty) return '-';
    final dashIndex = trimmed.indexOf('-');
    return dashIndex > 0 ? trimmed.substring(0, dashIndex) : trimmed;
  }

  DateTime? _parseDateTime(String dateTimeStr) {
    try {
      return DateTime.parse(dateTimeStr);
    } catch (_) {
      return null;
    }
  }

  bool _isPriorityCritical(WorkOrder order) =>
      order.priority.trim().toLowerCase() == 'critical';

  bool _isMoreThanSevenDaysOld(WorkOrder order) {
    final createdAt = _parseDateTime(_effectiveCreatedAt(order));
    if (createdAt == null) return false;
    final now = DateTime.now();
    return now.difference(createdAt).inDays > 7;
  }

  bool _isCreatedToday(WorkOrder order) {
    final createdAt = _parseDateTime(order.createdAt);
    if (createdAt == null) return false;
    final now = DateTime.now();
    return createdAt.year == now.year &&
        createdAt.month == now.month &&
        createdAt.day == now.day;
  }

  bool _hasWorkOrderIndicators(WorkOrder order) =>
      _isPriorityCritical(order) ||
      _isMoreThanSevenDaysOld(order) ||
      _isCreatedToday(order);

  Widget _buildWorkOrderIcons(
    WorkOrder order, {
    double iconSize = 14,
    double iconSpacing = 4,
    bool withCardBadge = false,
  }) {
    final indicators = <Map<String, dynamic>>[];
    if (_isPriorityCritical(order)) {
      indicators.add({
        'icon': Icons.priority_high_rounded,
        'color': const Color(0xFFB91C1C),
        'tooltip': 'Critical',
      });
    }
    if (_isMoreThanSevenDaysOld(order)) {
      indicators.add({
        'icon': Icons.access_time_filled_rounded,
        'color': const Color(0xFFB45309),
        'tooltip': 'Overdue > 7 days',
      });
    }
    if (_isCreatedToday(order)) {
      indicators.add({
        'icon': Icons.fiber_new_rounded,
        'color': const Color(0xFF0369A1),
        'tooltip': 'Created today',
      });
    }

    if (indicators.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: iconSpacing,
      children: indicators
          .map(
            (info) => Tooltip(
              message: info['tooltip'] as String,
              child: withCardBadge
                  ? Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: (info['color'] as Color).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        info['icon'] as IconData,
                        size: iconSize,
                        color: info['color'] as Color,
                      ),
                    )
                  : Icon(
                      info['icon'] as IconData,
                      size: iconSize,
                      color: info['color'] as Color,
                    ),
            ),
          )
          .toList(),
    );
  }

  TextStyle get _detailTextStyle =>
      const TextStyle(fontSize: 14, color: Color(0xFF334155));

  TextStyle get _detailLabelStyle => const TextStyle(
    fontSize: 14,
    color: Color(0xFF334155),
    fontWeight: FontWeight.w700,
  );

  Widget _buildLocationDisplay(String locationCode) {
    if (locationCode.isEmpty) {
      return Row(
        children: [
          const Icon(
            Icons.location_on_outlined,
            size: 16,
            color: Color(0xFF334155),
          ),
          const SizedBox(width: 6),
          const SelectableText(
            '-',
            style: TextStyle(fontSize: 14, color: Color(0xFF334155)),
          ),
        ],
      );
    }

    final idx = locationCode.indexOf('-');
    if (idx <= 0) {
      return Row(
        children: [
          const Icon(
            Icons.location_on_outlined,
            size: 16,
            color: Color(0xFF334155),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SelectableText.rich(
              TextSpan(
                style: _detailTextStyle,
                children: [TextSpan(text: locationCode)],
              ),
            ),
          ),
        ],
      );
    }

    final hospital = locationCode.substring(0, idx);
    final rest = locationCode.substring(idx);
    return Row(
      children: [
        const Icon(
          Icons.location_on_outlined,
          size: 16,
          color: Color(0xFF334155),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: SelectableText.rich(
            TextSpan(
              style: _detailTextStyle,
              children: [
                const TextSpan(
                  text: '',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: hospital,
                  style: const TextStyle(
                    color: Color(0xFF1D4ED8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(text: rest),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<String?> _promptReason(String title) async {
    final reasonController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Please provide reason',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(reasonController.text.trim()),
              child: const Text('Submit'),
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
    String? selectedId;
    return showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(title),
              content: DropdownButtonFormField<String>(
                initialValue: selectedId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Engineer',
                  border: OutlineInputBorder(),
                ),
                items: _activeEngineers
                    .where((engineer) => engineer.id != (excludeUserId ?? ''))
                    .map(
                      (engineer) => DropdownMenuItem<String>(
                        value: engineer.id,
                        child: Text(_displayName(engineer)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setStateDialog(() => selectedId = value);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedId == null
                      ? null
                      : () => Navigator.of(context).pop(selectedId),
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<DateTime?> _promptDateTime(String title) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      helpText: title,
    );
    if (pickedDate == null || !mounted) return null;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(DateTime.now()),
    );
    if (pickedTime == null) return null;
    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  Future<void> _runAction(
    String action,
    WorkOrder order,
    BuildContext rowContext,
  ) async {
    try {
      String feedback;
      final user = LoginSessionController.instance.userInfo;
      if (action == 'edit') {
        ScaffoldMessenger.of(rowContext).showSnackBar(
          const SnackBar(content: Text('Edit action is not available yet.')),
        );
        return;
      } else if (action == 'assign_to_engineer') {
        final engineerId = await _promptEngineerId(title: 'Assign to engineer');
        if (engineerId == null || engineerId.isEmpty) return;
        feedback = _toActionMessage(
          await ApiController.assignWorkOrder(
            order.id,
            targetUserId: engineerId,
            reason: 'Assign on demand.',
          ),
        );
      } else if (action == 'revoke_to_unassigned') {
        final reason = await _promptReason('Return to public pool');
        if (reason == null || reason.isEmpty) return;
        feedback = await ApiController.releaseWorkOrder(order.id, reason);
        // } else if (action == 'cancel') {
        //   final reason = await _promptReason('Cancel work order');
        //   if (reason == null || reason.isEmpty) return;
        //   feedback = await ApiController.cancelWorkOrder(order.id, reason);
      } else if (action == 'take') {
        feedback = await ApiController.pickWorkOrder(order.id);
      } else if (action == 'transfer_away') {
        final engineerId = await _promptEngineerId(
          title: 'Hand off to',
          excludeUserId: user.id,
        );
        if (engineerId == null || engineerId.isEmpty) return;
        final reason = await _promptReason('Hand off reason');
        if (reason == null || reason.isEmpty) return;
        feedback = _toActionMessage(
          await ApiController.assignWorkOrder(
            order.id,
            targetUserId: engineerId,
            reason: reason,
          ),
        );
      } else if (action == 'transfer_to_me') {
        final reason = await _promptReason('Take over reason');
        if (reason == null || reason.isEmpty) return;
        feedback = _toActionMessage(
          await ApiController.assignWorkOrder(
            order.id,
            targetUserId: user.id,
            reason: reason,
          ),
        );
      } else if (action == 'release_to_unassigned') {
        final reason = await _promptReason('Return to public pool');
        if (reason == null || reason.isEmpty) return;
        feedback = await ApiController.releaseWorkOrder(order.id, reason);
      } else if (action == 'plan') {
        final picked = await _promptDateTime('Schedule work order');
        if (picked == null) return;
        feedback = await ApiController.planWorkOrder(
          order.id,
          plannedDate: picked.toIso8601String().split('.').first,
        );
      } else if (action == 'start') {
        feedback = await ApiController.startWorkOrder(order.id);
      } else {
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        rowContext,
      ).showSnackBar(SnackBar(content: Text(feedback)));
      await _loadWorkOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        rowContext,
      ).showSnackBar(SnackBar(content: Text('Action failed: $e')));
    }
  }

  List<PopupMenuEntry<String>> _buildActionItems({
    required WorkOrder order,
    required bool hasManagerRole,
    required bool hasEngineerRole,
  }) {
    final items = <PopupMenuEntry<String>>[];

    if (hasManagerRole) {
      items.add(const PopupMenuItem(value: 'edit', child: Text('Edit')));
      items.add(
        const PopupMenuItem(
          value: 'assign_to_engineer',
          child: Text('Assign to engineer'),
        ),
      );
      if (!_isUnassigned(order)) {
        items.add(
          const PopupMenuItem(
            value: 'revoke_to_unassigned',
            child: Text('Return to public pool'),
          ),
        );
      }
    }

    if (hasEngineerRole) {
      if (_isUnassigned(order)) {
        items.add(const PopupMenuItem(value: 'take', child: Text('Take it')));
      } else if (_isMine(order)) {
        items.add(
          const PopupMenuItem(value: 'transfer_away', child: Text('Hand off')),
        );
        if (!hasManagerRole) {
          items.add(
            const PopupMenuItem(
              value: 'release_to_unassigned',
              child: Text('Return to public pool'),
            ),
          );
        }
        items.add(const PopupMenuItem(value: 'plan', child: Text('Schedule')));
        items.add(
          const PopupMenuItem(value: 'start', child: Text('Start work')),
        );
      } else if (_isAssignedToOthers(order)) {
        items.add(
          const PopupMenuItem(
            value: 'transfer_to_me',
            child: Text('Take over'),
          ),
        );
      }
    }

    if (items.isEmpty) {
      items.add(
        const PopupMenuItem<String>(
          enabled: false,
          value: 'none',
          child: Text('No actions'),
        ),
      );
    }
    return items;
  }

  String _toActionMessage(dynamic result) {
    if (result is String) return result;
    if (result is Map) {
      final raw = Map<dynamic, dynamic>.from(result);
      if (raw['message'] is String) return raw['message'] as String;
      if (raw['error'] is String) return raw['error'] as String;
    }
    return 'Done';
  }

  Widget _buildOwnerChip(WorkOrder order) {
    if (order.status.toLowerCase() == 'cancelled') {
      return const Chip(
        label: Text('Cancelled'),
        backgroundColor: Color.fromARGB(255, 135, 5, 5),
        side: BorderSide(color: Color(0xFFFECACA)),
        labelStyle: TextStyle(
          color: Color.fromARGB(255, 211, 211, 211),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      );
    } else if (order.ownerUserId.isEmpty) {
      return const Chip(
        label: Text('Unassigned'),
        backgroundColor: Color(0xFFFEE2E2),
        side: BorderSide(color: Color(0xFFFECACA)),
        labelStyle: TextStyle(
          color: Color(0xFF991B1B),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      );
    } else {
      return Chip(
        label: Text(_ownerDisplayName(order)),
        backgroundColor: const Color(0xFFDBEAFE),
        side: const BorderSide(color: Color(0xFFBFDBFE)),
        labelStyle: const TextStyle(
          color: Color(0xFF1D4ED8),
          fontWeight: FontWeight.w600,
        ),
      );
    }
  }

  Widget _buildStatusChip(WorkOrder order) {
    final status = order.status.trim();
    final normalized = status.toLowerCase();
    Color backgroundColor = const Color(0xFFE2E8F0);
    Color borderColor = const Color(0xFFCBD5E1);
    Color textColor = const Color(0xFF334155);

    if (normalized == 'cancelled') {
      backgroundColor = const Color(0xFFFEE2E2);
      borderColor = const Color(0xFFFECACA);
      textColor = const Color(0xFF991B1B);
    } else if (normalized == 'unassigned' || order.ownerUserId.isEmpty) {
      backgroundColor = const Color(0xFFFFF7ED);
      borderColor = const Color(0xFFFED7AA);
      textColor = const Color(0xFF9A3412);
    } else if (normalized == 'picked' ||
        normalized == 'in_progress' ||
        normalized == 'planned') {
      backgroundColor = const Color(0xFFDBEAFE);
      borderColor = const Color(0xFFBFDBFE);
      textColor = const Color(0xFF1D4ED8);
    } else if (normalized == 'completed' || normalized == 'signed_edited') {
      backgroundColor = const Color(0xFFDCFCE7);
      borderColor = const Color(0xFFBBF7D0);
      textColor = const Color(0xFF166534);
    }

    return Chip(
      label: Text(status.isEmpty ? 'Unknown' : status),
      backgroundColor: backgroundColor,
      side: BorderSide(color: borderColor),
      labelStyle: TextStyle(
        color: textColor,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    );
  }

  Widget _buildStatusChipForTable(WorkOrder order, double maxWidth) {
    final status = order.status.trim().isEmpty
        ? 'Unknown'
        : order.status.trim();
    final normalized = order.status.trim().toLowerCase();
    Color textColor = const Color(0xFF334155);

    if (normalized == 'cancelled') {
      textColor = const Color(0xFF991B1B);
    } else if (normalized == 'unassigned' || order.ownerUserId.isEmpty) {
      textColor = const Color(0xFF9A3412);
    } else if (normalized == 'picked' ||
        normalized == 'in_progress' ||
        normalized == 'planned') {
      textColor = const Color(0xFF1D4ED8);
    } else if (normalized == 'completed' || normalized == 'signed_edited') {
      textColor = const Color(0xFF166534);
    }

    return Tooltip(
      message: status,
      child: SizedBox(
        width: maxWidth,
        child: SelectableText(
          status,
          maxLines: 1,
          // overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    WorkOrder item, {
    required bool hasManagerRole,
    required bool hasEngineerRole,
  }) {
    final ownerName = _ownerDisplayName(item);
    final hasWorkOrderIndicators = _hasWorkOrderIndicators(item);
    final workOrderIcons = _buildWorkOrderIcons(
      item,
      iconSize: 18,
      iconSpacing: 8,
      withCardBadge: true,
    );
    final hasPickedEngineer =
        item.ownerUserId.isNotEmpty && item.status.toLowerCase() != 'cancelled';
    final deviceText = [
      if (item.deviceBrand.isNotEmpty) item.deviceBrand,
      if (item.deviceModel.isNotEmpty) item.deviceModel,
    ].join(' - ');
    final issueText = _buildDescriptionWithRemark(item);
    return Card(
      color: Colors.white,
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 16),
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasWorkOrderIndicators) ...[
                            workOrderIcons,
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: SelectableText(
                              item.woNo.isNotEmpty
                                  ? item.woNo
                                  : item.displayLabel,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                color: _isPriorityCritical(item)
                                    ? const Color(0xFFB91C1C)
                                    : const Color(0xFF0F172A),
                                decoration: _isPriorityCritical(item)
                                    ? TextDecoration.underline
                                    : TextDecoration.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.add_box_outlined,
                            size: 16,
                            color: Color(0xFF334155),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: SelectableText.rich(
                              TextSpan(
                                style: _detailTextStyle,
                                children: [
                                  TextSpan(text: _createdDisplayDate(item)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (hasPickedEngineer) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 16,
                              color: Color(0xFF1D4ED8),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: SelectableText(
                                ownerName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF1D4ED8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      _buildLocationDisplay(item.locationCode),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.devices_other_outlined,
                            size: 16,
                            color: Color(0xFF334155),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: SelectableText.rich(
                              TextSpan(
                                style: _detailTextStyle,
                                children: [
                                  TextSpan(
                                    text: deviceText.isEmpty ? '-' : deviceText,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.report_problem_outlined,
                            size: 16,
                            color: Color(0xFF334155),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: SelectableText.rich(
                              TextSpan(
                                style: _detailTextStyle,
                                children: [TextSpan(text: issueText)],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 36),
                Center(
                  child: PopupMenuButton<String>(
                    tooltip: 'Actions',
                    icon: const Icon(Icons.more_vert),
                    onSelected: (String value) {
                      if (value == 'none') return;
                      _runAction(value, item, context);
                    },
                    itemBuilder: (_) => _buildActionItems(
                      order: item,
                      hasManagerRole: hasManagerRole,
                      hasEngineerRole: hasEngineerRole,
                    ),
                  ),
                ),
              ],
            ),
            Positioned(top: 0, right: 0, child: _buildStatusChip(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildTraditionalRow(
    BuildContext context,
    WorkOrder item, {
    required bool hasManagerRole,
    required bool hasEngineerRole,
    required double woWidth,
    required double createdWidth,
    required double locationWidth,
    required double deviceWidth,
    required double issueWidth,
    required double ownerWidth,
    required double statusWidth,
    required double actionsWidth,
  }) {
    final ownerName = _ownerDisplayName(item);
    final hasWorkOrderIndicators = _hasWorkOrderIndicators(item);
    final workOrderIcons = _buildWorkOrderIcons(
      item,
      iconSize: 14,
      iconSpacing: 4,
      withCardBadge: false,
    );
    final hasPickedEngineer =
        item.ownerUserId.isNotEmpty && item.status.toLowerCase() != 'cancelled';
    final deviceText = [
      if (item.deviceBrand.isNotEmpty) item.deviceBrand,
      if (item.deviceModel.isNotEmpty) item.deviceModel,
    ].join(' - ');
    final issueText = _buildDescriptionWithRemark(item);
    Widget cell({
      required double width,
      required Widget child,
      EdgeInsets padding = const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 14,
      ),
    }) {
      return Container(
        width: width,
        padding: padding,
        alignment: Alignment.centerLeft,
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: child,
      );
    }

    Widget locationCell = SelectableText.rich(
      TextSpan(
        style: _detailTextStyle,
        children: () {
          final locationCode = item.locationCode.trim();
          if (locationCode.isEmpty) {
            return const [TextSpan(text: '-')];
          }
          final idx = locationCode.indexOf('-');
          if (idx <= 0) {
            return [TextSpan(text: locationCode)];
          }
          return [
            TextSpan(
              text: locationCode.substring(0, idx),
              style: const TextStyle(
                color: Color(0xFF1D4ED8),
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(text: locationCode.substring(idx)),
          ];
        }(),
      ),
    );

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: Color(0xFFE2E8F0)),
          right: BorderSide(color: Color(0xFFE2E8F0)),
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          cell(
            width: woWidth,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (hasWorkOrderIndicators) ...[
                  workOrderIcons,
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: SelectableText(
                    item.woNo.isNotEmpty ? item.woNo : item.displayLabel,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _isPriorityCritical(item)
                          ? const Color(0xFFB91C1C)
                          : const Color(0xFF0F172A),
                      decoration: _isPriorityCritical(item)
                          ? TextDecoration.underline
                          : TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          cell(
            width: createdWidth,
            child: SelectableText(
              _createdDisplayDate(item),
              style: _detailTextStyle,
            ),
          ),
          cell(width: locationWidth, child: locationCell),
          cell(
            width: deviceWidth,
            child: SelectableText(
              deviceText.isEmpty ? '-' : deviceText,
              style: _detailTextStyle,
            ),
          ),
          cell(
            width: issueWidth,
            child: SelectableText(issueText, style: _detailTextStyle),
          ),
          cell(
            width: ownerWidth,
            child: SelectableText(
              hasPickedEngineer ? ownerName : '-',
              style: TextStyle(
                fontSize: 14,
                color: hasPickedEngineer
                    ? const Color(0xFF1D4ED8)
                    : const Color(0xFF334155),
                fontWeight: hasPickedEngineer
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
          ),
          cell(
            width: statusWidth,
            child: _buildStatusChipForTable(item, statusWidth),
          ),
          // SizedBox(
          cell(
            width: actionsWidth,
            child: Center(
              child: SizedBox(
                width: 32,
                height: 20,
                child: PopupMenuButton<String>(
                  padding: EdgeInsetsGeometry.all(0),
                  tooltip: 'Actions',
                  icon: const Icon(Icons.more_horiz, size: 20),
                  onSelected: (String value) {
                    if (value == 'none') return;
                    _runAction(value, item, context);
                  },
                  itemBuilder: (_) => _buildActionItems(
                    order: item,
                    hasManagerRole: hasManagerRole,
                    hasEngineerRole: hasEngineerRole,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeaderCell(String label, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      alignment: Alignment.centerLeft,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          right: BorderSide(color: Color(0xFFE2E8F0)),
          top: BorderSide(color: Color(0xFFE2E8F0)),
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }

  String _dateText(DateTime? value) {
    if (value == null) return 'Any';
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  bool _hasRole(UserInfo user, String role) {
    return user.roles.any((item) => item.toUpperCase() == role);
  }

  Widget _buildInstitutionAutocomplete(double width) {
    final institutions =
        List<InstitutionOption>.from(AppState.instance.institutions)..sort(
          (a, b) => a.displayLabel.toLowerCase().compareTo(
            b.displayLabel.toLowerCase(),
          ),
        );

    return SizedBox(
      width: width,
      child: Autocomplete<InstitutionOption>(
        displayStringForOption: (option) => option.displayLabel,
        optionsBuilder: (textEditingValue) {
          final query = textEditingValue.text.trim().toLowerCase();
          if (query.isEmpty) return institutions;
          return institutions.where((item) {
            return item.displayLabel.toLowerCase().contains(query);
          });
        },
        onSelected: _applyInstitutionFilter,
        fieldViewBuilder:
            (context, textEditingController, focusNode, onFieldSubmitted) {
              if (textEditingController.text != _institutionController.text) {
                textEditingController.value = _institutionController.value;
              }
              return TextField(
                controller: textEditingController,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: 'Institution',
                  hintText: institutions.isEmpty
                      ? 'No institutions loaded'
                      : 'Type code or name',
                  isDense: true,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  suffixIcon: _selectedInstitutionCode.isEmpty
                      ? const Icon(Icons.arrow_drop_down)
                      : IconButton(
                          tooltip: 'Clear',
                          onPressed: _clearInstitutionFilter,
                          icon: const Icon(Icons.close),
                        ),
                ),
                onSubmitted: (_) {
                  final query = textEditingController.text.trim().toLowerCase();
                  InstitutionOption? match;
                  for (final item in institutions) {
                    if (item.code.toLowerCase() == query ||
                        item.displayLabel.toLowerCase() == query) {
                      match = item;
                      break;
                    }
                  }
                  _applyInstitutionFilter(match);
                },
              );
            },
      ),
    );
  }

  Widget _buildStatusField(double width) {
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: _openStatusFilterDialog,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Status',
            // helperText: 'Tap to select statuses',
            isDense: true,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            suffixIcon: _selectedStatuses.isEmpty
                ? const Icon(Icons.arrow_drop_down)
                : IconButton(
                    tooltip: 'Clear',
                    onPressed: () {
                      setState(() {
                        _selectedStatuses = [];
                        _currentPage = 1;
                      });
                      _loadWorkOrders();
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
          child: Text(
            _statusFilterSummary(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              color: _selectedStatuses.isEmpty
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF334155),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEngineerDropdown(double width, {required bool enabled}) {
    final dropdownEngineers = _engineerTab == 'picked_by_others'
        ? _engineersForFilter
              .where((engineer) => engineer.id != _userId)
              .toList()
        : _engineersForFilter;
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        initialValue: enabled ? (_selectedEngineerId ?? '') : null,
        decoration: const InputDecoration(
          labelText: 'Engineer',
          isDense: true,
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: [
          const DropdownMenuItem(value: '', child: Text('All engineers')),
          ...dropdownEngineers
              .map(
                (engineer) => DropdownMenuItem(
                  value: engineer.id,
                  child: Text(
                    engineer.isActive
                        ? _displayName(engineer)
                        : '${_displayName(engineer)} (inactive)',
                  ),
                ),
              )
              .toList(),
        ],
        onChanged: enabled ? _onEngineerChanged : null,
      ),
    );
  }

  Widget _buildIncludeInactiveEngineersCheckbox() {
    return CheckboxListTile(
      value: _includeInactiveEngineers,
      onChanged: (value) => _onIncludeInactiveEngineersChanged(value ?? false),
      contentPadding: EdgeInsets.zero,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      title: const Text(
        'Include inactive engineers',
        style: TextStyle(fontSize: 13, color: Color(0xFF334155)),
      ),
    );
  }

  Widget _buildQuickFilterContainer({
    required String title,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text(
          //   title,
          //   style: const TextStyle(
          //     fontSize: 13,
          //     fontWeight: FontWeight.w800,
          //     color: Color(0xFF334155),
          //   ),
          // ),
          // const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildManagerFilters(bool useCompactLayout) {
    final content = useCompactLayout
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInstitutionAutocomplete(double.infinity),
              const SizedBox(height: 12),
              _buildEngineerDropdown(double.infinity, enabled: true),
              const SizedBox(height: 4),
              _buildIncludeInactiveEngineersCheckbox(),
              const SizedBox(height: 12),
              _buildStatusField(double.infinity),
            ],
          )
        : Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildInstitutionAutocomplete(260),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEngineerDropdown(240, enabled: true),
                  SizedBox(
                    width: 220,
                    child: _buildIncludeInactiveEngineersCheckbox(),
                  ),
                ],
              ),
              _buildStatusField(240),
            ],
          );

    return _buildQuickFilterContainer(title: 'Manager filters', child: content);
  }

  Widget _buildEngineerFilters(bool useCompactLayout) {
    const tabs = [
      ('unassigned', 'Public pool'),
      ('my_pickups', 'My work orders'),
      ('planned', 'Scheduled'),
      ('picked_by_others', 'Taken by others'),
    ];
    const compactTabIcons = <String, IconData>{
      'unassigned': Icons.move_to_inbox_outlined,
      'my_pickups': Icons.assignment_ind_outlined,
      'planned': Icons.event_note_outlined,
      'picked_by_others': Icons.people_alt_outlined,
    };
    final currentCompactTabLabel = tabs
        .firstWhere((item) => item.$1 == _engineerTab, orElse: () => tabs.first)
        .$2;
    final showEngineerDropdown = _engineerTab == 'picked_by_others';
    final showPlannedDate = _engineerTab == 'planned';
    final showStatusFilter = _engineerTab != 'unassigned';

    final tabToggle = ToggleButtons(
      isSelected: tabs.map((item) => item.$1 == _engineerTab).toList(),
      onPressed: (index) => _onEngineerTabChanged(tabs[index].$1),
      constraints: const BoxConstraints(minHeight: 34, minWidth: 88),
      borderRadius: BorderRadius.circular(12),
      color: const Color(0xFF334155),
      selectedColor: Colors.white,
      fillColor: const Color(0xFF0F766E),
      selectedBorderColor: const Color(0xFF0F766E),
      borderColor: const Color(0xFFCBD5E1),
      children: tabs
          .map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                item.$2,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: item.$1 == _engineerTab
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
          )
          .toList(),
    );

    final compactTabWrap = Center(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: tabs
            .map(
              (item) => ChoiceChip(
                tooltip: item.$2,
                label: Icon(
                  compactTabIcons[item.$1] ?? Icons.radio_button_checked,
                  size: 18,
                  color: item.$1 == _engineerTab
                      ? Colors.white
                      : const Color(0xFF334155),
                ),
                selected: item.$1 == _engineerTab,
                onSelected: (_) => _onEngineerTabChanged(item.$1),
                selectedColor: const Color(0xFF0F766E),
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: item.$1 == _engineerTab
                      ? const Color(0xFF0F766E)
                      : const Color(0xFFCBD5E1),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: const VisualDensity(
                  horizontal: -2,
                  vertical: -2,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            )
            .toList(),
      ),
    );

    final plannedDateButton = OutlinedButton.icon(
      onPressed: _pickPlannedDate,
      icon: const Icon(Icons.event_outlined, size: 18),
      label: Text(
        _plannedDateFilter == null
            ? 'Planned date'
            : _dateText(_plannedDateFilter),
      ),
    );

    final plannedDateClear = _plannedDateFilter == null
        ? const SizedBox.shrink()
        : TextButton(
            onPressed: _clearPlannedDate,
            child: const Text('Clear date'),
          );

    final content = useCompactLayout
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  currentCompactTabLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              compactTabWrap,
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  onPressed: _toggleCompactEngineerFilters,
                  style: TextButton.styleFrom(
                    visualDensity: const VisualDensity(
                      horizontal: -2,
                      vertical: -2,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Icon(
                    _showCompactEngineerFilters
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                  ),
                  label: Text(
                    _showCompactEngineerFilters
                        ? 'Hide filters'
                        : 'Show filters',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (_showCompactEngineerFilters) ...[
                const SizedBox(height: 8),
                _buildInstitutionAutocomplete(double.infinity),
                if (showStatusFilter) ...[
                  const SizedBox(height: 12),
                  _buildStatusField(double.infinity),
                ],
                if (showEngineerDropdown) ...[
                  const SizedBox(height: 12),
                  _buildEngineerDropdown(double.infinity, enabled: true),
                  const SizedBox(height: 4),
                  _buildIncludeInactiveEngineersCheckbox(),
                ],
                if (showPlannedDate) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [plannedDateButton, plannedDateClear],
                  ),
                ],
              ],
            ],
          )
        : Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: tabToggle,
              ),
              _buildInstitutionAutocomplete(240),
              if (showStatusFilter) _buildStatusField(240),
              if (showEngineerDropdown)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEngineerDropdown(240, enabled: true),
                    SizedBox(
                      width: 220,
                      child: _buildIncludeInactiveEngineersCheckbox(),
                    ),
                  ],
                ),
              if (showPlannedDate) plannedDateButton,
              if (showPlannedDate && _plannedDateFilter != null)
                plannedDateClear,
            ],
          );

    return _buildQuickFilterContainer(
      title: 'Engineer filters',
      child: content,
    );
  }

  void _syncHorizontalTableScroll({
    required ScrollController sourceController,
    required ScrollController targetController,
    required double offset,
  }) {
    if (!sourceController.hasClients || !targetController.hasClients) return;
    if (_syncingHorizontalTableScroll) return;
    final maxOffset = targetController.position.maxScrollExtent;
    final nextOffset = offset.clamp(0.0, maxOffset);
    if ((targetController.offset - nextOffset).abs() < 0.5) return;
    _syncingHorizontalTableScroll = true;
    targetController.jumpTo(nextOffset);
    _syncingHorizontalTableScroll = false;
  }

  @override
  Widget build(BuildContext context) {
    final user = LoginSessionController.instance.userInfo;

    final hasManagerRole = _hasRole(user, 'MANAGER');
    final hasEngineerRole = _hasRole(user, 'ENGINEER');
    final hasAdminRole = _hasRole(user, 'ADMIN');
    final screenWidth = MediaQuery.of(context).size.width;
    final shouldUseCardLayoutByWidth = screenWidth < _cardModeWidthBreakpoint;
    final shouldUseCardView = shouldUseCardLayoutByWidth || _useCardView;
    final useCompactFilters = screenWidth < 980;
    final bottomContentPadding = 20.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      drawer: AppDrawer(user: user),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Work Orders',
              style: TextStyle(
                color: Color(0xFF334155),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 12),
            if (!shouldUseCardLayoutByWidth)
              ToggleButtons(
                isSelected: [shouldUseCardView, !shouldUseCardView],
                onPressed: (index) {
                  setState(() => _useCardView = index == 0);
                },
                constraints: const BoxConstraints(minHeight: 28, minWidth: 40),
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFF334155),
                selectedColor: Colors.white,
                fillColor: const Color(0xFF0F766E),
                selectedBorderColor: const Color(0xFF0F766E),
                borderColor: const Color(0xFFCBD5E1),
                children: const [
                  Icon(Icons.grid_view_rounded, size: 16),
                  Icon(Icons.view_headline_rounded, size: 16),
                ],
              ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: ToggleButtons(
                isSelected: [_activeTypeIndex == 0, _activeTypeIndex == 1],
                onPressed: _onWorkOrderTypeChanged,
                constraints: const BoxConstraints(minHeight: 28, minWidth: 56),
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFF334155),
                selectedColor: Colors.white,
                fillColor: const Color(0xFF2563EB),
                selectedBorderColor: const Color(0xFF1D4ED8),
                borderColor: const Color(0xFFCBD5E1),
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.build,
                        size: 14,
                        color: _activeTypeIndex == 0
                            ? Colors.white
                            : const Color(0xFF334155),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'CM',
                        style: TextStyle(
                          fontSize: 11,
                          color: _activeTypeIndex == 0
                              ? Colors.white
                              : const Color(0xFF334155),
                          fontWeight: _activeTypeIndex == 0
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: _activeTypeIndex == 1
                            ? Colors.white
                            : const Color(0xFF334155),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'PM',
                        style: TextStyle(
                          fontSize: 11,
                          color: _activeTypeIndex == 1
                              ? Colors.white
                              : const Color(0xFF334155),
                          fontWeight: _activeTypeIndex == 1
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // IconButton(
          //   tooltip: 'Refresh',
          //   onPressed: _loadWorkOrders,
          //   icon: const Icon(Icons.refresh),
          // ),
          const SizedBox(width: 10),
        ],
      ),
      floatingActionButton: (hasManagerRole)
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).pushNamed('/create-work-order');
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Work Order'),
            )
          : null,
      floatingActionButtonLocation: hasManagerRole
          ? FloatingActionButtonLocation.endFloat
          : null,
      body: Column(
        children: [
          if (hasEngineerRole) _buildEngineerFilters(useCompactFilters),
          if (hasManagerRole && !hasEngineerRole)
            _buildManagerFilters(useCompactFilters),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? const Center(child: Text('No work orders found.'))
                : shouldUseCardView
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      int columns = 1;
                      if (width >= 1800) {
                        columns = 5;
                      } else if (width >= 1500) {
                        columns = 4;
                      } else if (width >= 1100) {
                        columns = 3;
                      } else if (width >= 700) {
                        columns = 2;
                      }

                      const spacing = 8.0;
                      final rows = <List<WorkOrder>>[];
                      for (var i = 0; i < _items.length; i += columns) {
                        final end = (i + columns < _items.length)
                            ? i + columns
                            : _items.length;
                        rows.add(_items.sublist(i, end));
                      }

                      return SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          bottomContentPadding,
                        ),
                        child: Column(
                          children: rows
                              .map(
                                (rowItems) => Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: spacing,
                                  ),
                                  child: IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        for (
                                          var index = 0;
                                          index < columns;
                                          index++
                                        ) ...[
                                          if (index > 0)
                                            const SizedBox(width: spacing),
                                          Expanded(
                                            child: index < rowItems.length
                                                ? _buildRow(
                                                    context,
                                                    rowItems[index],
                                                    hasManagerRole:
                                                        hasManagerRole ||
                                                        hasAdminRole,
                                                    hasEngineerRole:
                                                        hasEngineerRole,
                                                  )
                                                : const SizedBox.shrink(),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      );
                    },
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final tableWidth = constraints.maxWidth * 0.95;
                      final sidePadding =
                          (constraints.maxWidth - tableWidth) / 2;

                      final safeActionsWidth = 60.0;

                      final woWidthWeight = 0.10;
                      final createdWidthWeight = 0.12;
                      final locationWidthWeight = 0.12;
                      final deviceWidthWeight = 0.10;
                      final issueWidthWeight = 0.20;
                      final ownerWidthWeight = 0.09;
                      final statusWidthWeight = 0.10;

                      final sumWeight =
                          woWidthWeight +
                          createdWidthWeight +
                          locationWidthWeight +
                          deviceWidthWeight +
                          issueWidthWeight +
                          ownerWidthWeight +
                          statusWidthWeight;

                      final woWidth =
                          ((tableWidth - safeActionsWidth) *
                                  (woWidthWeight / sumWeight))
                              .toInt();
                      final createdWidth =
                          ((tableWidth - safeActionsWidth) *
                                  (createdWidthWeight / sumWeight))
                              .toInt();
                      final locationWidth =
                          ((tableWidth - safeActionsWidth) *
                                  (locationWidthWeight / sumWeight))
                              .toInt();
                      final deviceWidth =
                          ((tableWidth - safeActionsWidth) *
                                  (deviceWidthWeight / sumWeight))
                              .toInt();
                      final issueWidth =
                          ((tableWidth - safeActionsWidth) *
                                  (issueWidthWeight / sumWeight))
                              .toInt();
                      final ownerWidth =
                          ((tableWidth - safeActionsWidth) *
                                  (ownerWidthWeight / sumWeight))
                              .toInt();
                      final statusWidth =
                          ((tableWidth - safeActionsWidth) *
                                  (statusWidthWeight / sumWeight))
                              .toInt();

                      final realActionsWidth =
                          tableWidth -
                          (woWidth +
                              createdWidth +
                              locationWidth +
                              deviceWidth +
                              issueWidth +
                              ownerWidth +
                              statusWidth);

                      final headerRow = Row(
                        children: [
                          _buildTableHeaderCell(
                            'WO Number',
                            woWidth.toDouble(),
                          ),
                          _buildTableHeaderCell(
                            'HA Created At',
                            createdWidth.toDouble(),
                          ),
                          _buildTableHeaderCell(
                            'Location',
                            locationWidth.toDouble(),
                          ),
                          _buildTableHeaderCell(
                            'Device',
                            deviceWidth.toDouble(),
                          ),
                          _buildTableHeaderCell('Issue', issueWidth.toDouble()),
                          _buildTableHeaderCell(
                            'Taken By',
                            ownerWidth.toDouble(),
                          ),
                          _buildTableHeaderCell(
                            'Status',
                            statusWidth.toDouble(),
                          ),
                          _buildTableHeaderCell(
                            '',
                            realActionsWidth.toDouble(),
                          ),
                        ],
                      );

                      final listRows = _items
                          .map(
                            (item) => _buildTraditionalRow(
                              context,
                              item,
                              hasManagerRole: hasManagerRole || hasAdminRole,
                              hasEngineerRole: hasEngineerRole,
                              woWidth: woWidth.toDouble(),
                              createdWidth: createdWidth.toDouble(),
                              locationWidth: locationWidth.toDouble(),
                              deviceWidth: deviceWidth.toDouble(),
                              issueWidth: issueWidth.toDouble(),
                              ownerWidth: ownerWidth.toDouble(),
                              statusWidth: statusWidth.toDouble(),
                              actionsWidth: realActionsWidth - 2,
                            ),
                          )
                          .toList();

                      return Column(
                        children: [
                          NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (!_syncingHorizontalTableScroll) {
                                _syncHorizontalTableScroll(
                                  sourceController: _listHeaderScrollController,
                                  targetController: _listBodyScrollController,
                                  offset: notification.metrics.pixels,
                                );
                              }
                              return false;
                            },
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: sidePadding,
                              ),
                              child: SingleChildScrollView(
                                controller: _listHeaderScrollController,
                                scrollDirection: Axis.horizontal,
                                physics: const ClampingScrollPhysics(),
                                child: SizedBox(
                                  width: tableWidth,
                                  child: headerRow,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: NotificationListener<ScrollNotification>(
                              onNotification: (notification) {
                                if (!_syncingHorizontalTableScroll) {
                                  _syncHorizontalTableScroll(
                                    sourceController: _listBodyScrollController,
                                    targetController:
                                        _listHeaderScrollController,
                                    offset: notification.metrics.pixels,
                                  );
                                }
                                return false;
                              },
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: SingleChildScrollView(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: sidePadding,
                                  ),
                                  controller: _listBodyScrollController,
                                  scrollDirection: Axis.horizontal,
                                  physics: const ClampingScrollPhysics(),
                                  child: SizedBox(
                                    width: tableWidth,
                                    child: Column(
                                      children: [
                                        ...listRows,
                                        const SizedBox(height: 8),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          _buildPaginationBar(hasFloatingButton: hasManagerRole),
        ],
      ),
    );
  }
}
