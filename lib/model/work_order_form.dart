import 'package:maintapp/common/data_helper.dart';

class WorkOrderForm {
  String id = '';
  String workOrderId = '';
  String templateId = '';
  String reportNo = '';
  String status = '';
  Map<String, dynamic> dataJson = {};
  Map<String, List<WorkOrderFormFieldRemarkItem>> fieldRemarks = {};
  List<WorkOrderFormFieldRemarkItem> fieldRemarkItems = [];
  String pdfUrl = '';
  String createdAt = '';
  String updatedAt = '';
  Map<String, dynamic> raw = {};

  WorkOrderForm();

  WorkOrderForm.fromJson(Map<dynamic, dynamic> json) {
    raw = Map<String, dynamic>.from(json);
    id = DataHelper.getStringSafely(json, 'id', '');
    workOrderId = DataHelper.getStringSafely(json, 'work_order_id', '');
    templateId = DataHelper.getStringSafely(json, 'template_id', '');
    reportNo = DataHelper.getStringSafely(json, 'report_no', '');
    status = DataHelper.getStringSafely(json, 'status', '');
    dataJson = DataHelper.getMapSafely(json, 'data_json');
    fieldRemarkItems = DataHelper.getListOfMapSafely(
      json,
      'field_remark_items',
    ).map((item) => WorkOrderFormFieldRemarkItem.fromJson(item)).toList();
    final rawFieldRemarks = json['field_remarks'];
    if (rawFieldRemarks is Map) {
      fieldRemarks = rawFieldRemarks.map((key, value) {
        final items = value is List
            ? value
                  .whereType<Map<dynamic, dynamic>>()
                  .map((item) => WorkOrderFormFieldRemarkItem.fromJson(item))
                  .toList()
            : <WorkOrderFormFieldRemarkItem>[];
        return MapEntry('$key'.trim(), items);
      });
    }
    pdfUrl = DataHelper.getStringSafely(json, 'pdf_url', '');
    createdAt = DataHelper.getStringSafely(json, 'created_at', '');
    updatedAt = DataHelper.getStringSafely(json, 'updated_at', '');
  }
}

class WorkOrderFormFieldRemarkItem {
  String id = '';
  String fieldKey = '';
  String remark = '';
  String createdBy = '';
  String createdByName = '';
  String createdAt = '';
  String updatedBy = '';
  String updatedByName = '';
  String updatedAt = '';
  String deletedBy = '';
  String deletedAt = '';

  WorkOrderFormFieldRemarkItem();

  WorkOrderFormFieldRemarkItem.fromJson(Map<dynamic, dynamic> json) {
    id = DataHelper.getStringSafely(json, 'id', '');
    fieldKey = DataHelper.getStringSafely(json, 'field_key', '');
    remark = DataHelper.getStringSafely(json, 'remark', '');
    createdBy = DataHelper.getStringSafely(json, 'created_by', '');
    createdByName = DataHelper.getStringSafely(json, 'created_by_name', '');
    createdAt = DataHelper.getStringSafely(json, 'created_at', '');
    updatedBy = DataHelper.getStringSafely(json, 'updated_by', '');
    updatedByName = DataHelper.getStringSafely(json, 'updated_by_name', '');
    updatedAt = DataHelper.getStringSafely(json, 'updated_at', '');
    deletedBy = DataHelper.getStringSafely(json, 'deleted_by', '');
    deletedAt = DataHelper.getStringSafely(json, 'deleted_at', '');
  }
}

class WorkOrderFormRemarkMutationResult {
  String message = '';
  String formStatus = '';
  WorkOrderFormFieldRemarkItem remark = WorkOrderFormFieldRemarkItem();
  Map<String, dynamic> raw = {};

  WorkOrderFormRemarkMutationResult();

  WorkOrderFormRemarkMutationResult.fromJson(Map<dynamic, dynamic> json) {
    raw = Map<String, dynamic>.from(json);
    message = DataHelper.getStringSafely(json, 'message', '');
    formStatus = DataHelper.getStringSafely(json, 'form_status', '');
    final rawRemark = json['remark'];
    if (rawRemark is Map) {
      remark = WorkOrderFormFieldRemarkItem.fromJson(rawRemark);
    }
  }

  bool get isSuccess => remark.id.trim().isNotEmpty;
}

class WorkOrderFormSignResult {
  String message = '';
  String pdfUrl = '';
  String reportNo = '';
  String signatureUrl = '';
  Map<String, dynamic> raw = {};

  WorkOrderFormSignResult();

  WorkOrderFormSignResult.fromJson(Map<dynamic, dynamic> json) {
    raw = Map<String, dynamic>.from(json);
    message = DataHelper.getStringSafely(json, 'message', '');
    pdfUrl = DataHelper.getStringSafely(json, 'pdf_url', '');
    reportNo = DataHelper.getStringSafely(json, 'report_no', '');
    signatureUrl = DataHelper.getStringSafely(json, 'signature_url', '');
  }
}
