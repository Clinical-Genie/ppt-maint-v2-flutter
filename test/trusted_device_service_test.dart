import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maintapp/common/platform_helper.dart';
import 'package:maintapp/common/secure_storage.dart';
import 'package:maintapp/common/trusted_device_storage.dart';
import 'package:maintapp/model/trusted_device.dart';
import 'package:maintapp/model/login_info.dart';
import 'package:maintapp/services/trusted_device_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SecureStorage.instance.data.clear();
    PlatformHelper.instance.setup();
  });

  TrustedDeviceRegistration registration() {
    return const TrustedDeviceRegistration(
      device: TrustedDevice(
        id: 'device-id',
        deviceUuid: 'installation-id',
        platform: 'android',
        deviceName: 'Test phone',
        model: 'Test phone',
        appVersion: '1.0.0+1',
      ),
      deviceSecret: 'server-secret',
    );
  }

  test(
    'complete setup stores verifier and never stores plaintext PIN',
    () async {
      final service = TrustedDeviceService(pinIterations: 10);
      await TrustedDeviceStorage.save({
        TrustedDeviceStorage.deviceUuidKey: 'installation-id',
      });

      await service.completeSetup(
        username: 'engineer',
        pin: '123456',
        biometricsEnabled: true,
        registration: registration(),
      );

      final state = await service.loadState();
      expect(state.isConfigured, isTrue);
      expect(state.deviceSecret, 'server-secret');
      expect(state.pinHash, isNot('123456'));
      expect(state.pinSalt, isNotEmpty);
      expect(state.biometricsEnabled, isTrue);
      expect(SecureStorage.instance.data.toString(), isNot(contains('123456')));
    },
  );

  test('correct PIN unlocks and incorrect PIN increments attempts', () async {
    final service = TrustedDeviceService(pinIterations: 10);
    await TrustedDeviceStorage.save({
      TrustedDeviceStorage.deviceUuidKey: 'installation-id',
    });
    await service.completeSetup(
      username: 'engineer',
      pin: '123456',
      biometricsEnabled: false,
      registration: registration(),
    );

    expect(await service.verifyPin('000000'), isFalse);
    expect((await service.loadState()).failedPinAttempts, 1);
    expect(await service.verifyPin('123456'), isTrue);
    expect((await service.loadState()).failedPinAttempts, 0);
  });

  test(
    'five failed PIN attempts persist a lockout across service restart',
    () async {
      final now = DateTime.now();
      var service = TrustedDeviceService(pinIterations: 10, now: () => now);
      await TrustedDeviceStorage.save({
        TrustedDeviceStorage.deviceUuidKey: 'installation-id',
      });
      await service.completeSetup(
        username: 'engineer',
        pin: '123456',
        biometricsEnabled: false,
        registration: registration(),
      );

      for (var attempt = 0; attempt < 5; attempt++) {
        expect(await service.verifyPin('000000'), isFalse);
      }
      final lockedState = await service.loadState();
      expect(lockedState.isLocked, isTrue);
      expect(lockedState.lockedUntil, now.add(const Duration(seconds: 30)));

      service = TrustedDeviceService(pinIterations: 10, now: () => now);
      expect((await service.loadState()).isLocked, isTrue);
      expect(await service.verifyPin('123456'), isFalse);

      await TrustedDeviceStorage.save({
        TrustedDeviceStorage.lockedUntilKey: now
            .subtract(const Duration(seconds: 1))
            .toIso8601String(),
      });
      expect((await service.loadState()).isLocked, isFalse);
    },
  );

  test('revoked-device cleanup retains UUID and removes credentials', () async {
    await TrustedDeviceStorage.save({
      TrustedDeviceStorage.deviceUuidKey: 'installation-id',
      TrustedDeviceStorage.deviceSecretKey: 'secret',
      TrustedDeviceStorage.pinSaltKey: 'salt',
      TrustedDeviceStorage.pinHashKey: 'hash',
      TrustedDeviceStorage.biometricsEnabledKey: 'true',
      TrustedDeviceStorage.failedPinAttemptsKey: '5',
      TrustedDeviceStorage.lockedUntilKey: DateTime.utc(
        2026,
        6,
        11,
        13,
      ).toIso8601String(),
    });

    await TrustedDeviceStorage.clearRegistration();
    final state = await TrustedDeviceStorage.load();

    expect(state.deviceUuid, 'installation-id');
    expect(state.deviceSecret, isEmpty);
    expect(state.pinHash, isEmpty);
    expect(state.biometricsEnabled, isFalse);
    expect(state.failedPinAttempts, 0);
    expect(state.lockedUntil, isNull);
  });

  test(
    'registration forwards mobile metadata and replacement choice',
    () async {
      Map<String, String>? receivedPayload;
      bool? receivedReplace;
      final service = TrustedDeviceService(
        pinIterations: 10,
        devicePayloadBuilder: () async => {
          'device_uuid': 'installation-id',
          'platform': 'ios',
          'device_name': 'iPad',
          'model': 'iPad',
          'app_version': '1.0.0+1',
        },
        registerDevice: (payload, replace) async {
          receivedPayload = payload;
          receivedReplace = replace;
          return registration();
        },
      );

      final result = await service.register(replace: true);

      expect(result.deviceSecret, 'server-secret');
      expect(receivedPayload?['platform'], 'ios');
      expect(receivedPayload?['device_uuid'], 'installation-id');
      expect(receivedReplace, isTrue);
    },
  );

  test(
    'invalid device credentials are surfaced without opening a session',
    () async {
      final service = TrustedDeviceService(
        pinIterations: 10,
        createDeviceSession: (_, _) async =>
            throw const TrustedDeviceApiException(
              code: 1030002,
              message: 'Invalid device credentials',
            ),
      );
      await TrustedDeviceStorage.save({
        TrustedDeviceStorage.deviceUuidKey: 'installation-id',
      });
      await service.completeSetup(
        username: 'engineer',
        pin: '123456',
        biometricsEnabled: false,
        registration: registration(),
      );

      expect(
        service.createDeviceSession(),
        throwsA(
          isA<TrustedDeviceApiException>().having(
            (error) => error.code,
            'code',
            1030002,
          ),
        ),
      );
    },
  );

  test(
    'revoke calls backend then clears credentials but retains UUID',
    () async {
      var revokeCalled = false;
      final service = TrustedDeviceService(
        pinIterations: 10,
        revokeDevice: () async => revokeCalled = true,
        createDeviceSession: (_, _) async => LoginInfo(),
      );
      await TrustedDeviceStorage.save({
        TrustedDeviceStorage.deviceUuidKey: 'installation-id',
        TrustedDeviceStorage.deviceSecretKey: 'server-secret',
        TrustedDeviceStorage.pinSaltKey: 'salt',
        TrustedDeviceStorage.pinHashKey: 'hash',
      });

      await service.revoke();
      final state = await service.loadState();

      expect(revokeCalled, isTrue);
      expect(state.deviceUuid, 'installation-id');
      expect(state.isConfigured, isFalse);
    },
  );

  test('trusted-device flow is limited to iOS and Android', () {
    PlatformHelper.instance.currentPlatform = PlatformName.iOS;
    expect(TrustedDeviceService(pinIterations: 10).isSupportedPlatform, isTrue);
    PlatformHelper.instance.currentPlatform = PlatformName.android;
    expect(TrustedDeviceService(pinIterations: 10).isSupportedPlatform, isTrue);
    PlatformHelper.instance.currentPlatform = PlatformName.macOS;
    expect(
      TrustedDeviceService(pinIterations: 10).isSupportedPlatform,
      isFalse,
    );
    PlatformHelper.instance.currentPlatform = PlatformName.web;
    expect(
      TrustedDeviceService(pinIterations: 10).isSupportedPlatform,
      isFalse,
    );
  });
}
