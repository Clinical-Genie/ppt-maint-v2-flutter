import 'package:flutter/material.dart';
import 'package:maintapp/common/platform_helper.dart';
import 'package:maintapp/pages/dashboard_page.dart';
import 'package:maintapp/pages/login_page.dart';
import 'package:maintapp/pages/login_sessions_page.dart';
import 'package:maintapp/pages/profile_page.dart';
import 'package:maintapp/pages/create_work_order_page.dart';
import 'package:maintapp/pages/work_order_list_page.dart';
import 'package:maintapp/pages/user_management_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    PlatformHelper.instance.setup();

    return MaterialApp(
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
        '/user-management': (context) => const UserManagementPage(),
      },
    );
  }
}
