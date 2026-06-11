import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maintapp/common/platform_helper.dart';
import 'package:maintapp/common/secure_storage.dart';
import 'package:maintapp/common/trusted_device_storage.dart';
import 'package:maintapp/services/mobile_app_lock_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SecureStorage.instance.data.clear();
  });

  Future<void> configureTrustedDevice() {
    return TrustedDeviceStorage.save({
      TrustedDeviceStorage.deviceUuidKey: 'installation-id',
      TrustedDeviceStorage.deviceSecretKey: 'server-secret',
      TrustedDeviceStorage.usernameKey: 'engineer',
      TrustedDeviceStorage.pinSaltKey: 'salt',
      TrustedDeviceStorage.pinHashKey: 'hash',
      TrustedDeviceStorage.biometricsEnabledKey: 'false',
    });
  }

  test('mobile logout routes configured device to unlock', () async {
    PlatformHelper.instance.currentPlatform = PlatformName.android;
    await configureTrustedDevice();

    expect(
      await MobileAppLockService.instance.loggedOutRoute(),
      '/device-unlock',
    );
    expect((await TrustedDeviceStorage.load()).appLocked, isTrue);
  });

  test('mobile logout without PIN setup routes to password login', () async {
    PlatformHelper.instance.currentPlatform = PlatformName.iOS;
    await TrustedDeviceStorage.save({
      TrustedDeviceStorage.deviceUuidKey: 'installation-id',
    });

    expect(await MobileAppLockService.instance.loggedOutRoute(), '/login');
  });

  test('desktop and web logout remain on password login', () async {
    await configureTrustedDevice();

    PlatformHelper.instance.currentPlatform = PlatformName.macOS;
    expect(await MobileAppLockService.instance.loggedOutRoute(), '/login');

    PlatformHelper.instance.currentPlatform = PlatformName.web;
    expect(await MobileAppLockService.instance.loggedOutRoute(), '/login');
  });

  test('background lock persists until successful authentication', () async {
    PlatformHelper.instance.currentPlatform = PlatformName.android;
    await configureTrustedDevice();

    expect(
      await MobileAppLockService.instance.lockForBackground(isLoggedIn: true),
      isTrue,
    );
    expect(await MobileAppLockService.instance.isLockRequired(), isTrue);

    const restartedService = MobileAppLockService();
    expect(await restartedService.isLockRequired(), isTrue);

    await restartedService.unlock();
    expect(await restartedService.isLockRequired(), isFalse);
  });

  test('untrusted mobile background lock requires password route', () async {
    PlatformHelper.instance.currentPlatform = PlatformName.android;

    expect(
      await MobileAppLockService.instance.lockForBackground(isLoggedIn: true),
      isTrue,
    );
    expect(await MobileAppLockService.instance.isLockRequired(), isTrue);
    expect(await MobileAppLockService.instance.unlockRoute(), '/login');

    await MobileAppLockService.instance.unlock();
    expect(await MobileAppLockService.instance.isLockRequired(), isFalse);
  });

  test('trusted mobile background lock requires device unlock route', () async {
    PlatformHelper.instance.currentPlatform = PlatformName.iOS;
    await configureTrustedDevice();

    expect(
      await MobileAppLockService.instance.lockForBackground(isLoggedIn: true),
      isTrue,
    );
    expect(await MobileAppLockService.instance.unlockRoute(), '/device-unlock');
  });

  test(
    'background does not lock when no authenticated session exists',
    () async {
      PlatformHelper.instance.currentPlatform = PlatformName.android;
      await configureTrustedDevice();

      expect(
        await MobileAppLockService.instance.lockForBackground(
          isLoggedIn: false,
        ),
        isFalse,
      );
      expect(await MobileAppLockService.instance.isLockRequired(), isFalse);
    },
  );
}
