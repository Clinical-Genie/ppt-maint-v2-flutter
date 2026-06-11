import 'package:flutter/material.dart';
import 'package:maintapp/api/api_controller.dart';
import 'package:maintapp/common/platform_helper.dart';
import 'package:maintapp/pages/dashboard_page.dart';
import 'package:maintapp/pages/email_batch_list_page.dart';
import 'package:maintapp/pages/email_contact_list_page.dart';
import 'package:maintapp/pages/email_template_list_page.dart';
import 'package:maintapp/pages/form_template_choice_group_list_page.dart';
import 'package:maintapp/pages/login_page.dart';
import 'package:maintapp/pages/login_sessions_page.dart';
import 'package:maintapp/pages/trusted_device_unlock_page.dart';
import 'package:maintapp/pages/profile_page.dart';
import 'package:maintapp/pages/create_work_order_page.dart';
import 'package:maintapp/pages/transfer_request_list_page.dart';
import 'package:maintapp/pages/work_order_list_page.dart';
import 'package:maintapp/pages/user_management_page.dart';
import 'package:maintapp/state/login_session_controller.dart';
import 'package:maintapp/services/mobile_app_lock_service.dart';

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
        builder: (context, child) =>
            AppKeyboardDismissRegion(child: child ?? const SizedBox.shrink()),
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
          '/login': (context) =>
              const LoginPage(allowTrustedDeviceUnlock: false),
          '/device-unlock': (context) => const TrustedDeviceUnlockPage(),
          '/profile': (context) => const ProfilePage(),
          '/login-sessions': (context) => const LoginSessionsPage(),
          '/create-work-order': (context) => const CreateWorkOrderPage(),
          '/work-orders': (context) => const WorkOrderListPage(),
          '/email-batches': (context) => const EmailBatchListPage(),
          '/email-templates': (context) => const EmailTemplateListPage(),
          '/email-contacts': (context) => const EmailContactListPage(),
          '/template-choice-groups': (context) =>
              const FormTemplateChoiceGroupListPage(),
          '/transfer-requests': (context) => const TransferRequestListPage(),
          '/user-management': (context) => const UserManagementPage(),
        },
      ),
    );
  }
}

class AppKeyboardDismissRegion extends StatelessWidget {
  const AppKeyboardDismissRegion({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: child,
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
  bool _backgroundLockPending = false;
  Future<void>? _lockWrite;

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
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _handleBackground();
    } else if (state == AppLifecycleState.resumed) {
      _handleResume();
    }
  }

  void _handleBackground() {
    if (_backgroundLockPending ||
        !MobileAppLockService.instance.isSupported ||
        !LoginSessionController.instance.isLoggedIn()) {
      return;
    }
    _backgroundLockPending = true;
    _lockWrite = MobileAppLockService.instance
        .lockForBackground(
          isLoggedIn: LoginSessionController.instance.isLoggedIn(),
        )
        .then((locked) {
          if (!locked) {
            _backgroundLockPending = false;
          }
        });
  }

  Future<void> _handleResume() async {
    if (_checkingSession) {
      return;
    }
    _checkingSession = true;
    try {
      await _lockWrite;
      final requiresMobileUnlock =
          _backgroundLockPending ||
          await MobileAppLockService.instance.isLockRequired();
      if (requiresMobileUnlock) {
        _backgroundLockPending = false;
        await LoginSessionController.instance.logoutLocally(
          resetLoginInfo: true,
        );
        final route = await MobileAppLockService.instance.unlockRoute();
        MyApp.navigatorKey.currentState?.pushNamedAndRemoveUntil(
          route,
          (route) => false,
        );
        return;
      }

      final session = LoginSessionController.instance;
      if (!session.isLoggedIn()) {
        await session.loadSessionFromStorage(fetchUserInfo: true);
        if (!session.isLoggedIn()) {
          return;
        }
      }

      await session.refreshTokenIfNeeded();

      if (!session.isLoggedIn()) {
        ApiAction.callAPIFail(
          'appLifecycleResume',
          'Session expired',
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
