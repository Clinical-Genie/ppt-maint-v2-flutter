import 'package:flutter/material.dart';
import 'package:maintapp/api/api_controller.dart';
import 'package:maintapp/common/platform_helper.dart';
import 'package:maintapp/pages/dashboard_page.dart';
import 'package:maintapp/pages/email_batch_list_page.dart';
import 'package:maintapp/pages/login_page.dart';
import 'package:maintapp/pages/login_sessions_page.dart';
import 'package:maintapp/pages/profile_page.dart';
import 'package:maintapp/pages/create_work_order_page.dart';
import 'package:maintapp/pages/transfer_request_list_page.dart';
import 'package:maintapp/pages/work_order_list_page.dart';
import 'package:maintapp/pages/user_management_page.dart';
import 'package:maintapp/state/login_session_controller.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    PlatformHelper.instance.setup();

    return _AppLifecycleGuard(
      child: MaterialApp(
        navigatorKey: navigatorKey,
      title: 'PPT Maintenance System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF212121),
          onPrimary: Colors.white,
          secondary: Color(0xFF757575),
          onSecondary: Colors.white,
          error: Color(0xFFB00020),
          onError: Colors.white,
          surface: Color(0xFFF5F5F5),
          onSurface: Color(0xFF111111),
        ),

        useMaterial3: true,
      ),
      home: const LoginPage(),
      routes: {
        '/home': (context) => const DashboardPage(),
        '/login': (context) => const LoginPage(),
        '/profile': (context) => const ProfilePage(),
        '/login-sessions': (context) => const LoginSessionsPage(),
        '/create-work-order': (context) => const CreateWorkOrderPage(),
        '/work-orders': (context) => const WorkOrderListPage(),
        '/email-batches': (context) => const EmailBatchListPage(),
        '/transfer-requests': (context) => const TransferRequestListPage(),
        '/user-management': (context) => const UserManagementPage(),
      },
      ),
    );
  }
}

class _AppLifecycleGuard extends StatefulWidget {
  const _AppLifecycleGuard({required this.child});

  final Widget child;

  @override
  State<_AppLifecycleGuard> createState() => _AppLifecycleGuardState();
}

class _AppLifecycleGuardState extends State<_AppLifecycleGuard>
    with WidgetsBindingObserver {
  bool _checkingSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleResume();
    }
  }

  Future<void> _handleResume() async {
    if (_checkingSession) {
      return;
    }
    _checkingSession = true;
    try {
      final session = LoginSessionController.instance;
      if (!session.isLoggedIn()) {
        return;
      }

      await session.refreshTokenIfNeeded();

      if (!session.isLoggedIn()) {
        ApiAction.callAPIFail(
          'appLifecycleResume',
          'Session expired',
          'Refresh token failed when app resumed from background.',
          'Please sign in again.',
          false,
        );
      }
    } finally {
      _checkingSession = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
