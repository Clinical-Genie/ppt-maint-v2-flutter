import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maintapp/common/trusted_device_storage.dart';
import 'package:maintapp/pages/trusted_device_unlock_page.dart';
import 'package:maintapp/services/trusted_device_service.dart';

class _FakeTrustedDeviceService extends TrustedDeviceService {
  _FakeTrustedDeviceService({
    required this.state,
    required this.biometricAvailable,
    this.biometricResult = BiometricUnlockResult.failed,
  }) : super(pinIterations: 1);

  final TrustedDeviceLocalState state;
  final bool biometricAvailable;
  final BiometricUnlockResult biometricResult;
  int biometricCalls = 0;

  @override
  Future<TrustedDeviceLocalState> loadState() async => state;

  @override
  Future<bool> canUseBiometrics() async => biometricAvailable;

  @override
  Future<BiometricUnlockResult> authenticateBiometrically() async {
    biometricCalls++;
    return biometricResult;
  }
}

TrustedDeviceLocalState _state({
  required bool configured,
  bool biometricsEnabled = false,
}) {
  return TrustedDeviceLocalState(
    deviceUuid: configured ? 'installation-id' : '',
    deviceSecret: configured ? 'server-secret' : '',
    username: configured ? 'engineer' : '',
    pinSalt: configured ? 'salt' : '',
    pinHash: configured ? 'hash' : '',
    biometricsEnabled: biometricsEnabled,
    failedPinAttempts: 0,
    appLocked: true,
  );
}

void main() {
  testWidgets('biometrics never start automatically', (tester) async {
    final service = _FakeTrustedDeviceService(
      state: _state(configured: true, biometricsEnabled: true),
      biometricAvailable: true,
    );

    await tester.pumpWidget(
      MaterialApp(home: TrustedDeviceUnlockPage(trustedDeviceService: service)),
    );
    await tester.pumpAndSettle();

    expect(service.biometricCalls, 0);
    expect(find.text('Unlock with biometrics'), findsOneWidget);
  });

  testWidgets('biometric button starts authentication and allows retry', (
    tester,
  ) async {
    final service = _FakeTrustedDeviceService(
      state: _state(configured: true, biometricsEnabled: true),
      biometricAvailable: true,
      biometricResult: BiometricUnlockResult.failed,
    );

    await tester.pumpWidget(
      MaterialApp(home: TrustedDeviceUnlockPage(trustedDeviceService: service)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Unlock with biometrics'));
    await tester.pumpAndSettle();
    expect(service.biometricCalls, 1);
    expect(
      find.text('Biometric unlock failed. Tap the button to retry.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Unlock with biometrics'));
    await tester.pumpAndSettle();
    expect(service.biometricCalls, 2);
  });

  testWidgets('trusted device can switch between all unlock methods', (
    tester,
  ) async {
    final service = _FakeTrustedDeviceService(
      state: _state(configured: true, biometricsEnabled: true),
      biometricAvailable: true,
    );

    await tester.pumpWidget(
      MaterialApp(home: TrustedDeviceUnlockPage(trustedDeviceService: service)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use 6-digit PIN'));
    await tester.pump();
    expect(find.text('Unlock with PIN'), findsOneWidget);

    await tester.tap(find.text('Use username/password'));
    await tester.pump();
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    await tester.tap(find.text('Use biometrics'));
    await tester.pump();
    expect(find.text('Unlock with biometrics'), findsOneWidget);
    expect(service.biometricCalls, 0);
  });

  testWidgets('untrusted device exposes password method only', (tester) async {
    final service = _FakeTrustedDeviceService(
      state: _state(configured: false),
      biometricAvailable: false,
    );

    await tester.pumpWidget(
      MaterialApp(home: TrustedDeviceUnlockPage(trustedDeviceService: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Use biometrics'), findsNothing);
    expect(find.text('Use 6-digit PIN'), findsNothing);
  });
}
