import 'package:maintapp/common/data_helper.dart';

class AdminEmailLog {
  String id = '';
  String template = '';
  String status = '';
  String subject = '';
  String provider = '';
  String providerMessageId = '';
  String error = '';
  String createdAt = '';
  String updatedAt = '';
  Map<String, dynamic> raw = {};

  AdminEmailLog();

  AdminEmailLog.fromJson(Map<dynamic, dynamic> json) {
    raw = Map<String, dynamic>.from(json);
    id = DataHelper.getStringSafely(json, 'id', '');
    template = DataHelper.getStringSafely(json, 'template', '');
    status = DataHelper.getStringSafely(json, 'status', '');
    subject = DataHelper.getStringSafely(json, 'subject', '');
    provider = DataHelper.getStringSafely(json, 'provider', '');
    providerMessageId = DataHelper.getStringSafely(
      json,
      'provider_message_id',
      '',
    );
    error = DataHelper.getStringSafely(json, 'error', '');
    createdAt = DataHelper.getStringSafely(json, 'created_at', '');
    updatedAt = DataHelper.getStringSafely(json, 'updated_at', '');
  }
}

class AdminEmailLogList {
  List<AdminEmailLog> items = [];
  int total = 0;
  int limit = 0;
  int offset = 0;

  AdminEmailLogList();

  AdminEmailLogList.fromJson(Map<dynamic, dynamic> json) {
    items = DataHelper.getListOfMapSafely(json, 'items')
        .map((item) => AdminEmailLog.fromJson(item))
        .toList();
    total = DataHelper.getIntSafely(json, 'total', items.length);
    limit = DataHelper.getIntSafely(json, 'limit', 0);
    offset = DataHelper.getIntSafely(json, 'offset', 0);
  }
}
