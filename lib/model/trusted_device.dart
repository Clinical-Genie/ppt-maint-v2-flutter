class TrustedDevice {
  const TrustedDevice({
    required this.id,
    required this.deviceUuid,
    required this.platform,
    required this.deviceName,
    required this.model,
    required this.appVersion,
    this.registeredAt,
    this.lastUsedAt,
    this.revokedAt,
  });

  final String id;
  final String deviceUuid;
  final String platform;
  final String deviceName;
  final String model;
  final String appVersion;
  final DateTime? registeredAt;
  final DateTime? lastUsedAt;
  final DateTime? revokedAt;

  factory TrustedDevice.fromJson(Map<dynamic, dynamic> json) {
    DateTime? date(String key) {
      final value = '${json[key] ?? ''}'.trim();
      return value.isEmpty ? null : DateTime.tryParse(value);
    }

    return TrustedDevice(
      id: '${json['id'] ?? ''}',
      deviceUuid: '${json['device_uuid'] ?? ''}',
      platform: '${json['platform'] ?? ''}',
      deviceName: '${json['device_name'] ?? ''}',
      model: '${json['model'] ?? ''}',
      appVersion: '${json['app_version'] ?? ''}',
      registeredAt: date('registered_at'),
      lastUsedAt: date('last_used_at'),
      revokedAt: date('revoked_at'),
    );
  }
}

class TrustedDeviceApiException implements Exception {
  const TrustedDeviceApiException({
    required this.code,
    required this.message,
    this.existingDevice,
  });

  final int? code;
  final String message;
  final TrustedDevice? existingDevice;

  @override
  String toString() => message;
}

class TrustedDeviceRegistration {
  const TrustedDeviceRegistration({
    required this.device,
    required this.deviceSecret,
  });

  final TrustedDevice device;
  final String deviceSecret;
}
