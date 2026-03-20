import 'package:maintapp/common/data_helper.dart';

class WorkOrderSourceFile {
  String id = '';
  String workOrderId = '';
  String fileName = '';
  String downloadUrl = '';
  String contentType = '';
  int size = 0;
  String uploadedBy = '';
  String uploadedAt = '';
  String ocrJobId = '';
  Map<String, dynamic> raw = {};

  WorkOrderSourceFile();

  WorkOrderSourceFile.fromJson(Map<dynamic, dynamic> json) {
    raw = Map<String, dynamic>.from(json);
    id = DataHelper.getStringSafely(json, 'id', '');
    workOrderId = DataHelper.getStringSafely(json, 'work_order_id', '');
    fileName = DataHelper.getStringSafely(
      json,
      'file_name',
      DataHelper.getStringSafely(json, 'source_file_name', ''),
    );
    downloadUrl = DataHelper.getStringSafely(
      json,
      'download_url',
      DataHelper.getStringSafely(json, 'source_file_url', ''),
    );
    contentType = DataHelper.getStringSafely(json, 'content_type', '');
    size = DataHelper.getIntSafely(json, 'size', 0);
    uploadedBy = DataHelper.getStringSafely(json, 'uploaded_by', '');
    uploadedAt = DataHelper.getStringSafely(
      json,
      'uploaded_at',
      DataHelper.getStringSafely(json, 'created_at', ''),
    );
    ocrJobId = DataHelper.getStringSafely(json, 'ocr_job_id', '');
  }
}
