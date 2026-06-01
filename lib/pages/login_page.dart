import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maintapp/api/api_controller.dart';
import 'package:maintapp/language/mlang.dart';
import 'package:maintapp/model/user_info.dart';
import 'package:maintapp/model/work_order.dart';
import 'package:maintapp/pages/work_order_detail_page.dart';
import 'package:maintapp/state/app_state.dart';
import 'package:maintapp/state/login_session_controller.dart';

/// A simple login page that only supports username + password authentication.
///
/// It intentionally does not provide "create account" or "forgot password" links.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isInitializing = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  bool _isEngineer(UserInfo user) {
    return user.roles.any((role) => role.toUpperCase() == 'ENGINEER');
  }

  Future<void> _loadUsersAfterLogin() async {
    final List<UserInfo> allUsers = await ApiController.listUsers(
      role: 'ENGINEER',
      limit: 100,
      offset: 0,
      includeInactive: true,
    ).then((list) => list.items);

    List<UserInfo> activeEngineers = await ApiController.listUsers(
      role: 'ENGINEER',
      limit: 100,
      offset: 0,
      includeInactive: false,
    ).then((list) => list.items);

    if (activeEngineers.isEmpty) {
      activeEngineers = allUsers.where(_isEngineer).toList();
    }

    AppState.instance.setUsers(
      activeEngineers: activeEngineers,
      allUsers: allUsers,
    );
  }

  Future<bool> _redirectToActiveWorkingWorkOrder(BuildContext context) async {
    final currentUser = LoginSessionController.instance.userInfo;
    if (!_isEngineer(currentUser)) {
      return false;
    }

    try {
      final activeWorkOrders = await ApiController.listWorkOrders(
        user: 'me',
        status: 'working',
        pageSize: 1,
      );
      if (activeWorkOrders.items.isEmpty) {
        return false;
      }

      final WorkOrder activeWorkOrder = activeWorkOrders.items.first;
      if (activeWorkOrder.ownerUserId.trim().isEmpty ||
          activeWorkOrder.ownerUserId.trim() != currentUser.id.trim()) {
        return false;
      }

      if (!mounted) {
        return false;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => WorkOrderDetailPage(workOrderId: activeWorkOrder.id),
        ),
      );
      return true;
    } catch (e, stackTrace) {
      log('Active working WO redirect failed: $e');
      log(stackTrace.toString());
      return false;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isInitializing) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    // await Future.delayed(const Duration(milliseconds: 550));
    await LoginSessionController.instance.loginByUsername(
      _usernameController.text.trim(),
      _passwordController.text.trim(),
    );
    setState(() => _isLoading = false);

    // For demo purposes this accepts any non-empty credentials.
    // In a real app, replace this with real server-side authentication.

    if (LoginSessionController.instance.isLoggedIn()) {
      try {
        AppState.instance.setInstitutions(
          await ApiController.listInstitutions(),
        );
        try {
          await _loadUsersAfterLogin();
        } catch (_) {}
      } catch (_) {}
      log("login success, navigate to dashboard.");
      LoginSessionController.instance.debugCheckLoginInfo(
        condition: "After Login",
      );
      if (mounted) {
        if (await _redirectToActiveWorkingWorkOrder(context)) {
          return;
        }
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login failed. Please try again.')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();

    _initPage();
  }

  Future<void> _initPage() async {
    try {
      await ApiPaths.loadServerSettings();
      final restored = await LoginSessionController.instance
          .loadSessionFromStorage(fetchUserInfo: true);
      await MLang.init(() {
        if (mounted) {
          setState(() {});
        }
      });
      if (restored) {
        try {
          AppState.instance.setInstitutions(
            await ApiController.listInstitutions(),
          );
          try {
            await _loadUsersAfterLogin();
          } catch (_) {}
        } catch (_) {}
        if (mounted) {
          if (await _redirectToActiveWorkingWorkOrder(context)) {
            return;
          }
          Navigator.of(context).pushReplacementNamed('/home');
          return;
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _openServerSettings() async {
    final hostController = TextEditingController(text: ApiPaths.server.host);
    final portController = TextEditingController(
      text: ApiPaths.server.port.toString(),
    );
    bool useHttps = ApiPaths.server.useHttps;
    bool useWebProxy = ApiPaths.server.useWebProxy;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Server Settings'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: hostController,
                      decoration: const InputDecoration(
                        labelText: 'Server Host',
                        hintText: '192.168.50.187',
                      ),
                      autocorrect: false,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: portController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Port',
                        hintText: '3500',
                      ),
                      autocorrect: false,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Use HTTPS'),
                      value: useHttps,
                      onChanged: (value) {
                        setDialogState(() {
                          useHttps = value;
                        });
                      },
                    ),
                    // if (kIsWeb)
                    //   SwitchListTile(
                    //     contentPadding: EdgeInsets.zero,
                    //     title: const Text('Use Web Proxy'),
                    //     subtitle: const Text(
                    //       'Use relative /api paths through Flutter web dev proxy',
                    //     ),
                    //     value: useWebProxy,
                    //     onChanged: (value) {
                    //       setDialogState(() {
                    //         useWebProxy = value;
                    //       });
                    //     },
                    //   ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final host = hostController.text.trim();
                    final port = int.tryParse(portController.text.trim());
                    useWebProxy =
                        false; // Force disable web proxy for now since it's causing confusion and issues

                    if (host.isEmpty || port == null || port <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please enter a valid server host and port.',
                          ),
                        ),
                      );
                      return;
                    }

                    await ApiPaths.saveServerSettings(
                      Server(
                        host: host,
                        port: port,
                        useHttps: useHttps,
                        useWebProxy: useWebProxy,
                      ),
                    );

                    if (mounted) {
                      setState(() {});
                    }
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Stack(
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
            Positioned(
              top: 12,
              right: 12,
              child: SafeArea(
                child: IconButton.filledTonal(
                  onPressed: _openServerSettings,
                  icon: const Icon(Icons.settings),
                  tooltip: 'Server Settings',
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;

                  if (width >= 1100) {
                    return _buildDesktopLayout();
                  }
                  if (width >= 700) {
                    return _buildTabletLayout();
                  }
                  return _buildMobileLayout();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBrandHeader(),
              const SizedBox(height: 10),
              _buildLoginCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabletLayout() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBrandTabletHeader(),
              const SizedBox(height: 28),
              _buildLoginCard(),
            ],
          ),
        ),
      ),
    );
    // return Center(
    //   child: SingleChildScrollView(
    //     padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
    //     child: ConstrainedBox(
    //       constraints: const BoxConstraints(maxWidth: 980),
    //       child: Row(
    //         children: [
    //           Expanded(
    //             child: Padding(
    //               padding: const EdgeInsets.only(right: 32),
    //               child: _buildIntroPanel(
    //                 titleFontSize: 34,
    //                 descriptionFontSize: 18,
    //               ),
    //             ),
    //           ),
    //           SizedBox(width: 380, child: _buildLoginCard()),
    //         ],
    //       ),
    //     ),
    //   ),
    // );
  }

  Widget _buildDesktopLayout() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
          child: Row(
            children: [
              Expanded(
                flex: 6,
                child: Padding(
                  padding: const EdgeInsets.only(right: 48),
                  child: _buildIntroPanel(
                    titleFontSize: 42,
                    descriptionFontSize: 20,
                    serverTargetFontSize: 14,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: _buildLoginCard(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrandTabletHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/app/app_icon.png',
          height: 150,
          width: 150,
          fit: BoxFit.contain,
        ),
        SizedBox(
          height: 60,
          child: Image.asset(
            'assets/images/app/app_name.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Text(
                MLang.text('appTitle', 'Maintenance System'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 30),
        Text(
          MLang.text(
            "txtAppDescLong",
            "Monitor work orders, track maintenance progress, and access your operations dashboard in one place.",
          ),
          textAlign: TextAlign.left,
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 10),
        Text(
          _serverSummary(),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildBrandHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/app/app_icon.png',
          height: 150,
          width: 150,
          fit: BoxFit.contain,
        ),
        Transform.translate(
          offset: const Offset(0, -15),
          child: SizedBox(
            height: 60,
            child: Image.asset(
              'assets/images/app/app_name.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Text(
                  MLang.text('appTitle', 'Maintenance System'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
        ),

        // const SizedBox(height: 0),
        // const Text(
        //   'Sign in to continue',
        //   textAlign: TextAlign.center,
        //   style: TextStyle(color: Colors.white70),
        // ),
        const SizedBox(height: 10),
        Text(
          _serverSummary(),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  String _serverSummary() {
    final scheme = ApiPaths.server.useHttps ? 'https' : 'http';
    if (kIsWeb && ApiPaths.server.useWebProxy) {
      return 'Server: /api (web proxy) -> $scheme://${ApiPaths.server.host}:${ApiPaths.server.port}';
    }
    return 'Server: $scheme://${ApiPaths.server.host}:${ApiPaths.server.port}';
  }

  Widget _buildIntroPanel({
    required double titleFontSize,
    required double descriptionFontSize,
    required double serverTargetFontSize,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          spacing: 10,
          children: [
            Image.asset(
              'assets/images/app/app_icon.png',
              width: 140,
              height: 140,
              fit: BoxFit.contain,
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  height: 100,
                  child: Image.asset(
                    'assets/images/app/app_name.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Text(
                        MLang.text('appTitle', 'Maintenance System'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        // const SizedBox(height: 16),
        Text(
          MLang.text(
            "txtAppDescLong",
            "Monitor work orders, track maintenance progress, and access your operations dashboard in one place.",
          ),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
            fontSize: descriptionFontSize,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _serverSummary(),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: serverTargetFontSize,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Card(
      color: Colors.white.withValues(alpha: 0.90),
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _usernameController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: MLang.text('lblUsername', 'Username'),
                  prefixIcon: const Icon(Icons.person),
                ),
                textInputAction: TextInputAction.next,
                autocorrect: false,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your username';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: MLang.text('lblPassword', 'Password'),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                  ),
                ),
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your password';
                  }
                  if (value.length < 4) {
                    return 'Password must be at least 4 characters';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isLoading || _isInitializing) ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: (_isLoading || _isInitializing)
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          MLang.text('lblLogin', 'Sign in'),
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
