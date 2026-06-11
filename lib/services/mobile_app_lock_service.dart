import 'package:maintapp/common/platform_helper.dart';
import 'package:maintapp/common/trusted_device_storage.dart';

class MobileAppLockService {
  const MobileAppLockService();

  static const MobileAppLockService instance = MobileAppLockService();

  bool get isSupported => PlatformHelper.instance.supportsTrustedDeviceUnlock();

  Future<bool> hasTrustedDevice() async {
    if (!isSupported) return false;
    return (await TrustedDeviceStorage.load()).isConfigured;
  }

  Future<bool> isLockRequired() async {
    if (!isSupported) return false;
    return (await TrustedDeviceStorage.load()).appLocked;
  }

  Future<bool> lock() async {
    if (!await hasTrustedDevice()) return false;
    await TrustedDeviceStorage.setAppLocked(true);
    return true;
  }

  Future<bool> lockForBackground({required bool isLoggedIn}) async {
    if (!isSupported || !isLoggedIn) return false;
    await TrustedDeviceStorage.setAppLocked(true);
    return true;
  }

  Future<void> unlock() async {
    if (!isSupported) return;
    await TrustedDeviceStorage.setAppLocked(false);
  }

  Future<String> loggedOutRoute() async {
    return await lock() ? '/device-unlock' : '/login';
  }

  Future<String> unlockRoute() async {
    return await hasTrustedDevice() ? '/device-unlock' : '/login';
  }
}
