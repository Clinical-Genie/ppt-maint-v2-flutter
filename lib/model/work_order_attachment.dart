import 'package:maintapp/common/data_helper.dart';

class WorkOrderAttachment {
  String id = '';
  String workOrderId = '';
  String fileName = '';
  String fileUrl = '';
  String contentType = '';
  String description = '';
  String createdAt = '';
  Map<String, dynamic> raw = {};

  WorkOrderAttachment();

  WorkOrderAttachment.fromJson(Map<dynamic, dynamic> json) {
    raw = Map<String, dynamic>.from(json);
    id = DataHelper.getStringSafely(json, 'id', '');
    workOrderId = DataHelper.getStringSafely(json, 'work_order_id', '');
    fileName = DataHelper.getStringSafely(
      json,
      'file_name',
      DataHelper.getStringSafely(
        json,
        'filename',
        DataHelper.getStringSafely(json, 'name', ''),
      ),
    );
    fileUrl = DataHelper.getStringSafely(
      json,
      'file_url',
      DataHelper.getStringSafely(
        json,
        'download_url',
        DataHelper.getStringSafely(json, 'url', ''),
      ),
    );
    contentType = DataHelper.getStringSafely(
      json,
      'content_type',
      DataHelper.getStringSafely(json, 'mime_type', ''),
    );
    description = DataHelper.getStringSafely(json, 'description', '');
    createdAt = DataHelper.getStringSafely(
      json,
      'created_at',
      DataHelper.getStringSafely(json, 'uploaded_at', ''),
    );
  }

  String get displayLabel {
    if (fileName.trim().isNotEmpty) return fileName.trim();
    if (description.trim().isNotEmpty) return description.trim();
    return id.isEmpty ? 'Attachment' : id;
  }
}

class WorkOrderAttachmentList {
  List<WorkOrderAttachment> items = [];

  WorkOrderAttachmentList();

  WorkOrderAttachmentList.fromJson(Map<dynamic, dynamic> json) {
    final dynamic source =
        json['items'] ??
        json['attachments'] ??
        json['rows'] ??
        (json['data'] is Map
            ? (json['data']['items'] ??
                  json['data']['attachments'] ??
                  json['data']['rows'])
            : null);

    if (source is List) {
      items = source
          .whereType<Map<dynamic, dynamic>>()
          .map((item) => WorkOrderAttachment.fromJson(item))
          .toList();
    }
  }
}
