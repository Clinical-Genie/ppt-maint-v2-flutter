import 'package:flutter/material.dart';
import 'package:maintapp/model/user_info.dart';
import 'package:maintapp/state/login_session_controller.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({required this.user, super.key});

  final UserInfo user;

  @override
  Widget build(BuildContext context) {
    bool hasAdminRole = user.roles.contains('ADMIN');
    bool hasManagerRole = user.roles.contains('MANAGER');
    bool hasEngineerRole = user.roles.contains('ENGINEER');

    final session = LoginSessionController.instance;
    final displayName = user.fullName.isNotEmpty
        ? user.fullName
        : session.username;

    final bool hasDashboardAccess = true;
    final bool hasUserManagementAccess = hasAdminRole;
    final bool hasProfileAccess = true;
    final bool hasWorkOrderAccess = hasManagerRole || hasEngineerRole;
    final bool hasCreateWorkOrderAccess = hasManagerRole;
    final bool hasEmailBatchAccess = hasManagerRole || hasAdminRole;
    final bool hasTransferRequestAccess = hasEngineerRole;
    final bool hasLogoutAccess = true;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/login_page/login_bg.jpeg',
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.55),
                          Colors.black.withValues(alpha: 0.70),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  // color: Theme.of(context).colorScheme.primary,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        child: Text(
                          displayName.isNotEmpty ? displayName[0] : '?',
                          style: const TextStyle(
                            fontSize: 24,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (hasDashboardAccess)
              ListTile(
                leading: const Icon(Icons.dashboard_outlined),
                title: const Text('Dashboard'),
                onTap: () async {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushReplacementNamed('/home');
                },
              ),
            if (hasWorkOrderAccess)
              ListTile(
                leading: const Icon(Icons.list_alt_outlined),
                title: const Text('Work Orders'),
                onTap: () async {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushReplacementNamed('/work-orders');
                },
              ),
            if (hasCreateWorkOrderAccess)
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Create Work Order'),
                onTap: () async {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushNamed('/create-work-order');
                },
              ),
            if (hasEmailBatchAccess)
              ListTile(
                leading: const Icon(Icons.outgoing_mail),
                title: const Text('Email Batches'),
                onTap: () async {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushReplacementNamed('/email-batches');
                },
              ),
            if (hasTransferRequestAccess)
              ListTile(
                leading: const Icon(Icons.swap_horiz_outlined),
                title: const Text('Transfer Requests'),
                onTap: () async {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushReplacementNamed('/transfer-requests');
                },
              ),
            if (hasUserManagementAccess)
              ListTile(
                leading: const Icon(Icons.manage_accounts_outlined),
                title: const Text('User Management'),
                onTap: () async {
                  Navigator.of(context).pop();
                  Navigator.of(
                    context,
                  ).pushReplacementNamed('/user-management');
                },
              ),
            if (hasProfileAccess)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('My Profile'),
                onTap: () async {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushReplacementNamed('/profile');
                },
              ),
            const Divider(height: 1, color: Color.fromARGB(255, 157, 164, 172)),
            if (hasLogoutAccess)
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () async {
                  Navigator.of(context).pop();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed('/login');
                  }
                  session.logout();
                },
              ),
          ],
        ),
      ),
    );
  }
}
