import 'package:maintapp/common/data_helper.dart';

class UserVisit {
  String id = '';
  String userId = '';
  String institutionCode = '';
  String plannedDate = '';
  String startedAt = '';
  String endedAt = '';
  String status = '';
  Map<String, dynamic> raw = {};

  UserVisit();

  UserVisit.fromJson(Map<dynamic, dynamic> json) {
    raw = Map<String, dynamic>.from(json);
    id = DataHelper.getStringSafely(json, 'id', '');
    userId = DataHelper.getStringSafely(json, 'user_id', '');
    institutionCode = DataHelper.getStringSafely(json, 'institution_code', '');
    plannedDate = DataHelper.getStringSafely(json, 'planned_date', '');
    startedAt = DataHelper.getStringSafely(json, 'started_at', '');
    endedAt = DataHelper.getStringSafely(json, 'ended_at', '');
    status = DataHelper.getStringSafely(json, 'status', '');
  }
}

class UserVisitList {
  List<UserVisit> items = [];
  int total = 0;
  int limit = 0;
  int offset = 0;

  UserVisitList();

  UserVisitList.fromJson(Map<dynamic, dynamic> json) {
    items = DataHelper.getListOfMapSafely(json, 'items')
        .map((item) => UserVisit.fromJson(item))
        .toList();
    if (items.isEmpty && json['data'] is Map<dynamic, dynamic>) {
      items = DataHelper.getListOfMapSafely(json['data'], 'items')
          .map((item) => UserVisit.fromJson(item))
          .toList();
    }
    total = DataHelper.getIntSafely(json, 'total', items.length);
    limit = DataHelper.getIntSafely(json, 'limit', 0);
    offset = DataHelper.getIntSafely(json, 'offset', 0);
  }
}
