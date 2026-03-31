import 'package:maintapp/common/data_helper.dart';

class WorkOrderForm {
  String id = '';
  String workOrderId = '';
  String templateId = '';
  String reportNo = '';
  String status = '';
  Map<String, dynamic> dataJson = {};
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
    dataJson = DataHelper.getMapSafely(
      json,
      'data_json',
    );
    pdfUrl = DataHelper.getStringSafely(json, 'pdf_url', '');
    createdAt = DataHelper.getStringSafely(json, 'created_at', '');
    updatedAt = DataHelper.getStringSafely(json, 'updated_at', '');
  }
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
