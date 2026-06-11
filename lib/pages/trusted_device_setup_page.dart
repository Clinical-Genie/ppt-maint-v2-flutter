import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maintapp/model/trusted_device.dart';
import 'package:maintapp/services/trusted_device_service.dart';
import 'package:maintapp/state/login_session_controller.dart';

class TrustedDeviceSetupPage extends StatefulWidget {
  const TrustedDeviceSetupPage({super.key});

  @override
  State<TrustedDeviceSetupPage> createState() => _TrustedDeviceSetupPageState();
}

class _TrustedDeviceSetupPageState extends State<TrustedDeviceSetupPage> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _biometricsAvailable = false;
  bool _enableBiometrics = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBiometrics();
  }

  Future<void> _loadBiometrics() async {
    final available = await TrustedDeviceService.instance.canUseBiometrics();
    if (mounted) setState(() => _biometricsAvailable = available);
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final pin = _pinController.text;
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      setState(() => _error = 'Enter a 6-digit PIN.');
      return;
    }
    if (pin != _confirmController.text) {
      setState(() => _error = 'PINs do not match.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      TrustedDeviceRegistration registration;
      try {
        registration = await TrustedDeviceService.instance.register();
      } on TrustedDeviceApiException catch (error) {
        if (error.code != 1030004 || !mounted) rethrow;
        final existing = error.existingDevice;
        final replace = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Replace trusted device?'),
            content: Text(
              [
                'Another trusted device is already registered.',
                if (existing?.deviceName.isNotEmpty == true)
                  'Device: ${existing!.deviceName}',
                if (existing?.registeredAt != null)
                  'Registered: ${_formatDate(existing!.registeredAt!)}',
                'Replacing it will revoke the old device and its sessions.',
              ].join('\n'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Revoke old device and continue'),
              ),
            ],
          ),
        );
        if (replace != true) return;
        registration = await TrustedDeviceService.instance.register(
          replace: true,
        );
      }

      await TrustedDeviceService.instance.completeSetup(
        username: LoginSessionController.instance.username,
        pin: pin,
        biometricsEnabled: _enableBiometrics,
        registration: registration,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on TrustedDeviceApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = 'Setup failed: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trusted device setup'),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.phonelink_lock, size: 52),
                    const SizedBox(height: 16),
                    const Text(
                      'Create a local unlock PIN',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This PIN stays on this device and is never sent to the server.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 6,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: '6-digit PIN',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 6,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm PIN',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_biometricsAvailable)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enable biometric unlock'),
                        subtitle: const Text(
                          'Biometrics are verified only by this device.',
                        ),
                        value: _enableBiometrics,
                        onChanged: _saving
                            ? null
                            : (value) =>
                                  setState(() => _enableBiometrics = value),
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Set up trusted device'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
