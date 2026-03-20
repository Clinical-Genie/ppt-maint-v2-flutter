import 'package:maintapp/common/data_helper.dart';

class ApiMessageResult {
  String message = '';
  Map<String, dynamic> raw = {};

  ApiMessageResult();

  ApiMessageResult.fromJson(Map<dynamic, dynamic> json) {
    raw = Map<String, dynamic>.from(json);
    message = DataHelper.getStringSafely(json, 'message', '');
  }
}

class WorkOrderActionResult {
  String message = '';
  String workOrderId = '';
  String status = '';
  String ownerUserId = '';
  String ownerFullName = '';
  Map<String, dynamic> raw = {};

  WorkOrderActionResult();

  WorkOrderActionResult.fromJson(Map<dynamic, dynamic> json) {
    raw = Map<String, dynamic>.from(json);
    message = DataHelper.getStringSafely(json, 'message', '');
    workOrderId = DataHelper.getStringSafely(
      json,
      'work_order_id',
      DataHelper.getStringSafely(json, 'id', ''),
    );
    status = DataHelper.getStringSafely(json, 'status', '');
    ownerUserId = DataHelper.getStringSafely(json, 'owner_user_id', '');
    ownerFullName = DataHelper.getStringSafely(json, 'owner_full_name', '');
  }
}
