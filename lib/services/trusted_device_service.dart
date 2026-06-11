import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';
import 'package:maintapp/api/api_controller.dart';
import 'package:maintapp/common/device_info_controller.dart';
import 'package:maintapp/common/platform_helper.dart';
import 'package:maintapp/common/trusted_device_storage.dart';
import 'package:maintapp/model/login_info.dart';
import 'package:maintapp/model/trusted_device.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

enum BiometricUnlockResult {
  authenticated,
  cancelled,
  unavailable,
  temporarilyLocked,
  permanentlyLocked,
  failed,
}

class TrustedDeviceService {
  TrustedDeviceService({
    LocalAuthentication? localAuthentication,
    DateTime Function()? now,
    int pinIterations = 120000,
    Future<Map<String, String>> Function()? devicePayloadBuilder,
    Future<TrustedDeviceRegistration> Function(
      Map<String, String> payload,
      bool replace,
    )?
    registerDevice,
    Future<LoginInfo> Function(String deviceUuid, String deviceSecret)?
    createDeviceSession,
    Future<void> Function()? revokeDevice,
  }) : _localAuthentication = localAuthentication ?? LocalAuthentication(),
       _now = now ?? DateTime.now,
       _pinIterations = pinIterations,
       _devicePayloadBuilder = devicePayloadBuilder,
       _registerDevice =
           registerDevice ??
           ((payload, replace) => ApiController.registerTrustedDevice(
             payload: payload,
             replace: replace,
           )),
       _createDeviceSession =
           createDeviceSession ??
           ((deviceUuid, deviceSecret) =>
               ApiController.createTrustedDeviceSession(
                 deviceUuid: deviceUuid,
                 deviceSecret: deviceSecret,
               )),
       _revokeDevice = revokeDevice ?? ApiController.revokeTrustedDevice;

  static final TrustedDeviceService instance = TrustedDeviceService();

  static const int maximumPinAttempts = 5;
  static const int _derivedKeyLength = 32;

  final LocalAuthentication _localAuthentication;
  final DateTime Function() _now;
  final int _pinIterations;
  final Future<Map<String, String>> Function()? _devicePayloadBuilder;
  final Future<TrustedDeviceRegistration> Function(
    Map<String, String> payload,
    bool replace,
  )
  _registerDevice;
  final Future<LoginInfo> Function(String deviceUuid, String deviceSecret)
  _createDeviceSession;
  final Future<void> Function() _revokeDevice;

  bool get isSupportedPlatform =>
      PlatformHelper.instance.supportsTrustedDeviceUnlock();

  Future<TrustedDeviceLocalState> loadState() => TrustedDeviceStorage.load();

  Future<String> installationUuid() async {
    final state = await loadState();
    if (state.deviceUuid.isNotEmpty) {
      return state.deviceUuid;
    }
    final value = const Uuid().v4();
    await TrustedDeviceStorage.save({
      TrustedDeviceStorage.deviceUuidKey: value,
    });
    return value;
  }

  Future<Map<String, String>> buildDevicePayload() async {
    await DeviceInfoController.instance.init();
    final packageInfo = await PackageInfo.fromPlatform();
    final controller = DeviceInfoController.instance;
    final model = controller.getModel();
    final platform = PlatformHelper.instance.currentPlatform == PlatformName.iOS
        ? 'ios'
        : 'android';
    return {
      'device_uuid': await installationUuid(),
      'platform': platform,
      'device_name': model.isEmpty ? platform : model,
      'model': model,
      'app_version': '${packageInfo.version}+${packageInfo.buildNumber}',
    };
  }

  Future<TrustedDeviceRegistration> register({bool replace = false}) async {
    final payload =
        await (_devicePayloadBuilder?.call() ?? buildDevicePayload());
    return _registerDevice(payload, replace);
  }

  Future<void> completeSetup({
    required String username,
    required String pin,
    required bool biometricsEnabled,
    required TrustedDeviceRegistration registration,
  }) async {
    final salt = _randomBytes(16);
    final hash = _derivePin(pin, salt);
    await TrustedDeviceStorage.save({
      TrustedDeviceStorage.deviceSecretKey: registration.deviceSecret,
      TrustedDeviceStorage.usernameKey: username,
      TrustedDeviceStorage.pinSaltKey: base64Encode(salt),
      TrustedDeviceStorage.pinHashKey: base64Encode(hash),
      TrustedDeviceStorage.biometricsEnabledKey: biometricsEnabled.toString(),
      TrustedDeviceStorage.failedPinAttemptsKey: '0',
      TrustedDeviceStorage.lockedUntilKey: '',
      TrustedDeviceStorage.appLockedKey: 'false',
    });
  }

  Future<bool> verifyPin(String pin) async {
    final state = await loadState();
    if (!state.isConfigured || state.isLocked) {
      return false;
    }

    final actual = _derivePin(pin, base64Decode(state.pinSalt));
    final expected = base64Decode(state.pinHash);
    final matches = _constantTimeEquals(actual, expected);
    if (matches) {
      await TrustedDeviceStorage.clearPinFailures();
      return true;
    }

    final attempts = state.failedPinAttempts + 1;
    DateTime? lockedUntil;
    if (attempts >= maximumPinAttempts) {
      final lockoutIndex = attempts - maximumPinAttempts;
      final seconds = min(30 * (1 << min(lockoutIndex, 6)), 1800);
      lockedUntil = _now().add(Duration(seconds: seconds));
    }
    await TrustedDeviceStorage.save({
      TrustedDeviceStorage.failedPinAttemptsKey: attempts.toString(),
      TrustedDeviceStorage.lockedUntilKey: lockedUntil?.toIso8601String() ?? '',
    });
    return false;
  }

  Future<bool> canUseBiometrics() async {
    if (!isSupportedPlatform) return false;
    try {
      return await _localAuthentication.isDeviceSupported() &&
          await _localAuthentication.canCheckBiometrics &&
          (await _localAuthentication.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<BiometricUnlockResult> authenticateBiometrically() async {
    if (!(await canUseBiometrics())) {
      return BiometricUnlockResult.unavailable;
    }
    try {
      final authenticated = await _localAuthentication.authenticate(
        localizedReason: 'Unlock PPT Maintenance System',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      if (authenticated) {
        await TrustedDeviceStorage.clearPinFailures();
        return BiometricUnlockResult.authenticated;
      }
      return BiometricUnlockResult.cancelled;
    } on LocalAuthException catch (error) {
      if (error.code == LocalAuthExceptionCode.temporaryLockout) {
        return BiometricUnlockResult.temporarilyLocked;
      }
      if (error.code == LocalAuthExceptionCode.biometricLockout) {
        return BiometricUnlockResult.permanentlyLocked;
      }
      if (error.code == LocalAuthExceptionCode.noBiometricHardware ||
          error.code == LocalAuthExceptionCode.noBiometricsEnrolled ||
          error.code == LocalAuthExceptionCode.noCredentialsSet ||
          error.code ==
              LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable) {
        return BiometricUnlockResult.unavailable;
      }
      if (error.code == LocalAuthExceptionCode.userCanceled ||
          error.code == LocalAuthExceptionCode.systemCanceled ||
          error.code == LocalAuthExceptionCode.userRequestedFallback) {
        return BiometricUnlockResult.cancelled;
      }
      return BiometricUnlockResult.failed;
    } catch (_) {
      return BiometricUnlockResult.failed;
    }
  }

  Future<LoginInfo> createDeviceSession() async {
    final state = await loadState();
    if (!state.isConfigured) {
      throw const TrustedDeviceApiException(
        code: 1030002,
        message: 'Trusted device is not configured',
      );
    }
    return _createDeviceSession(state.deviceUuid, state.deviceSecret);
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    await TrustedDeviceStorage.save({
      TrustedDeviceStorage.biometricsEnabledKey: enabled.toString(),
    });
  }

  Future<void> changePin(String pin) async {
    final salt = _randomBytes(16);
    await TrustedDeviceStorage.save({
      TrustedDeviceStorage.pinSaltKey: base64Encode(salt),
      TrustedDeviceStorage.pinHashKey: base64Encode(_derivePin(pin, salt)),
      TrustedDeviceStorage.failedPinAttemptsKey: '0',
      TrustedDeviceStorage.lockedUntilKey: '',
    });
  }

  Future<void> revoke() async {
    await _revokeDevice();
    await TrustedDeviceStorage.clearRegistration();
  }

  Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  Uint8List _derivePin(String pin, List<int> salt) {
    final password = utf8.encode(pin);
    final hmac = Hmac(sha256, password);
    final output = BytesBuilder(copy: false);
    var blockIndex = 1;
    while (output.length < _derivedKeyLength) {
      final block = Uint8List(4)..buffer.asByteData().setUint32(0, blockIndex);
      var u = hmac.convert([...salt, ...block]).bytes;
      final result = Uint8List.fromList(u);
      for (var iteration = 1; iteration < _pinIterations; iteration++) {
        u = hmac.convert(u).bytes;
        for (var index = 0; index < result.length; index++) {
          result[index] ^= u[index];
        }
      }
      output.add(result);
      blockIndex++;
    }
    return Uint8List.fromList(output.toBytes().sublist(0, _derivedKeyLength));
  }

  bool _constantTimeEquals(List<int> first, List<int> second) {
    if (first.length != second.length) return false;
    var difference = 0;
    for (var index = 0; index < first.length; index++) {
      difference |= first[index] ^ second[index];
    }
    return difference == 0;
  }
}
