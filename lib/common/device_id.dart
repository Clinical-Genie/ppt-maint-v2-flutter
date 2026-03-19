import 'package:app_set_id/app_set_id.dart';

class DeviceId {
  static final _appSetIdPlugin = AppSetId();

  static Future<String> getDeviceId() async {
    const bool inTest = bool.fromEnvironment('flutter.test');

    String deviceId = await _appSetIdPlugin.getIdentifier() ?? "Unknown";
    if (inTest) {
      return "8F663D6B-72F6-4A39-8433-6D898BC34283";
    } else {
      return deviceId;
    }
  }
}
