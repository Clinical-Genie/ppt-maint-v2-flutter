import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:maintapp/api/api_controller.dart';
import 'package:maintapp/model/admin_result.dart';
import 'package:maintapp/model/api_result.dart';
import 'package:maintapp/model/email_batch.dart';
import 'package:maintapp/model/user_info.dart';
import 'package:maintapp/model/work_order.dart';
import 'package:maintapp/pages/email_batch_compose_page.dart';
import 'package:maintapp/pages/shared/app_drawer.dart';
import 'package:maintapp/pages/transfer_request_list_page.dart';
import 'package:maintapp/pages/work_order_detail_page.dart';
import 'package:maintapp/pages/work_order_email_history_page.dart';
import 'package:maintapp/pages/work_order_report_pages.dart';
import 'package:maintapp/pages/work_order_report_sign_page.dart';
import 'package:maintapp/state/app_state.dart';
import 'package:maintapp/state/login_session_controller.dart';

class WorkOrderListPage extends StatefulWidget {
  const WorkOrderListPage({super.key});

  @override
  State<WorkOrderListPage> createState() => _WorkOrderListPageState();
}

class _WorkOrderListPageState extends State<WorkOrderListPage> {
  final _institutionController = TextEditingController();
  final _woNoSearchController = TextEditingController();
  final _assetNumberSearchController = TextEditingController();
  final _serialNumberSearchController = TextEditingController();
  final _listHeaderScrollController = ScrollController();
  final _listBodyScrollController = ScrollController();
  bool _syncingHorizontalTableScroll = false;

  final List<String> _workOrderTypes = const ['CM', 'PM'];

  int _activeTypeIndex = 0;
  final List<WorkOrder> _items = [];
  List<UserInfo> _activeEngineers = [];
  List<UserInfo> _allUsers = [];

  bool _isLoading = false;
  // bool _isLoadingUsers = false;
  bool _useCardView = false;
  bool _includeInactiveEngineers = false;
  bool _showMobileFilters = false;
  static const double _cardModeWidthBreakpoint = 680.0;
  static const int _pageSize = 100;
  String _selectedInstitutionCode = '';
  String _selectedPool = 'public_pool';
  String _selectedGroup = 'picked';
  String? _selectedEngineerId;
  List<String> _selectedStatuses = [];
  DateTime? _plannedDateFilter;
  DateTimeRange? _haOutboundRange;
  int _currentPage = 1;
  int _totalItems = 0;
  int _currentOffset = 0;
  String _emailSentFilter = 'not_sent';
  EmailBatchConfig _emailBatchConfig = EmailBatchConfig();
  final Set<String> _selectedEmailWorkOrderIds = {};

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadEmailBatchConfig();
    _loadWorkOrders();
  }

  Future<void> _loadEmailBatchConfig() async {
    final config = await ApiController.getEmailBatchConfig();
    if (!mounted) return;
    setState(() => _emailBatchConfig = config);
  }

  @override
  void dispose() {
    _institutionController.dispose();
    _woNoSearchController.dispose();
    _assetNumberSearchController.dispose();
    _serialNumberSearchController.dispose();
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

    // setState(() => _isLoadingUsers = true);
    setState(() {});
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
        // setState(() => _isLoadingUsers = false);
        setState(() {});
      }
    }
  }

  Future<void> _loadWorkOrders() async {
    setState(() => _isLoading = true);
    String? userFilter;
    String? ownerFilter;
    String? plannedDateFilter;
    String? haOutboundFrom;
    String? haOutboundTo;

    if (_selectedPool == 'my_wos') {
      userFilter = 'me';
    } else if (_selectedPool == 'others_wos') {
      userFilter = 'others';
    }

    if (_showEngineerFilter &&
        _selectedEngineerId != null &&
        _selectedEngineerId!.isNotEmpty) {
      ownerFilter = _selectedEngineerId;
    }

    if (_showPlannedDate && _plannedDateFilter != null) {
      plannedDateFilter = _dateText(_plannedDateFilter);
    }

    final effectiveStatuses = _effectiveStatusesForQuery;
    final statusFilter = effectiveStatuses.join(',');
    final isEmailGroup = _selectedGroup == 'need_send_email';
    final emailSent = !isEmailGroup || _emailSentFilter == 'both'
        ? null
        : _emailSentFilter == 'sent';
    if (_haOutboundRange != null) {
      final start = _haOutboundRange!.start;
      final end = _haOutboundRange!.end;
      haOutboundFrom = DateTime.utc(
        start.year,
        start.month,
        start.day,
        0,
        0,
        0,
      ).toIso8601String();
      haOutboundTo = DateTime.utc(
        end.year,
        end.month,
        end.day,
        23,
        59,
        59,
      ).toIso8601String();
    }

    try {
      final payload = await ApiController.listWorkOrders(
        woType: _activeType,
        user: userFilter,
        page: _currentPage,
        pageSize: _pageSize,
        institution: _selectedInstitutionCode.isEmpty
            ? null
            : _selectedInstitutionCode,
        ownerUserId: ownerFilter,
        plannedDate: plannedDateFilter,
        status: statusFilter.isEmpty ? null : statusFilter,
        emailSent: emailSent,
        woNo: _woNoSearchController.text.trim().isEmpty
            ? null
            : _woNoSearchController.text.trim(),
        assetNumber: _assetNumberSearchController.text.trim().isEmpty
            ? null
            : _assetNumberSearchController.text.trim(),
        serialNumber: _serialNumberSearchController.text.trim().isEmpty
            ? null
            : _serialNumberSearchController.text.trim(),
        haOutboundFrom: haOutboundFrom,
        haOutboundTo: haOutboundTo,
      );
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(payload.items);
        final visibleIds = payload.items.map((item) => item.id).toSet();
        _selectedEmailWorkOrderIds.removeWhere(
          (id) => !visibleIds.contains(id),
        );
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

  Future<void> _pickHaOutboundDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _haOutboundRange,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 3650)),
      saveText: 'Select',
    );
    if (picked != null && mounted) {
      setState(() {
        _haOutboundRange = picked;
        _currentPage = 1;
      });
    }
  }

  void _applyDetailedSearch() {
    setState(() => _currentPage = 1);
    _loadWorkOrders();
  }

  void _clearDetailedSearch() {
    setState(() {
      _woNoSearchController.clear();
      _assetNumberSearchController.clear();
      _serialNumberSearchController.clear();
      _haOutboundRange = null;
      _currentPage = 1;
    });
    _loadWorkOrders();
  }

  bool get _hasEngineerRole =>
      _hasRole(LoginSessionController.instance.userInfo, 'ENGINEER');

  bool get _usesEngineerPools => _hasEngineerRole;

  bool get _isPublicPool => _selectedPool == 'public_pool';
  bool get _isCancelledPool => _selectedPool == 'cancelled_pool';
  bool get _isMyWOsPool => _selectedPool == 'my_wos';
  bool get _isOthersWOsPool => _selectedPool == 'others_wos';

  bool get _showEngineerFilter =>
      !_isPublicPool &&
      !_isCancelledPool &&
      ((_usesEngineerPools && _selectedPool == 'others_wos') ||
          (!_usesEngineerPools && _selectedPool == 'picked_wos'));

  bool get _showPlannedDate =>
      _selectedGroup == 'picked' || _selectedGroup == 'scheduled';

  List<String> get _allowedStatusesForCurrentContext {
    if (_isPublicPool) {
      return const ['unassigned'];
    }
    if (_isCancelledPool) {
      return const ['cancelled'];
    }

    if (_usesEngineerPools) {
      switch (_selectedGroup) {
        case 'picked':
          return const ['assigned', 'cannot_completed', 'planned', 'rejected'];
        case 'scheduled':
          return const ['planned'];
        case 'working':
          return const ['working'];
        case 'need_sign':
          return const ['completed'];
        case 'ended':
          return const [
            'need_approve',
            'approved',
            'email_sent',
            // Legacy work-order statuses kept only for old rows.
            'signed',
          ];
        case 'all':
        default:
          return const [
            'assigned',
            'planned',
            'working',
            'completed',
            'cannot_completed',
            'rejected',
            'need_approve',
            'approved',
            'email_sent',
            // Legacy work-order statuses kept only for old rows.
            'signed',
          ];
      }
    }

    switch (_selectedGroup) {
      case 'picked':
        return const ['assigned', 'planned', 'cannot_completed', 'rejected'];
      case 'working':
        return const ['working', 'completed'];
      case 'need_approve':
        return const [
          'need_approve',
          // Legacy work-order statuses kept only for old rows.
          'signed',
        ];
      case 'need_send_email':
        if (_emailSentFilter == 'sent') return const ['email_sent'];
        if (_emailSentFilter == 'both') {
          return const ['approved', 'email_sent'];
        }
        return const ['approved'];
      case 'ended':
        return const ['email_sent'];
      case 'all':
      default:
        return const [
          'assigned',
          'planned',
          'working',
          'completed',
          'cannot_completed',
          'rejected',
          'need_approve',
          'approved',
          'email_sent',
          // Legacy work-order statuses kept only for old rows.
          'signed',
        ];
    }
  }

  List<String> get _effectiveStatusesForQuery {
    if (_selectedStatuses.isNotEmpty) {
      return _selectedStatuses
          .where(_allowedStatusesForCurrentContext.contains)
          .toList();
    }
    return _allowedStatusesForCurrentContext;
  }

  bool get _showStatusFilter => _allowedStatusesForCurrentContext.length > 1;

  List<(String, String)> get _poolOptions {
    if (_usesEngineerPools) {
      return const [
        ('public_pool', 'Public Pool'),
        ('my_wos', 'My WOs'),
        ('others_wos', "Other's WOs"),
        ('cancelled_pool', 'Cancelled'),
      ];
    }
    return const [
      ('public_pool', 'Public Pool'),
      ('picked_wos', 'Picked WOs'),
      ('cancelled_pool', 'Cancelled'),
    ];
  }

  List<(String, String)> get _groupOptions {
    if (_isPublicPool || _isCancelledPool) return const [];
    if (_usesEngineerPools && _isMyWOsPool) {
      return const [
        ('picked', 'Picked / Scheduled'),
        ('need_sign', 'Need sign'),
        ('ended', 'Ended'),
        ('all', 'All'),
      ];
    }
    if (_usesEngineerPools && _isOthersWOsPool) {
      return const [
        ('all', 'All'),
        ('picked', 'Picked / Scheduled'),
        ('working', 'Working'),
        ('need_sign', 'Need sign'),
        ('ended', 'Ended'),
      ];
    }
    return const [
      ('picked', 'Picked'),
      ('working', 'Working'),
      ('need_approve', 'Need approve'),
      ('need_send_email', 'Need send email'),
      // ('ended', 'Ended'),
      ('all', 'All'),
    ];
  }

  String _defaultGroupForPool(String pool) {
    if (pool == 'public_pool' || pool == 'cancelled_pool') {
      return '';
    } else if (pool == 'others_wos') {
      return 'all';
    }
    return 'picked';
  }

  String _poolLabel(String value) {
    for (final item in _poolOptions) {
      if (item.$1 == value) return item.$2;
    }
    return value;
  }

  String _groupLabel(String value) {
    for (final item in _groupOptions) {
      if (item.$1 == value) return item.$2;
    }
    return value;
  }

  String get _mobileSelectionSummary {
    final pool = _poolLabel(_selectedPool);
    if (_groupOptions.isEmpty || _selectedGroup.isEmpty) {
      return pool;
    }
    return '$pool - ${_groupLabel(_selectedGroup)}';
  }

  String get _selectionSummary => _mobileSelectionSummary;

  String get _mobileFilterSummary {
    final parts = <String>[];
    if (_selectedInstitutionCode.isNotEmpty) {
      parts.add(_selectedInstitutionCode);
    }
    if (_selectedStatuses.isNotEmpty) {
      parts.add(_selectedStatuses.join(', '));
    }
    if (_showEngineerFilter &&
        _selectedEngineerId != null &&
        _selectedEngineerId!.isNotEmpty) {
      String engineerName = 'Engineer selected';
      for (final engineer in _engineersForFilter) {
        if (engineer.id == _selectedEngineerId) {
          engineerName = _displayName(engineer);
          break;
        }
      }
      parts.add(engineerName);
    }
    if (_showPlannedDate && _plannedDateFilter != null) {
      parts.add('Planned ${_dateText(_plannedDateFilter)}');
    }
    if (_woNoSearchController.text.trim().isNotEmpty) {
      parts.add('WO ${_woNoSearchController.text.trim()}');
    }
    if (_assetNumberSearchController.text.trim().isNotEmpty) {
      parts.add('Asset ${_assetNumberSearchController.text.trim()}');
    }
    if (_serialNumberSearchController.text.trim().isNotEmpty) {
      parts.add('Serial ${_serialNumberSearchController.text.trim()}');
    }
    if (_haOutboundRange != null) {
      parts.add(_dateRangeText(_haOutboundRange));
    }
    return parts.join(' • ');
  }

  void _onPoolChanged(String value) {
    if (_selectedPool == value) return;
    setState(() {
      _selectedPool = value;
      _selectedGroup = _defaultGroupForPool(value);
      _selectedEngineerId = null;
      _selectedStatuses = [];
      _selectedEmailWorkOrderIds.clear();
      _plannedDateFilter = null;
      _currentPage = 1;
    });
    _loadWorkOrders();
  }

  void _onGroupChanged(String value) {
    if (_selectedGroup == value) return;
    setState(() {
      _selectedGroup = value;
      _selectedStatuses = [];
      _selectedEmailWorkOrderIds.clear();
      if (!_showPlannedDate) {
        _plannedDateFilter = null;
      }
      _currentPage = 1;
    });
    _loadWorkOrders();
  }

  bool get _isEmailSelectionMode => _selectedGroup == 'need_send_email';

  void _toggleEmailSelection(WorkOrder item, bool selected) {
    final max = _emailBatchConfig.maxWorkOrders;
    setState(() {
      if (selected) {
        if (max <= 0 || _selectedEmailWorkOrderIds.length < max) {
          _selectedEmailWorkOrderIds.add(item.id);
        }
      } else {
        _selectedEmailWorkOrderIds.remove(item.id);
      }
    });
  }

  void _selectAllFilteredItems() {
    final max = _emailBatchConfig.maxWorkOrders;
    final ids = _items.map((item) => item.id);
    setState(() {
      _selectedEmailWorkOrderIds.clear();
      _selectedEmailWorkOrderIds.addAll(max > 0 ? ids.take(max) : ids);
    });
  }

  Future<void> _sendSelectedWorkOrders() async {
    final selected = _items
        .where((item) => _selectedEmailWorkOrderIds.contains(item.id))
        .toList();
    if (selected.isEmpty) return;
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EmailBatchComposePage(workOrders: selected),
      ),
    );
    if (sent == true && mounted) {
      setState(() => _selectedEmailWorkOrderIds.clear());
      await _loadWorkOrders();
    }
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

  String _statusFilterSummary() {
    if (_selectedStatuses.isEmpty) {
      return _showStatusFilter
          ? 'All in group'
          : _allowedStatusesForCurrentContext.join(', ');
    }
    return _selectedStatuses.join(', ');
  }

  Future<void> _openStatusFilterDialog() async {
    final availableStatuses = _allowedStatusesForCurrentContext;
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
                    children: availableStatuses.map((status) {
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

  void _toggleMobileFilters() {
    setState(() {
      _showMobileFilters = !_showMobileFilters;
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

  Widget _buildEmailSelectionBar() {
    if (!_isEmailSelectionMode) return const SizedBox.shrink();
    final selectedCount = _selectedEmailWorkOrderIds.length;
    final attachmentsSupported = _emailBatchConfig.attachmentsSupported;
    return Material(
      color: Colors.white,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('$selectedCount selected'),
              OutlinedButton(
                onPressed: _items.isEmpty ? null : _selectAllFilteredItems,
                child: const Text('Select All'),
              ),
              TextButton(
                onPressed: selectedCount == 0
                    ? null
                    : () => setState(() => _selectedEmailWorkOrderIds.clear()),
                child: const Text('Clear'),
              ),
              FilledButton.icon(
                onPressed: selectedCount == 0 || !attachmentsSupported
                    ? null
                    : _sendSelectedWorkOrders,
                icon: const Icon(Icons.send_outlined),
                label: Text('Send Selected ($selectedCount)'),
              ),
              if (!attachmentsSupported)
                const Text(
                  'Attachments are not supported by the mail provider.',
                  style: TextStyle(color: Color(0xFFB91C1C)),
                ),
            ],
          ),
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
  bool _isPendingTransfer(WorkOrder order) => order.isTransferring;
  String _lookupOwnerNameById(String ownerUserId) {
    if (ownerUserId.isEmpty) return '';
    for (final user in _allUsers) {
      if (user.id == ownerUserId) {
        return _displayName(user);
      }
    }
    return '';
  }

  bool _isOwnerInactive(String ownerUserId) {
    if (ownerUserId.isEmpty) return false;
    for (final user in _allUsers) {
      if (user.id == ownerUserId) {
        return !user.isActive;
      }
    }
    return false;
  }

  String _ownerDisplayName(WorkOrder order) {
    if (order.ownerFullName.isNotEmpty) {
      return order.ownerFullName;
    }
    final fromEngineers = _lookupOwnerNameById(order.ownerUserId);
    return fromEngineers.isNotEmpty ? fromEngineers : order.ownerUserId;
  }

  Widget _buildOwnerNameCell({
    required String ownerName,
    required String ownerUserId,
    required TextStyle style,
  }) {
    final isInactive = _isOwnerInactive(ownerUserId);
    return Row(
      children: [
        if (isInactive)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(Icons.close, size: 14, color: Color(0xFFB91C1C)),
          ),
        Expanded(
          child: SelectionArea(
            child: Text(
              ownerName,
              style: style,
              maxLines: 1,
              // minLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  String _createdDisplayDate(WorkOrder order) {
    return _formatDateTime(_effectiveCreatedAt(order));
  }

  String _plannedScheduleDisplay(WorkOrder order) {
    final rawPlannedDate = order.plannedDate.trim();
    if (rawPlannedDate.isEmpty) return '';
    final plannedDate = rawPlannedDate.contains('T')
        ? rawPlannedDate.split('T').first.trim()
        : rawPlannedDate;
    final plannedHalfDay = order.plannedHalfDay.trim().toUpperCase();
    if (plannedHalfDay == 'AM' || plannedHalfDay == 'PM') {
      return '$plannedDate ($plannedHalfDay)';
    }
    return plannedDate;
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

  Future<({DateTime plannedDate, String plannedHalfDay})?> _promptSchedule(
    String title,
  ) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      helpText: title,
    );
    if (pickedDate == null || !mounted) return null;

    String selectedHalfDay = 'full_day';
    final pickedHalfDay = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Schedule session'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    value: 'AM',
                    groupValue: selectedHalfDay,
                    title: const Text('AM'),
                    onChanged: (value) {
                      if (value == null) return;
                      setStateDialog(() => selectedHalfDay = value);
                    },
                  ),
                  RadioListTile<String>(
                    value: 'PM',
                    groupValue: selectedHalfDay,
                    title: const Text('PM'),
                    onChanged: (value) {
                      if (value == null) return;
                      setStateDialog(() => selectedHalfDay = value);
                    },
                  ),
                  RadioListTile<String>(
                    value: 'full_day',
                    groupValue: selectedHalfDay,
                    title: const Text('Full day'),
                    onChanged: (value) {
                      if (value == null) return;
                      setStateDialog(() => selectedHalfDay = value);
                    },
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
    if (pickedHalfDay == null || pickedHalfDay.isEmpty) return null;
    return (plannedDate: pickedDate, plannedHalfDay: pickedHalfDay);
  }

  Future<void> _viewDetails(WorkOrder order, BuildContext rowContext) async {
    final changed = await Navigator.of(rowContext).push<bool>(
      MaterialPageRoute(
        builder: (_) => WorkOrderDetailPage(workOrderId: order.id),
      ),
    );
    if (changed == true && mounted) {
      await _loadWorkOrders();
    }
  }

  Future<void> _runAction(
    String action,
    WorkOrder order,
    BuildContext rowContext,
  ) async {
    final navigator = Navigator.of(rowContext);
    final scaffoldMessenger = ScaffoldMessenger.of(rowContext);
    try {
      String feedback;
      final user = LoginSessionController.instance.userInfo;
      if (action == 'view_details') {
        final changed = await navigator.push<bool>(
          MaterialPageRoute(
            builder: (_) => WorkOrderDetailPage(workOrderId: order.id),
          ),
        );
        if (changed == true && mounted) await _loadWorkOrders();
        return;
      } else if (action == 'open_incoming_transfers') {
        await navigator.push(
          MaterialPageRoute(
            builder: (_) => const TransferRequestListPage(
              initialMode: TransferRequestPageMode.incoming,
            ),
          ),
        );
        return;
      } else if (action == 'email_history') {
        await navigator.push(
          MaterialPageRoute(
            builder: (_) => WorkOrderEmailHistoryPage(workOrder: order),
          ),
        );
        return;
      } else if (action == 'create_email_draft') {
        final sent = await navigator.push<bool>(
          MaterialPageRoute(
            builder: (_) => EmailBatchComposePage(workOrders: [order]),
          ),
        );
        if (sent == true && mounted) {
          await _loadWorkOrders();
        }
        return;
      } else if (action == 'view_report') {
        final changed = await navigator.push<bool>(
          MaterialPageRoute(
            builder: (_) => WorkOrderDetailPage(workOrderId: order.id),
          ),
        );
        if (changed == true && mounted) await _loadWorkOrders();
        return;
      } else if (action == 'review') {
        final changed = await navigator.push<bool>(
          MaterialPageRoute(
            builder: (_) => WorkOrderDetailPage(workOrderId: order.id),
          ),
        );
        if (changed == true && mounted) await _loadWorkOrders();
        return;
      } else if (action == 'add_remarks') {
        await navigator.push<bool>(
          MaterialPageRoute(
            builder: (_) => WorkOrderReportFormPage(workOrder: order),
          ),
        );
        if (!mounted) return;
        await _loadWorkOrders();
        return;
      } else if (action == 'send_email') {
        final sent = await navigator.push<bool>(
          MaterialPageRoute(
            builder: (_) => EmailBatchComposePage(workOrders: [order]),
          ),
        );
        if (sent == true && mounted) await _loadWorkOrders();
        return;
      } else if (action == 'edit') {
        scaffoldMessenger.showSnackBar(
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
        await ApiController.createTransferRequest(
          order.id,
          toEngineerId: engineerId,
          reason: reason,
        );
        feedback = 'Transfer request created.';
      } else if (action == 'transfer_to_me') {
        final reason = await _promptReason('Take over reason');
        if (reason == null || reason.isEmpty) return;
        await ApiController.createTransferRequest(
          order.id,
          toEngineerId: user.id,
          reason: reason,
        );
        feedback = 'Takeover request created.';
      } else if (action == 'release_to_unassigned') {
        final reason = await _promptReason('Return to public pool');
        if (reason == null || reason.isEmpty) return;
        feedback = await ApiController.releaseWorkOrder(order.id, reason);
      } else if (action == 'plan') {
        final picked = await _promptSchedule('Schedule work order');
        if (picked == null) return;
        feedback = await ApiController.planWorkOrder(
          order.id,
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
          order.id,
          reason,
        );
      } else if (action == 'approve') {
        feedback = await ApiController.approveWorkOrder(order.id);
      } else if (action == 'reject') {
        final reason = await _promptReason('Reject work order');
        if (reason == null || reason.isEmpty) return;
        feedback = await ApiController.rejectWorkOrder(
          order.id,
          reason: reason,
        );
      } else if (action == 'fill_report') {
        if (order.woType.trim().toUpperCase() != 'CM') {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Only CM report is wired now.')),
          );
          return;
        }
        final updated = await navigator.push<bool>(
          MaterialPageRoute(
            builder: (_) => WorkOrderReportFormPage(workOrder: order),
          ),
        );
        if (updated == true) {
          await _loadWorkOrders();
        }
        return;
      } else if (action == 'edit_report') {
        final updated = await navigator.push<bool>(
          MaterialPageRoute(
            builder: (_) => WorkOrderReportFormPage(workOrder: order),
          ),
        );
        if (updated == true) {
          await _loadWorkOrders();
        }
        return;
      } else if (action == 'sign') {
        final updated = await navigator.push<bool>(
          MaterialPageRoute(
            builder: (_) => WorkOrderReportSignPage(workOrder: order),
          ),
        );
        if (updated == true) {
          await _loadWorkOrders();
        }
        return;
      } else if (action == 'start') {
        feedback = await ApiController.startWorkOrder(order.id);
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(SnackBar(content: Text(feedback)));
        await navigator.push(
          MaterialPageRoute(
            builder: (_) => WorkOrderDetailPage(workOrderId: order.id),
          ),
        );
        if (!mounted) return;
        await _loadWorkOrders();
        return;
      } else {
        return;
      }
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(SnackBar(content: Text(feedback)));
      await _loadWorkOrders();
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Action failed: $e')),
      );
    }
  }

  List<PopupMenuEntry<String>> _buildActionItems({
    required WorkOrder order,
    required bool hasManagerRole,
    required bool hasEngineerRole,
  }) {
    if (_isPendingTransfer(order)) {
      return const <PopupMenuEntry<String>>[
        // PopupMenuItem(value: 'view_details', child: Text('View details')),
        // PopupMenuItem(value: 'email_history', child: Text('Email history')),
        PopupMenuItem(
          value: 'open_incoming_transfers',
          child: Text('Manage transfer'),
        ),
      ];
    }

    final items = <PopupMenuEntry<String>>[];

    // items.add(
    //   const PopupMenuItem(value: 'view_details', child: Text('View details')),
    // );

    if (hasManagerRole) {
      final normalizedStatus = order.status.trim().toLowerCase();
      if (_isUnassigned(order) || normalizedStatus == 'unassigned') {
        items.add(
          const PopupMenuItem(
            value: 'assign_to_engineer',
            child: Text('Assign to engineer'),
          ),
        );
      } else if (normalizedStatus == 'assigned' ||
          normalizedStatus == 'planned' ||
          normalizedStatus == 'cannot_completed' ||
          normalizedStatus == 'rejected') {
        items.add(
          const PopupMenuItem(
            value: 'assign_to_engineer',
            child: Text('Assign to engineer'),
          ),
        );
        items.add(
          const PopupMenuItem(
            value: 'revoke_to_unassigned',
            child: Text('Return to public pool'),
          ),
        );
      } else if (normalizedStatus == 'need_approve' ||
          normalizedStatus == 'signed') {
        items.add(
          normalizedStatus == 'need_approve'
              ? const PopupMenuItem(value: 'review', child: Text('Review'))
              : const PopupMenuItem(
                  value: 'view_report',
                  child: Text('View Report'),
                ),
        );
        items.add(
          const PopupMenuItem(value: 'edit_report', child: Text('Edit Report')),
        );
        if (normalizedStatus != 'need_approve') {
          items.add(
            const PopupMenuItem(
              value: 'add_remarks',
              child: Text('Add remarks'),
            ),
          );
        }
        // items.add(const PopupMenuItem(value: 'approve', child: Text('Accept')));
        // items.add(const PopupMenuItem(value: 'reject', child: Text('Reject')));
      } else if (normalizedStatus == 'approved') {
        items.add(
          const PopupMenuItem(value: 'send_email', child: Text('Send email')),
        );
      }
    }

    if (hasEngineerRole) {
      final normalizedStatus = order.status.trim().toLowerCase();

      if (_isUnassigned(order)) {
        items.add(const PopupMenuItem(value: 'take', child: Text('Take it')));
      } else if (_isMine(order)) {
        if (normalizedStatus == 'assigned' ||
            normalizedStatus == 'cannot_completed' ||
            normalizedStatus == 'rejected') {
          items.add(
            const PopupMenuItem(value: 'plan', child: Text('Schedule')),
          );
          items.add(
            const PopupMenuItem(value: 'start', child: Text('Start work')),
          );
          items.add(
            const PopupMenuItem(
              value: 'transfer_away',
              child: Text('Hand off'),
            ),
          );
          if (!hasManagerRole) {
            items.add(
              const PopupMenuItem(
                value: 'release_to_unassigned',
                child: Text('Return to public pool'),
              ),
            );
          }
        } else if (normalizedStatus == 'planned') {
          items.add(
            const PopupMenuItem(value: 'plan', child: Text('Re-schedule')),
          );
          items.add(
            const PopupMenuItem(value: 'start', child: Text('Start work')),
          );
          items.add(
            const PopupMenuItem(
              value: 'transfer_away',
              child: Text('Hand off'),
            ),
          );
          if (!hasManagerRole) {
            items.add(
              const PopupMenuItem(
                value: 'release_to_unassigned',
                child: Text('Return to public pool'),
              ),
            );
          }
        } else if (normalizedStatus == 'working') {
          items.add(
            const PopupMenuItem(
              value: 'fill_report',
              child: Text('Fill report'),
            ),
          );
          items.add(
            const PopupMenuItem(
              value: 'cannot_complete',
              child: Text('Cannot complete'),
            ),
          );
        } else if (normalizedStatus == 'completed') {
          items.add(
            const PopupMenuItem(value: 'sign', child: Text('Review and Sign')),
          );
          items.add(
            const PopupMenuItem(
              value: 'edit_report',
              child: Text('Edit Report'),
            ),
          );
        }
      } else if (_isAssignedToOthers(order)) {
        if (normalizedStatus == 'assigned' || normalizedStatus == 'planned') {
          items.add(
            const PopupMenuItem(
              value: 'transfer_to_me',
              child: Text('Take over'),
            ),
          );
        }
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
    if (result is ApiMessageResult) return result.message;
    if (result is WorkOrderActionResult) {
      return result.message.isNotEmpty ? result.message : 'Done';
    }
    if (result is AdminPingResult) {
      return result.message.isNotEmpty ? result.message : result.status;
    }
    if (result is Map) {
      final raw = Map<dynamic, dynamic>.from(result);
      if (raw['message'] is String) return raw['message'] as String;
      if (raw['error'] is String) return raw['error'] as String;
    }
    return 'Done';
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
    } else if (normalized == 'rejected') {
      backgroundColor = const Color(0xFFFFF1F2);
      borderColor = const Color(0xFFFECDD3);
      textColor = const Color(0xFFBE123C);
    } else if (normalized == 'picked' ||
        normalized == 'in_progress' ||
        normalized == 'planned') {
      backgroundColor = const Color(0xFFDBEAFE);
      borderColor = const Color(0xFFBFDBFE);
      textColor = const Color(0xFF1D4ED8);
    } else if (normalized == 'need_approve') {
      backgroundColor = const Color(0xFFFEF3C7);
      borderColor = const Color(0xFFFDE68A);
      textColor = const Color(0xFF92400E);
    } else if (normalized == 'approved' || normalized == 'email_sent') {
      backgroundColor = const Color(0xFFE0F2FE);
      borderColor = const Color(0xFFBAE6FD);
      textColor = const Color(0xFF075985);
    } else if (normalized == 'completed' || normalized == 'signed') {
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
    } else if (normalized == 'rejected') {
      textColor = const Color(0xFFBE123C);
    } else if (normalized == 'picked' ||
        normalized == 'in_progress' ||
        normalized == 'planned') {
      textColor = const Color(0xFF1D4ED8);
    } else if (normalized == 'need_approve') {
      textColor = const Color(0xFF92400E);
    } else if (normalized == 'approved' || normalized == 'email_sent') {
      textColor = const Color(0xFF075985);
    } else if (normalized == 'completed' || normalized == 'signed') {
      textColor = const Color(0xFF166534);
    }

    return Tooltip(
      message: status,
      child: SizedBox(
        width: maxWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              status,
              maxLines: 1,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            if (normalized == 'planned' &&
                _plannedScheduleDisplay(order).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _plannedScheduleDisplay(order),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            if (_isPendingTransfer(order))
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Pending transfer',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9A3412),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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

  Widget _buildStatusTagColumn(WorkOrder order) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildStatusChip(order),
        if (_isPendingTransfer(order)) ...[
          const SizedBox(height: 6),
          _buildPendingTransferChip(),
        ],
      ],
    );
  }

  Widget _buildRow(
    BuildContext context,
    WorkOrder item, {
    required bool hasManagerRole,
    required bool hasEngineerRole,
  }) {
    final isCritical = _isPriorityCritical(item);
    final rowBackgroundColor = isCritical
        ? const Color(0xFFFFF1F2)
        : Colors.white;
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
      color: rowBackgroundColor,
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 16),
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isEmailSelectionMode)
                  Checkbox(
                    value: _selectedEmailWorkOrderIds.contains(item.id),
                    onChanged: (value) =>
                        _toggleEmailSelection(item, value ?? false),
                  ),
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
                            child: InkWell(
                              onTap: () => _viewDetails(item, context),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                  horizontal: 2,
                                ),
                                child: Text(
                                  item.woNo.isNotEmpty
                                      ? item.woNo
                                      : item.displayLabel,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                    color: _isPriorityCritical(item)
                                        ? const Color(0xFFB91C1C)
                                        : const Color(0xFF0F172A),
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
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
                              child: _buildOwnerNameCell(
                                ownerName: ownerName,
                                ownerUserId: item.ownerUserId,
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
                      if (_isPendingTransfer(item)) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Transfer request pending',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF9A3412),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      _buildLocationDisplay(item.locationCode),
                      if (item.status.trim().toLowerCase() == 'planned' &&
                          _plannedScheduleDisplay(item).isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.event_note_outlined,
                              size: 16,
                              color: Color(0xFF334155),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: SelectableText(
                                _plannedScheduleDisplay(item),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF334155),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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
            Positioned(top: 0, right: 0, child: _buildStatusTagColumn(item)),
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
    final isCritical = _isPriorityCritical(item);
    final rowBackgroundColor = isCritical
        ? const Color(0xFFFFF1F2)
        : Colors.white;
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
      decoration: BoxDecoration(
        color: rowBackgroundColor,
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
                if (_isEmailSelectionMode)
                  Checkbox(
                    value: _selectedEmailWorkOrderIds.contains(item.id),
                    onChanged: (value) =>
                        _toggleEmailSelection(item, value ?? false),
                    visualDensity: VisualDensity.compact,
                  ),
                if (hasWorkOrderIndicators) ...[
                  workOrderIcons,
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: InkWell(
                    onTap: () => _viewDetails(item, context),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 2,
                        horizontal: 2,
                      ),
                      child: Text(
                        item.woNo.isNotEmpty ? item.woNo : item.displayLabel,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _isPriorityCritical(item)
                              ? const Color(0xFFB91C1C)
                              : const Color(0xFF0F172A),
                          decoration: TextDecoration.underline,
                        ),
                      ),
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
            child: hasPickedEngineer
                ? _buildOwnerNameCell(
                    ownerName: ownerName,
                    ownerUserId: item.ownerUserId,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1D4ED8),
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : const SelectableText(
                    '-',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF334155),
                      fontWeight: FontWeight.w400,
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
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      ),
    );
  }

  String _dateText(DateTime? value) {
    if (value == null) return 'Any';
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  String _dateRangeText(DateTimeRange? value) {
    if (value == null) return 'HA outbound date range';
    return '${_dateText(value.start)} to ${_dateText(value.end)}';
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
    final dropdownEngineers = _selectedPool == 'others_wos'
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
          ...dropdownEngineers.map(
            (engineer) => DropdownMenuItem(
              value: engineer.id,
              child: Text(
                engineer.isActive
                    ? _displayName(engineer)
                    : '${_displayName(engineer)} (inactive)',
              ),
            ),
          ),
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

  Widget _buildDetailedSearchContent(bool useCompactLayout) {
    final dateRangeButton = OutlinedButton.icon(
      onPressed: _pickHaOutboundDateRange,
      icon: const Icon(Icons.date_range_outlined, size: 18),
      label: Text(_dateRangeText(_haOutboundRange)),
    );
    final hasDetailedSearchValue =
        _woNoSearchController.text.trim().isNotEmpty ||
        _assetNumberSearchController.text.trim().isNotEmpty ||
        _serialNumberSearchController.text.trim().isNotEmpty ||
        _haOutboundRange != null;

    final content = useCompactLayout
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailedSearchTextField(
                controller: _woNoSearchController,
                label: 'WO Number',
              ),
              const SizedBox(height: 12),
              _buildDetailedSearchTextField(
                controller: _assetNumberSearchController,
                label: 'Asset Number',
              ),
              const SizedBox(height: 12),
              _buildDetailedSearchTextField(
                controller: _serialNumberSearchController,
                label: 'Serial Number',
              ),
              const SizedBox(height: 12),
              dateRangeButton,
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton(
                    onPressed: _applyDetailedSearch,
                    child: const Text('Search'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: hasDetailedSearchValue
                        ? _clearDetailedSearch
                        : null,
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ],
          )
        : Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildDetailedSearchTextField(
                controller: _woNoSearchController,
                label: 'WO Number',
                width: 180,
              ),
              _buildDetailedSearchTextField(
                controller: _assetNumberSearchController,
                label: 'Asset Number',
                width: 180,
              ),
              _buildDetailedSearchTextField(
                controller: _serialNumberSearchController,
                label: 'Serial Number',
                width: 200,
              ),
              dateRangeButton,
              FilledButton(
                onPressed: _applyDetailedSearch,
                child: const Text('Search'),
              ),
              TextButton(
                onPressed: hasDetailedSearchValue ? _clearDetailedSearch : null,
                child: const Text('Clear'),
              ),

              // const SizedBox(height: 12),
              // toggleDetailButton,
            ],
          );

    return content;
  }

  Widget _buildDetailedSearchTextField({
    required TextEditingController controller,
    required String label,
    double width = double.infinity,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
        onSubmitted: (_) => _applyDetailedSearch(),
      ),
    );
  }

  // Widget _buildDetailedSearchToggle() {
  //   return Align(
  //     alignment: Alignment.centerLeft,
  //     child: TextButton.icon(
  //       onPressed: () {
  //         setState(() => _showDetailedSearch = !_showDetailedSearch);
  //       },
  //       icon: Icon(
  //         _showDetailedSearch
  //             ? Icons.keyboard_arrow_up
  //             : Icons.keyboard_arrow_down,
  //       ),
  //       label: Text(
  //         _showDetailedSearch
  //             ? 'Hide detailed search'
  //             : 'More search options',
  //       ),
  //     ),
  //   );
  // }

  Widget _buildPoolSelector({required bool useCompactLayout}) {
    final options = _poolOptions;
    final screenWidth = MediaQuery.of(context).size.width;
    final veryCompact =
        (useCompactLayout && screenWidth <= 440) || screenWidth >= 1200;
    if (useCompactLayout || screenWidth >= 1200) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: options
            .map(
              (item) => Tooltip(
                message: item.$2,
                child: ChoiceChip(
                  label: veryCompact
                      ? Icon(
                          _poolIconForValue(item.$1),
                          size: 16,
                          color: _selectedPool == item.$1
                              ? Colors.white
                              : const Color(0xFF334155),
                        )
                      : Text(item.$2),
                  selected: _selectedPool == item.$1,
                  onSelected: (_) => _onPoolChanged(item.$1),
                  selectedColor: const Color(0xFF0F766E),
                  showCheckmark: false,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: const VisualDensity(
                    horizontal: -2,
                    vertical: -2,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: veryCompact ? 6 : 8,
                    vertical: 6,
                  ),
                  labelStyle: TextStyle(
                    color: _selectedPool == item.$1
                        ? Colors.white
                        : const Color(0xFF334155),
                    fontSize: veryCompact ? 11 : 12,
                    fontWeight: _selectedPool == item.$1
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
            )
            .toList(),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map(
            (item) => ChoiceChip(
              label: Text(item.$2),
              selected: _selectedPool == item.$1,
              onSelected: (_) => _onPoolChanged(item.$1),
              selectedColor: const Color(0xFF0F766E),
              showCheckmark: false,
              labelStyle: TextStyle(
                color: _selectedPool == item.$1
                    ? Colors.white
                    : const Color(0xFF334155),
                fontWeight: _selectedPool == item.$1
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildGroupSelector() {
    final options = _groupOptions;
    if (options.isEmpty) {
      return const SizedBox.shrink();
    }
    final screenWidth = MediaQuery.of(context).size.width;
    final veryCompact = screenWidth <= 440 || screenWidth >= 1200;
    return Wrap(
      spacing: veryCompact ? 4 : 6,
      runSpacing: veryCompact ? 4 : 6,
      children: options
          .map(
            (item) => Tooltip(
              message: item.$2,
              child: ChoiceChip(
                label: veryCompact
                    ? Icon(
                        _groupIconForValue(item.$1),
                        size: 14,
                        color: _selectedGroup == item.$1
                            ? Colors.white
                            : const Color(0xFF334155),
                      )
                    : Text(item.$2),
                selected: _selectedGroup == item.$1,
                onSelected: (_) => _onGroupChanged(item.$1),
                selectedColor: const Color(0xFF2563EB),
                showCheckmark: false,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: veryCompact
                    ? const VisualDensity(horizontal: -3, vertical: -3)
                    : const VisualDensity(horizontal: -2, vertical: -2),
                padding: EdgeInsets.symmetric(
                  horizontal: veryCompact ? 4 : 8,
                  vertical: veryCompact ? 4 : 6,
                ),
                labelStyle: TextStyle(
                  color: _selectedGroup == item.$1
                      ? Colors.white
                      : const Color(0xFF334155),
                  fontSize: veryCompact ? 11 : 12,
                  fontWeight: _selectedGroup == item.$1
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  IconData _poolIconForValue(String value) {
    switch (value) {
      case 'public_pool':
        return Icons.move_to_inbox_outlined;
      case 'cancelled_pool':
        return Icons.cancel_outlined;
      case 'my_wos':
        return Icons.assignment_ind_outlined;
      case 'others_wos':
        return Icons.people_alt_outlined;
      case 'picked_wos':
        return Icons.work_outline;
      default:
        return Icons.radio_button_checked;
    }
  }

  IconData _groupIconForValue(String value) {
    switch (value) {
      case 'picked':
        return Icons.pan_tool_alt_outlined;
      case 'scheduled':
        return Icons.event_note_outlined;
      case 'working':
        return Icons.build_circle_outlined;
      case 'need_sign':
        return Icons.draw_outlined;
      case 'need_approve':
        return Icons.fact_check_outlined;
      case 'need_send_email':
        return Icons.outgoing_mail;
      case 'ended':
        return Icons.task_alt_outlined;
      case 'all':
        return Icons.apps_outlined;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.label_outline;
    }
  }

  Widget _buildFilterPanel({required bool useCompactLayout}) {
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

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!useCompactLayout) ...[
          Text(
            _selectionSummary,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 10),
          _buildPoolSelector(useCompactLayout: useCompactLayout),
          if (_groupOptions.isNotEmpty) ...[const SizedBox(height: 8)],
        ],
        if (!useCompactLayout && _groupOptions.isNotEmpty) ...[
          _buildGroupSelector(),
        ],
        const SizedBox(height: 16),
        _buildInstitutionAutocomplete(double.infinity),
        if (_isEmailSelectionMode) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _emailSentFilter,
            decoration: const InputDecoration(
              labelText: 'Email Status',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'not_sent',
                child: Text('Email not Sent'),
              ),
              DropdownMenuItem(value: 'sent', child: Text('Email is Sent')),
              DropdownMenuItem(value: 'both', child: Text('Both')),
            ],
            onChanged: (value) {
              if (value == null || value == _emailSentFilter) return;
              setState(() {
                _emailSentFilter = value;
                _selectedStatuses = [];
                _selectedEmailWorkOrderIds.clear();
                _currentPage = 1;
              });
              _loadWorkOrders();
            },
          ),
        ],
        if (_showStatusFilter) ...[
          const SizedBox(height: 12),
          _buildStatusField(double.infinity),
        ],
        if (_showEngineerFilter) ...[
          const SizedBox(height: 12),
          _buildEngineerDropdown(double.infinity, enabled: true),
          const SizedBox(height: 4),
          _buildIncludeInactiveEngineersCheckbox(),
        ],
        if (_showPlannedDate) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [plannedDateButton, plannedDateClear],
          ),
        ],
        const SizedBox(height: 8),
        _buildDetailedSearchContent(useCompactLayout),
      ],
    );

    return _buildQuickFilterContainer(title: 'Filters', child: content);
  }

  Widget _buildWorkOrderListContent({
    required bool shouldUseCardView,
    required bool hasManagerRole,
    required bool hasAdminRole,
    required bool hasEngineerRole,
    required double bottomContentPadding,
  }) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return const Center(child: Text('No work orders found.'));
    }

    if (shouldUseCardView) {
      return LayoutBuilder(
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
            padding: EdgeInsets.fromLTRB(16, 0, 16, bottomContentPadding),
            child: Column(
              children: rows
                  .map(
                    (rowItems) => Padding(
                      padding: const EdgeInsets.only(bottom: spacing),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var index = 0; index < columns; index++) ...[
                              if (index > 0) const SizedBox(width: spacing),
                              Expanded(
                                child: index < rowItems.length
                                    ? _buildRow(
                                        context,
                                        rowItems[index],
                                        hasManagerRole:
                                            hasManagerRole || hasAdminRole,
                                        hasEngineerRole: hasEngineerRole,
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
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth * 0.95;
        final sidePadding = (constraints.maxWidth - tableWidth) / 2;

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
            ((tableWidth - safeActionsWidth) * (woWidthWeight / sumWeight))
                .toInt();
        final createdWidth =
            ((tableWidth - safeActionsWidth) * (createdWidthWeight / sumWeight))
                .toInt();
        final locationWidth =
            ((tableWidth - safeActionsWidth) *
                    (locationWidthWeight / sumWeight))
                .toInt();
        final deviceWidth =
            ((tableWidth - safeActionsWidth) * (deviceWidthWeight / sumWeight))
                .toInt();
        final issueWidth =
            ((tableWidth - safeActionsWidth) * (issueWidthWeight / sumWeight))
                .toInt();
        final ownerWidth =
            ((tableWidth - safeActionsWidth) * (ownerWidthWeight / sumWeight))
                .toInt();
        final statusWidth =
            ((tableWidth - safeActionsWidth) * (statusWidthWeight / sumWeight))
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
            _buildTableHeaderCell('WO Number', woWidth.toDouble()),
            _buildTableHeaderCell('HA Created At', createdWidth.toDouble()),
            _buildTableHeaderCell('Location', locationWidth.toDouble()),
            _buildTableHeaderCell('Device', deviceWidth.toDouble()),
            _buildTableHeaderCell('Issue', issueWidth.toDouble()),
            _buildTableHeaderCell('Taken By', ownerWidth.toDouble()),
            _buildTableHeaderCell('Status', statusWidth.toDouble()),
            _buildTableHeaderCell('', realActionsWidth.toDouble()),
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
                padding: EdgeInsets.symmetric(horizontal: sidePadding),
                child: SingleChildScrollView(
                  controller: _listHeaderScrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: SizedBox(width: tableWidth, child: headerRow),
                ),
              ),
            ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (!_syncingHorizontalTableScroll) {
                    _syncHorizontalTableScroll(
                      sourceController: _listBodyScrollController,
                      targetController: _listHeaderScrollController,
                      offset: notification.metrics.pixels,
                    );
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: sidePadding),
                    controller: _listBodyScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    child: SizedBox(
                      width: tableWidth,
                      child: Column(
                        children: [...listRows, const SizedBox(height: 8)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
    // final useCompactFilters = screenWidth < 980;
    final useDesktopSidebar = screenWidth >= 1200;
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
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadWorkOrders,
            icon: const Icon(Icons.refresh),
          ),
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
      body: useDesktopSidebar
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: _buildWorkOrderListContent(
                          shouldUseCardView: shouldUseCardView,
                          hasManagerRole: hasManagerRole,
                          hasAdminRole: hasAdminRole,
                          hasEngineerRole: hasEngineerRole,
                          bottomContentPadding: bottomContentPadding,
                        ),
                      ),
                      _buildEmailSelectionBar(),
                      _buildPaginationBar(hasFloatingButton: hasManagerRole),
                    ],
                  ),
                ),
                SizedBox(
                  width: 375,
                  child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 12, right: 12),
                      child: _buildFilterPanel(useCompactLayout: false),
                    ),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                _buildQuickFilterContainer(
                  title: 'Pool',
                  child: Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 36),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (screenWidth <= 440) ...[
                              Text(
                                _mobileSelectionSummary,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            _buildPoolSelector(useCompactLayout: true),
                            if (_groupOptions.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _buildGroupSelector(),
                            ],
                            if (!_showMobileFilters &&
                                _mobileFilterSummary.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                _mobileFilterSummary,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: IconButton(
                          onPressed: _toggleMobileFilters,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 30,
                            minHeight: 30,
                          ),
                          visualDensity: const VisualDensity(
                            horizontal: -4,
                            vertical: -4,
                          ),
                          tooltip: _showMobileFilters
                              ? 'Hide filters'
                              : 'Show filters',
                          icon: Icon(
                            _showMobileFilters ? Icons.tune : Icons.tune,
                            size: 18,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_showMobileFilters)
                  _buildFilterPanel(useCompactLayout: true),
                Expanded(
                  child: _buildWorkOrderListContent(
                    shouldUseCardView: shouldUseCardView,
                    hasManagerRole: hasManagerRole,
                    hasAdminRole: hasAdminRole,
                    hasEngineerRole: hasEngineerRole,
                    bottomContentPadding: bottomContentPadding,
                  ),
                ),
                _buildEmailSelectionBar(),
                _buildPaginationBar(hasFloatingButton: hasManagerRole),
              ],
            ),
    );
  }
}
