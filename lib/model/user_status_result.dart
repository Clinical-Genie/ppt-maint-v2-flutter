import 'package:maintapp/common/data_helper.dart';

class UserStatusUpdateResult {
  String userId = '';
  bool isActive = false;
  String message = '';
  Map<String, dynamic> raw = {};

  UserStatusUpdateResult();

  UserStatusUpdateResult.fromJson(Map<dynamic, dynamic> json) {
    raw = Map<String, dynamic>.from(json);
    userId = DataHelper.getStringSafely(
      json,
      'user_id',
      DataHelper.getStringSafely(json, 'id', ''),
    );
    isActive = DataHelper.getBoolSafely(
      json,
      'is_active',
      DataHelper.getBoolSafely(json, 'active', false),
    );
    message = DataHelper.getStringSafely(json, 'message', '');
  }
}
