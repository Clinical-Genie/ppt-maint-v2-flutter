import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maintapp/common/trusted_device_storage.dart';
import 'package:maintapp/model/trusted_device.dart';
import 'package:maintapp/pages/work_order_detail_page.dart';
import 'package:maintapp/services/post_auth_navigation_service.dart';
import 'package:maintapp/services/trusted_device_service.dart';
import 'package:maintapp/state/login_session_controller.dart';

enum TrustedDeviceUnlockMode { biometric, pin, password }

class TrustedDeviceUnlockPage extends StatefulWidget {
  const TrustedDeviceUnlockPage({super.key, this.trustedDeviceService});

  final TrustedDeviceService? trustedDeviceService;

  @override
  State<TrustedDeviceUnlockPage> createState() =>
      _TrustedDeviceUnlockPageState();
}

class _TrustedDeviceUnlockPageState extends State<TrustedDeviceUnlockPage>
    with WidgetsBindingObserver {
  final _pinController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFormKey = GlobalKey<FormState>();
  TrustedDeviceLocalState? _state;
  Timer? _timer;
  TrustedDeviceUnlockMode _mode = TrustedDeviceUnlockMode.pin;
  bool _loading = true;
  bool _authenticating = false;
  bool _biometricAvailable = false;
  bool _obscurePassword = true;
  String? _message;

  TrustedDeviceService get _trustedDeviceService =>
      widget.trustedDeviceService ?? TrustedDeviceService.instance;

  bool get _canUseBiometricMethod =>
      _state?.isConfigured == true &&
      _state?.biometricsEnabled == true &&
      _biometricAvailable;

  bool get _canUsePinMethod => _state?.isConfigured == true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _pinController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshState();
    }
  }

  Future<void> _initialize() async {
    await _refreshState(setInitialMode: true);
  }

  Future<void> _refreshState({bool setInitialMode = false}) async {
    var state = await _trustedDeviceService.loadState();
    if (state.lockedUntil != null && !state.isLocked) {
      await TrustedDeviceStorage.clearPinFailures();
      state = await _trustedDeviceService.loadState();
    }
    final biometricAvailable = await _trustedDeviceService.canUseBiometrics();
    _timer?.cancel();
    if (state.isLocked) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        _refreshState();
      });
    }
    if (!mounted) return;
    setState(() {
      _state = state;
      _usernameController.text = _usernameController.text.isEmpty
          ? state.username
          : _usernameController.text;
      _biometricAvailable = biometricAvailable;
      if (setInitialMode) {
        _mode = state.isConfigured
            ? state.biometricsEnabled && biometricAvailable
                  ? TrustedDeviceUnlockMode.biometric
                  : TrustedDeviceUnlockMode.pin
            : TrustedDeviceUnlockMode.password;
      }
      _loading = false;
    });
  }

  void _changeMode(TrustedDeviceUnlockMode mode) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _mode = mode;
      _message = null;
    });
  }

  Future<void> _useBiometrics() async {
    if (_authenticating || _state?.isLocked == true) return;
    setState(() {
      _authenticating = true;
      _message = null;
    });
    final result = await _trustedDeviceService.authenticateBiometrically();
    if (!mounted) return;
    setState(() => _authenticating = false);
    if (result == BiometricUnlockResult.authenticated) {
      await _createDeviceSession();
      return;
    }
    setState(() {
      _message = switch (result) {
        BiometricUnlockResult.temporarilyLocked ||
        BiometricUnlockResult.permanentlyLocked =>
          'Biometric unlock is locked. Choose another method or tap to retry later.',
        BiometricUnlockResult.unavailable =>
          'Biometric unlock is unavailable. Choose another method.',
        BiometricUnlockResult.cancelled =>
          'Biometric unlock was cancelled. Tap the button to retry.',
        _ => 'Biometric unlock failed. Tap the button to retry.',
      };
    });
  }

  Future<void> _submitPin() async {
    if (_authenticating || _state?.isLocked == true) return;
    final pin = _pinController.text;
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      setState(() => _message = 'Enter your 6-digit PIN.');
      return;
    }
    setState(() {
      _authenticating = true;
      _message = null;
    });
    final valid = await _trustedDeviceService.verifyPin(pin);
    _pinController.clear();
    await _refreshState();
    if (!mounted) return;
    setState(() => _authenticating = false);
    if (!valid) {
      setState(() {
        _message = _state?.isLocked == true
            ? 'Too many incorrect attempts. Device unlock is temporarily locked.'
            : 'Incorrect PIN.';
      });
      return;
    }
    await _createDeviceSession();
  }

  Future<void> _submitPassword() async {
    if (_authenticating || !_passwordFormKey.currentState!.validate()) return;
    setState(() {
      _authenticating = true;
      _message = null;
    });
    try {
      await LoginSessionController.instance.loginByUsername(
        _usernameController.text.trim(),
        _passwordController.text,
      );
      if (!LoginSessionController.instance.isLoggedIn()) {
        if (mounted) {
          setState(() => _message = 'Login failed. Please try again.');
        }
        return;
      }
      await _finishAuthentication();
    } catch (error) {
      if (mounted) setState(() => _message = 'Login failed: $error');
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  Future<void> _createDeviceSession() async {
    if (!mounted) return;
    setState(() => _authenticating = true);
    try {
      final loginInfo = await _trustedDeviceService.createDeviceSession();
      final state = await _trustedDeviceService.loadState();
      await LoginSessionController.instance.adoptAuthenticatedSession(
        loginInfo,
        username: state.username,
      );
      await _finishAuthentication();
    } on TrustedDeviceApiException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (error) {
      if (mounted) setState(() => _message = 'Unable to unlock: $error');
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  Future<void> _finishAuthentication() async {
    final workOrderId = await PostAuthNavigationService.instance
        .activeWorkingWorkOrderId();
    if (!mounted) return;
    if (workOrderId != null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => WorkOrderDetailPage(workOrderId: workOrderId),
        ),
        (route) => false,
      );
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  String _lockoutText() {
    final until = _state?.lockedUntil;
    if (until == null) return '';
    final seconds = until.difference(DateTime.now()).inSeconds + 1;
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return minutes > 0
        ? '$minutes:${remainder.toString().padLeft(2, '0')}'
        : '${seconds.clamp(0, 59)} seconds';
  }

  Widget _buildBiometricMode(bool locallyLocked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.fingerprint, size: 64),
        const SizedBox(height: 12),
        const Text(
          'Tap the button to start biometric unlock.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _authenticating || locallyLocked ? null : _useBiometrics,
          icon: const Icon(Icons.fingerprint),
          label: Text(
            _authenticating ? 'Checking...' : 'Unlock with biometrics',
          ),
        ),
      ],
    );
  }

  Widget _buildPinMode(bool locallyLocked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (locallyLocked)
          Text(
            'Device unlock is locked. Try again in ${_lockoutText()}.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          )
        else ...[
          TextField(
            controller: _pinController,
            enabled: !_authenticating,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 6,
            obscureText: true,
            textAlign: TextAlign.center,
            onSubmitted: (_) => _submitPin(),
            decoration: const InputDecoration(
              labelText: '6-digit PIN',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _authenticating ? null : _submitPin,
            child: Text(_authenticating ? 'Checking...' : 'Unlock with PIN'),
          ),
        ],
      ],
    );
  }

  Widget _buildPasswordMode() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _usernameController,
            enabled: !_authenticating,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixIcon: Icon(Icons.person),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Please enter your username'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            enabled: !_authenticating,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                onPressed: _authenticating
                    ? null
                    : () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
            validator: (value) => value == null || value.isEmpty
                ? 'Please enter your password'
                : null,
            onFieldSubmitted: (_) => _submitPassword(),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _authenticating ? null : _submitPassword,
            child: Text(_authenticating ? 'Signing in...' : 'Sign in'),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodButtons() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        if (_canUseBiometricMethod &&
            _mode != TrustedDeviceUnlockMode.biometric)
          TextButton.icon(
            onPressed: _authenticating
                ? null
                : () => _changeMode(TrustedDeviceUnlockMode.biometric),
            icon: const Icon(Icons.fingerprint),
            label: const Text('Use biometrics'),
          ),
        if (_canUsePinMethod && _mode != TrustedDeviceUnlockMode.pin)
          TextButton.icon(
            onPressed: _authenticating
                ? null
                : () => _changeMode(TrustedDeviceUnlockMode.pin),
            icon: const Icon(Icons.pin),
            label: const Text('Use 6-digit PIN'),
          ),
        if (_mode != TrustedDeviceUnlockMode.password)
          TextButton.icon(
            onPressed: _authenticating
                ? null
                : () => _changeMode(TrustedDeviceUnlockMode.password),
            icon: const Icon(Icons.password),
            label: const Text('Use username/password'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final locallyLocked = state?.isLocked ?? false;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Icon(Icons.lock_outline, size: 48),
                              const SizedBox(height: 12),
                              const Text(
                                'Unlock app',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (state?.username.isNotEmpty == true &&
                                  _mode !=
                                      TrustedDeviceUnlockMode.password) ...[
                                const SizedBox(height: 6),
                                Text(
                                  state!.username,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                              const SizedBox(height: 24),
                              switch (_mode) {
                                TrustedDeviceUnlockMode.biometric =>
                                  _buildBiometricMode(locallyLocked),
                                TrustedDeviceUnlockMode.pin => _buildPinMode(
                                  locallyLocked,
                                ),
                                TrustedDeviceUnlockMode.password =>
                                  _buildPasswordMode(),
                              },
                              if (_message != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  _message!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              _buildMethodButtons(),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
