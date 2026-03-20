import 'package:flutter/material.dart';
import 'package:maintapp/api/api_controller.dart';
import 'package:maintapp/model/admin_email_log.dart';
import 'package:maintapp/model/admin_result.dart';
import 'package:maintapp/model/user_info.dart';
import 'package:maintapp/model/session.dart';
import 'package:maintapp/model/work_order.dart';
import 'package:maintapp/pages/shared/app_drawer.dart';
import 'package:maintapp/state/login_session_controller.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isLoadingAdmin = false;
  bool _isLoadingReviewer = false;
  AdminPingResult _adminPing = AdminPingResult();
  SessionList _adminSessions = SessionList();
  Map<String, dynamic> _adminUsers = {};
  AdminEmailLogList _adminEmailLogs = AdminEmailLogList();
  WorkOrderList _reviewPendingSignature = WorkOrderList();
  WorkOrderList _reviewSignedEdited = WorkOrderList();

  @override
  void initState() {
    super.initState();
    _loadRoleSections();
  }

  Future<void> _loadRoleSections() async {
    final user = LoginSessionController.instance.userInfo;
    final hasAdminRole = _hasRole(user, 'ADMIN');
    final hasReviewerRole =
        _hasRole(user, 'REVIEWER') || _hasRole(user, 'MANAGER');

    if (hasAdminRole) {
      await _loadAdminSection();
    }
    if (hasReviewerRole) {
      await _loadReviewerSection();
    }
  }

  Future<void> _loadAdminSection() async {
    setState(() {
      _isLoadingAdmin = true;
    });

    try {
      final results = await Future.wait<dynamic>([
        ApiController.adminPing(),
        ApiController.getActiveSessions(),
        // ApiController.listUsers(includeInactive: true, limit: 100, offset: 0),
        ApiController.listAdminEmailLogs(limit: 50, offset: 0),
      ]);

      if (!mounted) return;
      setState(() {
        _adminPing = results[0] is AdminPingResult
            ? results[0] as AdminPingResult
            : AdminPingResult();
        _adminSessions = results[1] is SessionList
            ? results[1] as SessionList
            : SessionList();
        // _adminUsers = Map<String, dynamic>.from(results[2] ?? {});
        _adminUsers = {};
        _adminEmailLogs = results[2] is AdminEmailLogList
            ? results[2] as AdminEmailLogList
            : AdminEmailLogList();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAdmin = false;
        });
      }
    }
  }

  Future<void> _loadReviewerSection() async {
    setState(() {
      _isLoadingReviewer = true;
    });

    try {
      final results = await Future.wait<WorkOrderList>([
        ApiController.listWorkOrders(tab: 'pending_signature', pageSize: 50),
        ApiController.listWorkOrders(tab: 'signed_edited', pageSize: 50),
      ]);

      if (!mounted) return;
      setState(() {
        _reviewPendingSignature = results[0];
        _reviewSignedEdited = results[1];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingReviewer = false;
        });
      }
    }
  }

  int _extractCount(dynamic payload) {
    if (payload is WorkOrderList) {
      return payload.count;
    }
    if (payload is SessionList) {
      return payload.count;
    }
    if (payload is Map<dynamic, dynamic>) {
      if (payload['total'] is int) {
        return payload['total'] as int;
      }
      if (payload['count'] is int) {
        return payload['count'] as int;
      }
    }
    final items = _extractItems(payload);
    return items.length;
  }

  List<Map<String, dynamic>> _extractItems(dynamic payload) {
    if (payload is WorkOrderList) {
      return payload.items.map((workOrder) => workOrder.toJson()).toList();
    }
    if (payload is SessionList) {
      return payload.items.map((session) => session.toJson()).toList();
    }
    if (payload is AdminEmailLogList) {
      return payload.items.map((log) => log.raw).toList();
    }
    if (payload is AdminPingResult) {
      return [payload.raw];
    }
    if (payload is! Map<dynamic, dynamic>) {
      return <Map<String, dynamic>>[];
    }
    final dynamic rootItems = payload['items'] ?? payload['rows'];
    if (rootItems is List) {
      return rootItems.map((item) => Map<String, dynamic>.from(item)).toList();
    }
    final dynamic data = payload['data'];
    if (data is List) {
      return data.map((item) => Map<String, dynamic>.from(item)).toList();
    }
    if (data is Map<String, dynamic>) {
      final nestedItems = data['items'];
      if (nestedItems is List) {
        return nestedItems
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }
    return <Map<String, dynamic>>[];
  }

  ({int active, int inactive}) _extractUserStatusSummary() {
    final users = _extractItems(_adminUsers);
    int active = 0;
    int inactive = 0;
    for (final user in users) {
      if (user['is_active'] == true) {
        active++;
      } else {
        inactive++;
      }
    }
    return (active: active, inactive: inactive);
  }

  int _countEmailStatus(String status) {
    final logs = _extractItems(_adminEmailLogs);
    return logs.where((log) => '${log['status']}' == status).length;
  }

  @override
  Widget build(BuildContext context) {
    final session = LoginSessionController.instance;
    final user = session.userInfo;
    final hasManagerRole = _hasRole(user, 'MANAGER');
    final hasEngineerRole = _hasRole(user, 'ENGINEER');
    final hasAdminRole = _hasRole(user, 'ADMIN');
    final hasReviewerRole = _hasRole(user, 'REVIEWER');
    final metrics = _DashboardMetrics.fromUser(user, session.username);
    final adminUserSummary = _extractUserStatusSummary();
    final reviewerQueueItems = _extractItems(_reviewPendingSignature);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      drawer: AppDrawer(user: user),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Dashboard',
          style: TextStyle(
            color: Color(0xFF334155),
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                user.fullName.isNotEmpty ? user.fullName : session.username,
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1100;
          final horizontalPadding = isWide ? 32.0 : 16.0;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              20,
              horizontalPadding,
              32,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1320),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // _DashboardHero(
                    //   user: user,
                    //   hasManagerRole: hasManagerRole,
                    //   hasEngineerRole: hasEngineerRole,
                    // ),
                    // const SizedBox(height: 24),
                    if (hasManagerRole)
                      Text(
                        "Manager Dashboard",
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (hasManagerRole) const SizedBox(height: 18),
                    if (hasManagerRole)
                      _StatGrid(
                        items: [
                          _StatItem(
                            title: 'Work Orders To Complete',
                            value: metrics.totalToComplete.toString(),
                            icon: Icons.assignment_turned_in_outlined,
                            color: const Color(0xFF0F766E),
                          ),
                          _StatItem(
                            title: 'New Work Orders Today',
                            value: metrics.newToday.toString(),
                            icon: Icons.fiber_new_outlined,
                            color: const Color(0xFF2563EB),
                          ),
                          _StatItem(
                            title: 'Unpicked Work Orders',
                            value: metrics.unpicked.toString(),
                            icon: Icons.assignment_late_outlined,
                            color: const Color(0xFFDC2626),
                          ),
                          _StatItem(
                            title: 'Pending Approval',
                            value: metrics.pendingApproval.toString(),
                            icon: Icons.approval_outlined,
                            color: const Color(0xFFCA8A04),
                          ),
                        ],
                      ),

                    if (hasManagerRole) const SizedBox(height: 24),

                    if (hasManagerRole)
                      Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        children: [
                          _BreakdownCard(
                            title: 'Pending By Engineer',
                            subtitle:
                                'Open work orders currently assigned but not completed',
                            items: metrics.pendingByEngineer,
                            width: isWide ? 420 : constraints.maxWidth,
                            icon: Icons.engineering_outlined,
                          ),
                          _BreakdownCard(
                            title: 'Work Orders By Hospital',
                            subtitle:
                                'Current workload distribution across hospitals',
                            items: metrics.byHospital,
                            width: isWide ? 420 : constraints.maxWidth,
                            icon: Icons.local_hospital_outlined,
                          ),
                          _ShortcutCard(
                            width: isWide ? 420 : constraints.maxWidth,
                            shortcuts: const [
                              _ShortcutItem(
                                title: 'Add New Order',
                                subtitle: 'Create a new maintenance request',
                                icon: Icons.add_task_outlined,
                              ),
                              _ShortcutItem(
                                title: 'Search Work Orders',
                                subtitle: 'Find existing work orders quickly',
                                icon: Icons.search_outlined,
                              ),
                            ],
                          ),
                        ],
                      ),
                    if (hasManagerRole) const SizedBox(height: 24),
                    if (hasManagerRole && hasEngineerRole)
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color.fromARGB(255, 157, 164, 172),
                      ),
                    if (hasManagerRole && hasEngineerRole)
                      const SizedBox(height: 24),

                    if (hasEngineerRole)
                      Text(
                        "Engineer Dashboard",
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (hasEngineerRole) const SizedBox(height: 18),
                    if (hasEngineerRole)
                      _StatGrid(
                        items: [
                          _StatItem(
                            title: 'New Work Orders Today',
                            value: metrics.newToday.toString(),
                            icon: Icons.fiber_new_outlined,
                            color: const Color(0xFF2563EB),
                          ),
                          _StatItem(
                            title: 'Unpicked Work Orders',
                            value: metrics.unpicked.toString(),
                            icon: Icons.assignment_late_outlined,
                            color: const Color(0xFFDC2626),
                          ),
                          _StatItem(
                            title: 'My Picked Orders',
                            value: metrics.myPicked.toString(),
                            icon: Icons.handyman_outlined,
                            color: const Color(0xFF7C3AED),
                          ),
                          _StatItem(
                            title: 'Planned For Today',
                            value: metrics.plannedToday.toString(),
                            icon: Icons.today_outlined,
                            color: const Color(0xFFEA580C),
                          ),
                        ],
                      ),

                    if (hasEngineerRole) const SizedBox(height: 24),

                    if (hasEngineerRole)
                      Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        children: [
                          _BreakdownCard(
                            title: 'Interested Hospitals',
                            subtitle:
                                'Work orders from hospitals you follow closely',
                            items: metrics.interestedHospitals,
                            width: isWide ? 420 : constraints.maxWidth,
                            icon: Icons.location_city_outlined,
                          ),

                          _ShortcutCard(
                            width: isWide ? 420 : constraints.maxWidth,
                            shortcuts: const [
                              _ShortcutItem(
                                title: 'Search Work Orders',
                                subtitle: 'Find existing work orders quickly',
                                icon: Icons.search_outlined,
                              ),
                            ],
                          ),
                        ],
                      ),
                    if (hasEngineerRole || hasAdminRole || hasReviewerRole)
                      const SizedBox(height: 24),
                    if (hasAdminRole || hasReviewerRole)
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color.fromARGB(255, 157, 164, 172),
                      ),
                    if (hasAdminRole || hasReviewerRole)
                      const SizedBox(height: 24),
                    if (hasAdminRole)
                      Text(
                        "Admin Dashboard",
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (hasAdminRole) const SizedBox(height: 18),
                    if (hasAdminRole && _isLoadingAdmin)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (hasAdminRole)
                      _StatGrid(
                        items: [
                          _StatItem(
                            title: 'Admin Ping',
                            value: _adminPing.status.isNotEmpty
                                ? _adminPing.status.toUpperCase()
                                : (_adminPing.message.isNotEmpty ? 'OK' : '-'),
                            icon: Icons.monitor_heart_outlined,
                            color: const Color(0xFF0F766E),
                          ),
                          _StatItem(
                            title: 'Active Sessions',
                            value: _extractCount(_adminSessions).toString(),
                            icon: Icons.devices_outlined,
                            color: const Color(0xFF2563EB),
                          ),
                          _StatItem(
                            title: 'Active Users',
                            value: adminUserSummary.active.toString(),
                            icon: Icons.people_outline,
                            color: const Color(0xFF059669),
                          ),
                          _StatItem(
                            title: 'Inactive Users',
                            value: adminUserSummary.inactive.toString(),
                            icon: Icons.person_off_outlined,
                            color: const Color(0xFFDC2626),
                          ),
                          _StatItem(
                            title: 'Failed Emails',
                            value: _countEmailStatus('failed').toString(),
                            icon: Icons.mark_email_unread_outlined,
                            color: const Color(0xFFCA8A04),
                          ),
                        ],
                      ),
                    if (hasAdminRole) const SizedBox(height: 24),
                    if (hasAdminRole)
                      _SimpleListCard(
                        title: 'Recent Email Logs',
                        subtitle: 'Latest delivery activity from admin logs',
                        width: isWide ? 720 : constraints.maxWidth,
                        items: _extractItems(_adminEmailLogs),
                        emptyText: 'No email log data available.',
                        labelBuilder: (item) =>
                            '${item['to'] ?? item['recipient'] ?? item['email'] ?? '-'}',
                        valueBuilder: (item) =>
                            '${item['status'] ?? item['template'] ?? '-'}',
                      ),
                    if (hasAdminRole && hasReviewerRole)
                      const SizedBox(height: 24),
                    if (hasAdminRole && hasReviewerRole)
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color.fromARGB(255, 157, 164, 172),
                      ),
                    if (hasAdminRole && hasReviewerRole)
                      const SizedBox(height: 24),
                    if (hasReviewerRole)
                      Text(
                        "Reviewer Dashboard",
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (hasReviewerRole) const SizedBox(height: 18),
                    if (hasReviewerRole && _isLoadingReviewer)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (hasReviewerRole)
                      _StatGrid(
                        items: [
                          _StatItem(
                            title: 'Pending Signature',
                            value: _extractCount(
                              _reviewPendingSignature,
                            ).toString(),
                            icon: Icons.rate_review_outlined,
                            color: const Color(0xFF7C3AED),
                          ),
                          _StatItem(
                            title: 'Signed Edited',
                            value: _extractCount(
                              _reviewSignedEdited,
                            ).toString(),
                            icon: Icons.fact_check_outlined,
                            color: const Color(0xFFEA580C),
                          ),
                          _StatItem(
                            title: 'Review Queue',
                            value: reviewerQueueItems.length.toString(),
                            icon: Icons.list_alt_outlined,
                            color: const Color(0xFF1D4ED8),
                          ),
                        ],
                      ),
                    if (hasReviewerRole) const SizedBox(height: 24),
                    if (hasReviewerRole)
                      _SimpleListCard(
                        title: 'Review Queue',
                        subtitle:
                            'Work orders waiting for signature review or approval',
                        width: isWide ? 720 : constraints.maxWidth,
                        items: reviewerQueueItems,
                        emptyText: 'No work orders in review queue.',
                        labelBuilder: (item) =>
                            '${item['wo_no'] ?? item['woNo'] ?? item['id'] ?? '-'}',
                        valueBuilder: (item) =>
                            '${item['status'] ?? item['tab'] ?? '-'}',
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  bool _hasRole(UserInfo user, String role) {
    return user.roles.any((item) => item.toUpperCase() == role);
  }
}

// class _DashboardHero extends StatelessWidget {
//   const _DashboardHero({
//     required this.user,
//     required this.hasManagerRole,
//     required this.hasEngineerRole,
//   });

//   final UserInfo user;
//   final bool hasManagerRole;
//   final bool hasEngineerRole;

//   @override
//   Widget build(BuildContext context) {
//     final roleLabels = <String>[
//       if (hasManagerRole) 'Manager',
//       if (hasEngineerRole) 'Engineer',
//     ];

//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(24),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(28),
//         gradient: const LinearGradient(
//           colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         boxShadow: const [
//           BoxShadow(
//             color: Color(0x220F172A),
//             blurRadius: 28,
//             offset: Offset(0, 14),
//           ),
//         ],
//       ),
//       child: Wrap(
//         alignment: WrapAlignment.spaceBetween,
//         runSpacing: 16,
//         children: [
//           ConstrainedBox(
//             constraints: const BoxConstraints(maxWidth: 560),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   'Welcome ${user.fullName.isNotEmpty ? ', ${user.fullName}' : ''}',
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontSize: 24,
//                     fontWeight: FontWeight.w700,
//                   ),
//                 ),
//                 // const SizedBox(height: 10),
//                 // const Text(
//                 //   'Track maintenance activity, monitor workload, and move quickly from summary to action.',
//                 //   style: TextStyle(
//                 //     color: Color(0xFFDCE7FF),
//                 //     fontSize: 15,
//                 //     height: 1.5,
//                 //   ),
//                 // ),
//               ],
//             ),
//           ),
//           Wrap(
//             spacing: 10,
//             runSpacing: 10,
//             children: roleLabels
//                 .map(
//                   (role) => Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 14,
//                       vertical: 10,
//                     ),
//                     decoration: BoxDecoration(
//                       color: Colors.white.withValues(alpha: 0.14),
//                       borderRadius: BorderRadius.circular(999),
//                       border: Border.all(
//                         color: Colors.white.withValues(alpha: 0.18),
//                       ),
//                     ),
//                     child: Text(
//                       role,
//                       style: const TextStyle(
//                         fontSize: 10,
//                         color: Colors.white,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ),
//                 )
//                 .toList(),
//           ),
//         ],
//       ),
//     );
//   }
// }

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.items});

  final List<_StatItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: items
          .map((item) => SizedBox(width: 240, child: _StatCard(item: item)))
          .toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.item});

  final _StatItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Row(
            spacing: 18,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(item.icon, color: item.color),
              ),
              Text(
                item.value,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Text(
            item.title,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.width,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final List<_BreakdownItem> items;
  final double width;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = width.isFinite ? width : double.infinity;
    final cardWidth = effectiveWidth < 280
        ? 280.0
        : (effectiveWidth > 420 ? 420.0 : effectiveWidth);
    return SizedBox(
      width: cardWidth,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120F172A),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF1D4ED8)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 18),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        style: const TextStyle(
                          color: Color(0xFF334155),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.value.toString(),
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({required this.width, required this.shortcuts});

  final double width;
  final List<_ShortcutItem> shortcuts;

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = width.isFinite ? width : double.infinity;
    final cardWidth = effectiveWidth < 280
        ? 280.0
        : (effectiveWidth > 420 ? 420.0 : effectiveWidth);
    return SizedBox(
      width: cardWidth,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x220F172A),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Shortcuts',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Jump into common actions from the dashboard.',
              style: TextStyle(color: Color(0xFFCBD5E1), height: 1.4),
            ),
            const SizedBox(height: 18),
            ...shortcuts.map(
              (shortcut) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${shortcut.title} is not wired yet'),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(shortcut.icon, color: Colors.white),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shortcut.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                shortcut.subtitle,
                                style: const TextStyle(
                                  color: Color(0xFFCBD5E1),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Color(0xFFCBD5E1),
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem {
  const _StatItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
}

class _BreakdownItem {
  const _BreakdownItem({required this.label, required this.value});

  final String label;
  final int value;
}

class _ShortcutItem {
  const _ShortcutItem({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}

class _SimpleListCard extends StatelessWidget {
  const _SimpleListCard({
    required this.title,
    required this.subtitle,
    required this.width,
    required this.items,
    required this.emptyText,
    required this.labelBuilder,
    required this.valueBuilder,
  });

  final String title;
  final String subtitle;
  final double width;
  final List<Map<String, dynamic>> items;
  final String emptyText;
  final String Function(Map<String, dynamic>) labelBuilder;
  final String Function(Map<String, dynamic>) valueBuilder;

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = width.isFinite ? width : double.infinity;
    final cardWidth = effectiveWidth < 320
        ? 320.0
        : (effectiveWidth > 860 ? 860.0 : effectiveWidth);

    return SizedBox(
      width: cardWidth,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120F172A),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              Text(emptyText, style: const TextStyle(color: Color(0xFF64748B)))
            else
              ...items
                  .take(8)
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              labelBuilder(item),
                              style: const TextStyle(
                                color: Color(0xFF334155),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              valueBuilder(item),
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _DashboardMetrics {
  const _DashboardMetrics({
    required this.totalToComplete,
    required this.newToday,
    required this.unpicked,
    required this.pendingApproval,
    required this.myPicked,
    required this.plannedToday,
    required this.pendingByEngineer,
    required this.byHospital,
    required this.interestedHospitals,
  });

  final int totalToComplete;
  final int newToday;
  final int unpicked;
  final int pendingApproval;
  final int myPicked;
  final int plannedToday;
  final List<_BreakdownItem> pendingByEngineer;
  final List<_BreakdownItem> byHospital;
  final List<_BreakdownItem> interestedHospitals;

  factory _DashboardMetrics.fromUser(UserInfo user, String username) {
    final seedSource =
        '${user.id}|${user.email}|$username|${user.roles.join(",")}';
    final seed = seedSource.runes.fold<int>(0, (sum, char) => sum + char);
    int next(int offset, int min, int max) =>
        min + ((seed + offset) % (max - min + 1));

    return _DashboardMetrics(
      totalToComplete: next(11, 18, 56),
      newToday: next(23, 2, 12),
      unpicked: next(37, 1, 14),
      pendingApproval: next(41, 1, 9),
      myPicked: next(53, 3, 16),
      plannedToday: next(67, 2, 8),
      pendingByEngineer: [
        _BreakdownItem(label: 'Alex Chan', value: next(71, 2, 9)),
        _BreakdownItem(label: 'Sam Wong', value: next(73, 1, 8)),
        _BreakdownItem(label: 'Chris Lee', value: next(79, 1, 7)),
      ],
      byHospital: [
        _BreakdownItem(label: 'Queen Mary Hospital', value: next(83, 4, 14)),
        _BreakdownItem(label: 'Tuen Mun Hospital', value: next(89, 3, 11)),
        _BreakdownItem(
          label: 'Prince of Wales Hospital',
          value: next(97, 3, 12),
        ),
      ],
      interestedHospitals: [
        _BreakdownItem(
          label: 'Queen Elizabeth Hospital',
          value: next(101, 1, 6),
        ),
        _BreakdownItem(
          label: 'Princess Margaret Hospital',
          value: next(103, 1, 5),
        ),
        _BreakdownItem(
          label: 'United Christian Hospital',
          value: next(107, 1, 4),
        ),
      ],
    );
  }
}
