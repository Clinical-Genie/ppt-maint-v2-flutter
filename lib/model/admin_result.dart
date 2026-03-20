import 'package:maintapp/common/data_helper.dart';

class AdminResetPasswordResult {
  String message = '';
  String userId = '';
  String newPassword = '';
  bool revokeSessions = false;
  Map<String, dynamic> raw = {};

  AdminResetPasswordResult();

  AdminResetPasswordResult.fromJson(Map<dynamic, dynamic> json) {
    raw = Map<String, dynamic>.from(json);
    message = DataHelper.getStringSafely(json, 'message', '');
    userId = DataHelper.getStringSafely(
      json,
      'user_id',
      DataHelper.getStringSafely(json, 'id', ''),
    );
    newPassword = DataHelper.getStringSafely(
      json,
      'new_password',
      DataHelper.getStringSafely(json, 'password', ''),
    );
    revokeSessions = DataHelper.getBoolSafely(json, 'revoke_sessions', false);
  }
}

class AdminPingResult {
  String message = '';
  String status = '';
  String serverTime = '';
  Map<String, dynamic> raw = {};

  AdminPingResult();

  AdminPingResult.fromJson(Map<dynamic, dynamic> json) {
    raw = Map<String, dynamic>.from(json);
    message = DataHelper.getStringSafely(json, 'message', '');
    status = DataHelper.getStringSafely(
      json,
      'status',
      DataHelper.getStringSafely(json, 'ok', ''),
    );
    serverTime = DataHelper.getStringSafely(
      json,
      'server_time',
      DataHelper.getStringSafely(json, 'time', ''),
    );
  }
}

class HousekeepingRunResult {
  String message = '';
  String status = '';
  int affectedCount = 0;
  Map<String, dynamic> raw = {};

  HousekeepingRunResult();

  HousekeepingRunResult.fromJson(Map<dynamic, dynamic> json) {
    raw = Map<String, dynamic>.from(json);
    message = DataHelper.getStringSafely(json, 'message', '');
    status = DataHelper.getStringSafely(json, 'status', '');
    affectedCount = DataHelper.getIntSafely(
      json,
      'affected_count',
      DataHelper.getIntSafely(json, 'count', 0),
    );
  }
}
