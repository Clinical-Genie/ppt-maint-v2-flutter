import 'package:maintapp/common/secure_storage.dart';

class TrustedDeviceLocalState {
  const TrustedDeviceLocalState({
    required this.deviceUuid,
    required this.deviceSecret,
    required this.username,
    required this.pinSalt,
    required this.pinHash,
    required this.biometricsEnabled,
    required this.failedPinAttempts,
    required this.appLocked,
    this.lockedUntil,
  });

  final String deviceUuid;
  final String deviceSecret;
  final String username;
  final String pinSalt;
  final String pinHash;
  final bool biometricsEnabled;
  final int failedPinAttempts;
  final bool appLocked;
  final DateTime? lockedUntil;

  bool get isConfigured =>
      deviceUuid.isNotEmpty &&
      deviceSecret.isNotEmpty &&
      pinSalt.isNotEmpty &&
      pinHash.isNotEmpty;

  bool get isLocked =>
      lockedUntil != null && lockedUntil!.isAfter(DateTime.now());
}

class TrustedDeviceStorage {
  static const String group = 'trusted_device';
  static const String deviceUuidKey = 'trusted_device_uuid';
  static const String deviceSecretKey = 'trusted_device_secret';
  static const String usernameKey = 'trusted_device_username';
  static const String pinSaltKey = 'trusted_device_pin_salt';
  static const String pinHashKey = 'trusted_device_pin_hash';
  static const String biometricsEnabledKey =
      'trusted_device_biometrics_enabled';
  static const String failedPinAttemptsKey =
      'trusted_device_failed_pin_attempts';
  static const String lockedUntilKey = 'trusted_device_locked_until';
  static const String appLockedKey = 'trusted_device_app_locked';

  static Future<TrustedDeviceLocalState> load() async {
    await SecureStorage.instance.loadDataFromSecureStorage(group);
    String value(String key) =>
        SecureStorage.instance.getData(group, key, '').trim();

    return TrustedDeviceLocalState(
      deviceUuid: value(deviceUuidKey),
      deviceSecret: value(deviceSecretKey),
      username: value(usernameKey),
      pinSalt: value(pinSaltKey),
      pinHash: value(pinHashKey),
      biometricsEnabled: value(biometricsEnabledKey) == 'true',
      failedPinAttempts: int.tryParse(value(failedPinAttemptsKey)) ?? 0,
      appLocked: value(appLockedKey) == 'true',
      lockedUntil: DateTime.tryParse(value(lockedUntilKey)),
    );
  }

  static Future<void> save(Map<String, String> values) async {
    await SecureStorage.instance.loadDataFromSecureStorage(group);
    for (final entry in values.entries) {
      SecureStorage.instance.setData(group, entry.key, entry.value);
    }
    await SecureStorage.instance.saveDataToSecureStorage(group);
  }

  static Future<void> clearRegistration({bool keepUuid = true}) async {
    final state = await load();
    SecureStorage.instance.replaceCategoryWithDataSet(group, {
      if (keepUuid && state.deviceUuid.isNotEmpty)
        deviceUuidKey: state.deviceUuid,
    });
    await SecureStorage.instance.saveDataToSecureStorage(group);
  }

  static Future<void> clearPinFailures() async {
    await save({failedPinAttemptsKey: '0', lockedUntilKey: ''});
  }

  static Future<void> setAppLocked(bool locked) async {
    await save({appLockedKey: locked.toString()});
  }
}
