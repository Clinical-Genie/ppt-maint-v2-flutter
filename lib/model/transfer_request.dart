import 'package:maintapp/common/data_helper.dart';

class TransferRequestWorkOrderSummary {
  String id = '';
  String woNo = '';
  String woType = '';
  String status = '';
  String priority = '';
  String locationCode = '';
  String institutionCode = '';
  String assetNumber = '';
  String serialNumber = '';
  String sourceFileId = '';
  String sourceFileName = '';
  String sourceFileUrl = '';

  TransferRequestWorkOrderSummary();

  TransferRequestWorkOrderSummary.fromJson(Map<dynamic, dynamic> json) {
    id = DataHelper.getStringSafely(json, 'id', '');
    woNo = DataHelper.getStringSafely(json, 'wo_no', '');
    woType = DataHelper.getStringSafely(json, 'wo_type', '');
    status = DataHelper.getStringSafely(json, 'status', '');
    priority = DataHelper.getStringSafely(json, 'priority', '');
    locationCode = DataHelper.getStringSafely(json, 'location_code', '');
    institutionCode = DataHelper.getStringSafely(json, 'institution_code', '');
    assetNumber = DataHelper.getStringSafely(json, 'asset_number', '');
    serialNumber = DataHelper.getStringSafely(json, 'serial_number', '');
    sourceFileId = DataHelper.getStringSafely(json, 'source_file_id', '');
    sourceFileName = DataHelper.getStringSafely(json, 'source_file_name', '');
    sourceFileUrl = DataHelper.getStringSafely(json, 'source_file_url', '');
  }
}

class TransferRequest {
  String id = '';
  String workOrderId = '';
  String requestedBy = '';
  String requestedByName = '';
  String fromEngineerId = '';
  String fromEngineerName = '';
  String toEngineerId = '';
  String toEngineerName = '';
  String status = '';
  String reason = '';
  String decidedBy = '';
  String decidedByName = '';
  String decidedAt = '';
  String createdAt = '';
  String requestType = '';
  String decisionRequiredBy = '';
  TransferRequestWorkOrderSummary workOrder = TransferRequestWorkOrderSummary();

  TransferRequest();

  TransferRequest.fromJson(Map<dynamic, dynamic> json) {
    id = DataHelper.getStringSafely(json, 'id', '');
    workOrderId = DataHelper.getStringSafely(json, 'work_order_id', '');
    requestedBy = DataHelper.getStringSafely(json, 'requested_by', '');
    requestedByName = DataHelper.getStringSafely(json, 'requested_by_name', '');
    fromEngineerId = DataHelper.getStringSafely(json, 'from_engineer_id', '');
    fromEngineerName = DataHelper.getStringSafely(
      json,
      'from_engineer_name',
      '',
    );
    toEngineerId = DataHelper.getStringSafely(json, 'to_engineer_id', '');
    toEngineerName = DataHelper.getStringSafely(json, 'to_engineer_name', '');
    status = DataHelper.getStringSafely(json, 'status', '');
    reason = DataHelper.getStringSafely(json, 'reason', '');
    decidedBy = DataHelper.getStringSafely(json, 'decided_by', '');
    decidedByName = DataHelper.getStringSafely(json, 'decided_by_name', '');
    decidedAt = DataHelper.getStringSafely(json, 'decided_at', '');
    createdAt = DataHelper.getStringSafely(json, 'created_at', '');
    requestType = DataHelper.getStringSafely(json, 'request_type', '');
    decisionRequiredBy = DataHelper.getStringSafely(
      json,
      'decision_required_by',
      '',
    );

    final nestedWorkOrder =
        json['work_order'] ?? json['wo'] ?? json['item'] ?? json['data'];
    if (nestedWorkOrder is Map<dynamic, dynamic>) {
      workOrder = TransferRequestWorkOrderSummary.fromJson(nestedWorkOrder);
    }
  }
}

class TransferRequestListResponse {
  int total = 0;
  int limit = 0;
  int offset = 0;
  List<TransferRequest> items = [];

  TransferRequestListResponse();

  TransferRequestListResponse.fromJson(Map<dynamic, dynamic> json) {
    total = DataHelper.getIntSafely(json, 'total', 0);
    limit = DataHelper.getIntSafely(json, 'limit', 0);
    offset = DataHelper.getIntSafely(json, 'offset', 0);
    items = DataHelper.getListOfMapSafely(
      json,
      'items',
    ).map((item) => TransferRequest.fromJson(item)).toList();
  }
}
