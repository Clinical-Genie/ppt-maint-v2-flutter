import 'package:flutter/material.dart';
import 'package:maintapp/api/api_controller.dart';
import 'package:maintapp/model/user_info.dart';
import 'package:maintapp/model/work_order.dart';
import 'package:maintapp/pages/shared/app_drawer.dart';
import 'package:maintapp/state/login_session_controller.dart';

class WorkOrderListPage extends StatefulWidget {
  const WorkOrderListPage({super.key});

  @override
  State<WorkOrderListPage> createState() => _WorkOrderListPageState();
}

class _WorkOrderListPageState extends State<WorkOrderListPage> {
  final _searchController = TextEditingController();

  final List<String> _workOrderTypes = const ['CM', 'PM'];
  int _activeTypeIndex = 0;
  final List<WorkOrder> _items = [];
  final List<WorkOrder> _filteredItems = [];
  List<UserInfo> _activeEngineers = [];
  List<UserInfo> _allUsers = [];

  bool _isLoading = false;
  bool _isLoadingUsers = false;
  String _searchQuery = '';
  String _assignedFilter = 'unassigned';
  String? _selectedEngineerId;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadWorkOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _activeType => _workOrderTypes[_activeTypeIndex];
  String get _userId => LoginSessionController.instance.userInfo.id;

  bool _isEngineer(UserInfo user) {
    return user.roles.any((role) => role.toUpperCase() == 'ENGINEER');
  }

  Future<void> _loadUsers() async {
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
    } finally {
      if (mounted) {
        setState(() => _isLoadingUsers = false);
      }
    }
  }

  Future<void> _loadWorkOrders() async {
    setState(() => _isLoading = true);
    String? ownerFilter;
    if (_assignedFilter == 'me') {
      ownerFilter = _userId;
    } else if (_assignedFilter == 'other' && _selectedEngineerId != null) {
      ownerFilter = _selectedEngineerId;
    }

    try {
      final payload = await ApiController.listWorkOrders(
        woType: _activeType,
        pageSize: 100,
        ownerUserId: ownerFilter,
      );
      if (!mounted) return;
      _items
        ..clear()
        ..addAll(payload.items);
      _applyFilters();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onWorkOrderTypeChanged(int index) {
    if (index == _activeTypeIndex) return;
    setState(() => _activeTypeIndex = index);
    _loadWorkOrders();
  }

  void _applyFilters() {
    final q = _searchQuery.trim().toLowerCase();
    final start = _dateFrom;
    final end = _dateTo;

    final filtered = _items.where((item) {
      final queryMatch =
          q.isEmpty ||
          item.woNo.toLowerCase().contains(q) ||
          item.assetNumber.toLowerCase().contains(q) ||
          item.serialNumber.toLowerCase().contains(q) ||
          item.locationCode.toLowerCase().contains(q) ||
          item.contactName.toLowerCase().contains(q) ||
          item.contactNumber.toLowerCase().contains(q) ||
          item.remark.toLowerCase().contains(q) ||
          item.description.toLowerCase().contains(q) ||
          item.referenceNumber.toLowerCase().contains(q) ||
          item.ownerFullName.toLowerCase().contains(q) ||
          _ownerDisplayName(item).toLowerCase().contains(q);

      if (!queryMatch) return false;

      final ownerMatch = switch (_assignedFilter) {
        'all' => true,
        'unassigned' => item.ownerUserId.isEmpty,
        'me' => item.ownerUserId == LoginSessionController.instance.userInfo.id,
        'other' =>
          _selectedEngineerId != null
              ? item.ownerUserId == _selectedEngineerId
              : false,
        _ => true,
      };
      if (!ownerMatch) return false;

      if (start != null || end != null) {
        final date =
            DateTime.tryParse(item.haCreatedAt) ??
            DateTime.tryParse(item.createdAt) ??
            DateTime.tryParse(item.cmBreakdownAt) ??
            DateTime.tryParse(item.pmDeadlineAt) ??
            DateTime.tryParse(item.haOutboundAt) ??
            DateTime.tryParse(item.plannedDate) ??
            DateTime.tryParse(item.dueDate) ??
            DateTime.tryParse(item.createdAt) ??
            DateTime.now();
        if (start != null && date.isBefore(start)) return false;
        if (end != null) {
          final endDate = DateTime(end.year, end.month, end.day, 23, 59, 59);
          if (date.isAfter(endDate)) return false;
        }
      }

      return true;
    }).toList();

    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _filteredItems
      ..clear()
      ..addAll(filtered);
    setState(() {});
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
      _applyFilters();
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
      _applyFilters();
    }
  }

  void _onSearch() {
    setState(() => _searchQuery = _searchController.text);
    _applyFilters();
  }

  void _onAssignedFilterChanged(String? value) {
    if (value == null) return;
    setState(() {
      _assignedFilter = value;
      if (value != 'other') {
        _selectedEngineerId = null;
      }
    });
    _loadWorkOrders();
  }

  void _onEngineerChanged(String? engineerId) {
    setState(() {
      _selectedEngineerId = engineerId;
      _assignedFilter = engineerId == null ? 'all' : 'other';
    });
    _loadWorkOrders();
  }

  String _displayName(UserInfo user) {
    if (user.fullName.isNotEmpty) return user.fullName;
    if (user.username.isNotEmpty) return user.username;
    return user.id;
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
    return _formatDateTime(
      order.haCreatedAt.isNotEmpty ? order.haCreatedAt : order.createdAt,
    );
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeStr;
    }
  }

  String _buildLocationLabel(WorkOrder order, bool isManager) {
    if (isManager) {
      final institutionCode = order.institutionCodeOrFromLocation;
      if (institutionCode.isNotEmpty) {
        return institutionCode;
      }
    }
    return order.locationCode;
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
        final reason = await _promptReason('Put back to unassigned');
        if (reason == null || reason.isEmpty) return;
        feedback = await ApiController.releaseWorkOrder(order.id, reason);
      } else if (action == 'cancel') {
        final reason = await _promptReason('Cancel work order');
        if (reason == null || reason.isEmpty) return;
        feedback = await ApiController.cancelWorkOrder(order.id, reason);
      } else if (action == 'take') {
        feedback = await ApiController.pickWorkOrder(order.id);
      } else if (action == 'transfer_away') {
        final engineerId = await _promptEngineerId(
          title: 'Transfer away to',
          excludeUserId: user.id,
        );
        if (engineerId == null || engineerId.isEmpty) return;
        final reason = await _promptReason('Transfer away reason');
        if (reason == null || reason.isEmpty) return;
        feedback = _toActionMessage(
          await ApiController.assignWorkOrder(
            order.id,
            targetUserId: engineerId,
            reason: reason,
          ),
        );
      } else if (action == 'transfer_to_me') {
        final reason = await _promptReason('Transfer to me reason');
        if (reason == null || reason.isEmpty) return;
        feedback = _toActionMessage(
          await ApiController.assignWorkOrder(
            order.id,
            targetUserId: user.id,
            reason: reason,
          ),
        );
      } else if (action == 'release_to_unassigned') {
        final reason = await _promptReason('Put back to unassigned');
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
            child: Text('Put back to unassigned'),
          ),
        );
      }
      items.add(const PopupMenuItem(value: 'cancel', child: Text('Cancel')));
    }

    if (hasEngineerRole) {
      if (_isUnassigned(order)) {
        items.add(const PopupMenuItem(value: 'take', child: Text('Take it')));
      } else if (_isMine(order)) {
        items.add(
          const PopupMenuItem(
            value: 'transfer_away',
            child: Text('Transfer away request (with reason)'),
          ),
        );
        items.add(
          const PopupMenuItem(
            value: 'release_to_unassigned',
            child: Text('Put back to unassigned (with reason)'),
          ),
        );
        items.add(const PopupMenuItem(value: 'plan', child: Text('Schedule')));
        items.add(
          const PopupMenuItem(value: 'start', child: Text('Start work')),
        );
      } else if (_isAssignedToOthers(order)) {
        items.add(
          const PopupMenuItem(
            value: 'transfer_to_me',
            child: Text('Transfer to me request (with reason)'),
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

  Widget _buildRow(
    BuildContext context,
    WorkOrder item, {
    required bool hasManagerRole,
    required bool hasEngineerRole,
  }) {
    return Card(
      color: Colors.white,
      child: ListTile(
        title: Row(
          spacing: 12,
          children: [
            SelectableText(
              item.woNo.isNotEmpty ? item.woNo : item.displayLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            _buildOwnerChip(item),
          ],
        ),
        subtitle: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  'Created: ${_createdDisplayDate(item)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                if (_buildLocationLabel(item, hasManagerRole).isNotEmpty)
                  SelectableText(_buildLocationLabel(item, hasManagerRole)),
                SelectableText(
                  [
                    if (item.deviceBrand.isNotEmpty) item.deviceBrand,
                    if (item.deviceModel.isNotEmpty) item.deviceModel,
                  ].join(' '),
                ),
              ],
            ),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Description: ',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Expanded(
                  child: SelectableText(_buildDescriptionWithRemark(item)),
                ),
              ],
            ),
            if (item.status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SelectableText(
                  'Status: ${item.status}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
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
    );
  }

  String _dateText(DateTime? value) {
    if (value == null) return 'Any';
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  bool _hasRole(UserInfo user, String role) {
    return user.roles.any((item) => item.toUpperCase() == role);
  }

  @override
  Widget build(BuildContext context) {
    final user = LoginSessionController.instance.userInfo;

    final hasManagerRole = _hasRole(user, 'MANAGER');
    final hasEngineerRole = _hasRole(user, 'ENGINEER');
    final hasAdminRole = _hasRole(user, 'ADMIN');

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      drawer: AppDrawer(user: user),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Work Orders',
          style: TextStyle(
            color: Color(0xFF334155),
            fontWeight: FontWeight.w900,
          ),
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
                children: const [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.build, size: 14),
                      SizedBox(width: 4),
                      Text('CM', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule, size: 14),
                      SizedBox(width: 4),
                      Text('PM', style: TextStyle(fontSize: 11)),
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText:
                                  'Search by WO no, asset, serial, location, contact, remark',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.search),
                                onPressed: _onSearch,
                              ),
                            ),
                            onSubmitted: (_) => _onSearch(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                            _applyFilters();
                          },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        DropdownButton<String>(
                          value: _assignedFilter == 'other'
                              ? null
                              : _assignedFilter,
                          hint: const Text('Unassigned'),
                          onChanged: _onAssignedFilterChanged,
                          items: const [
                            DropdownMenuItem<String>(
                              value: 'unassigned',
                              child: Text('Unassigned'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'me',
                              child: Text('Me'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'all',
                              child: Text('All'),
                            ),
                          ],
                        ),
                        SizedBox(
                          width: 260,
                          child: _isLoadingUsers
                              ? const LinearProgressIndicator()
                              : DropdownButtonFormField<String>(
                                  initialValue: _assignedFilter == 'other'
                                      ? _selectedEngineerId
                                      : null,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Assigned engineer',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: _onEngineerChanged,
                                  items: _activeEngineers
                                      .map(
                                        (engineer) => DropdownMenuItem<String>(
                                          value: engineer.id,
                                          child: Text(_displayName(engineer)),
                                        ),
                                      )
                                      .toList(),
                                ),
                        ),
                        OutlinedButton(
                          onPressed: _pickDateFrom,
                          child: Text('From: ${_dateText(_dateFrom)}'),
                        ),
                        OutlinedButton(
                          onPressed: _pickDateTo,
                          child: Text('To: ${_dateText(_dateTo)}'),
                        ),
                        ElevatedButton(
                          onPressed: _applyFilters,
                          child: const Text('Apply Filters'),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                              _dateFrom = null;
                              _dateTo = null;
                              _assignedFilter = 'unassigned';
                              _selectedEngineerId = null;
                            });
                            _loadWorkOrders();
                          },
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredItems.isEmpty
                ? const Center(child: Text('No work orders found.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) => _buildRow(
                      context,
                      _filteredItems[index],
                      hasManagerRole: hasManagerRole || hasAdminRole,
                      hasEngineerRole: hasEngineerRole,
                    ),
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                  ),
          ),
        ],
      ),
    );
  }
}
