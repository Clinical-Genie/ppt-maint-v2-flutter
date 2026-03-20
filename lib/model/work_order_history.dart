import 'dart:convert';

import 'package:maintapp/common/data_helper.dart';

class WorkOrderHistoryEntry {
  String id = '';
  String workOrderId = '';
  String action = '';
  String actorUserId = '';
  String actorNameSnapshot = '';
  String summary = '';
  Map<String, dynamic> detailsJson = {};
  String fromStatus = '';
  String toStatus = '';
  String createdAt = '';

  WorkOrderHistoryEntry();

  WorkOrderHistoryEntry.fromJson(Map<dynamic, dynamic> json) {
    id = DataHelper.getStringSafely(json, 'id', '');
    workOrderId = DataHelper.getStringSafely(json, 'work_order_id', '');
    action = DataHelper.getStringSafely(json, 'action', '');
    actorUserId = DataHelper.getStringSafely(json, 'actor_user_id', '');
    actorNameSnapshot = DataHelper.getStringSafely(
      json,
      'actor_name_snapshot',
      '',
    );
    summary = DataHelper.getStringSafely(json, 'summary', '');
    detailsJson = DataHelper.getMapSafely(json, 'details_json');
    fromStatus = DataHelper.getStringSafely(json, 'from_status', '');
    toStatus = DataHelper.getStringSafely(json, 'to_status', '');
    createdAt = DataHelper.getStringSafely(json, 'created_at', '');
  }

  String get displaySummary => summary.isEmpty ? action : summary;

  String get prettyDetails {
    if (detailsJson.isEmpty) return '';
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(detailsJson);
  }
}

class WorkOrderHistoryResponse {
  String order = 'desc';
  List<WorkOrderHistoryEntry> items = [];

  WorkOrderHistoryResponse();

  WorkOrderHistoryResponse.fromJson(Map<dynamic, dynamic> json) {
    order = DataHelper.getStringSafely(json, 'order', 'desc');
    items = DataHelper.getListOfMapSafely(json, 'items')
        .map((item) => WorkOrderHistoryEntry.fromJson(item))
        .toList();
  }
}
