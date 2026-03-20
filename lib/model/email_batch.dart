import 'package:maintapp/common/data_helper.dart';

class EmailBatchSummary {
  String id = '';
  String createdBy = '';
  String subject = '';
  List<String> toEmails = [];
  String status = '';
  String provider = '';
  String providerMessageId = '';
  String error = '';
  String sentAt = '';
  String createdAt = '';
  String updatedAt = '';

  EmailBatchSummary();

  EmailBatchSummary.fromJson(Map<dynamic, dynamic> json) {
    id = DataHelper.getStringSafely(json, 'id', '');
    createdBy = DataHelper.getStringSafely(json, 'created_by', '');
    subject = DataHelper.getStringSafely(json, 'subject', '');
    toEmails = DataHelper.getListOfStringSafely(json, 'to_emails');
    status = DataHelper.getStringSafely(json, 'status', '');
    provider = DataHelper.getStringSafely(json, 'provider', '');
    providerMessageId = DataHelper.getStringSafely(
      json,
      'provider_message_id',
      '',
    );
    error = DataHelper.getStringSafely(json, 'error', '');
    sentAt = DataHelper.getStringSafely(json, 'sent_at', '');
    createdAt = DataHelper.getStringSafely(json, 'created_at', '');
    updatedAt = DataHelper.getStringSafely(json, 'updated_at', '');
  }
}

class EmailBatchWorkOrderItem {
  String workOrderId = '';
  String woNo = '';
  String status = '';
  String error = '';
  String sentAt = '';
  String mergedPdfUrl = '';

  EmailBatchWorkOrderItem();

  EmailBatchWorkOrderItem.fromJson(Map<dynamic, dynamic> json) {
    workOrderId = DataHelper.getStringSafely(json, 'work_order_id', '');
    woNo = DataHelper.getStringSafely(json, 'wo_no', '');
    status = DataHelper.getStringSafely(json, 'status', '');
    error = DataHelper.getStringSafely(json, 'error', '');
    sentAt = DataHelper.getStringSafely(json, 'sent_at', '');
    mergedPdfUrl = DataHelper.getStringSafely(json, 'merged_pdf_url', '');
  }
}

class EmailBatchDetail extends EmailBatchSummary {
  String bodyHtml = '';
  String bodyText = '';
  List<EmailBatchWorkOrderItem> workOrders = [];

  EmailBatchDetail();

  EmailBatchDetail.fromJson(Map<dynamic, dynamic> json) : super.fromJson(json) {
    bodyHtml = DataHelper.getStringSafely(json, 'body_html', '');
    bodyText = DataHelper.getStringSafely(json, 'body_text', '');
    workOrders = DataHelper.getListOfMapSafely(json, 'work_orders')
        .map((item) => EmailBatchWorkOrderItem.fromJson(item))
        .toList();
  }
}

class EmailBatchListResult {
  List<EmailBatchSummary> items = [];
  int total = 0;
  int limit = 0;
  int offset = 0;

  EmailBatchListResult();

  EmailBatchListResult.fromJson(Map<dynamic, dynamic> json) {
    items = DataHelper.getListOfMapSafely(json, 'items')
        .map((item) => EmailBatchSummary.fromJson(item))
        .toList();
    total = DataHelper.getIntSafely(json, 'total', items.length);
    limit = DataHelper.getIntSafely(json, 'limit', 0);
    offset = DataHelper.getIntSafely(json, 'offset', 0);
  }
}

class EmailBatchCreateResult {
  String message = '';
  String emailBatchId = '';
  String status = '';
  String createdAt = '';

  EmailBatchCreateResult();

  EmailBatchCreateResult.fromJson(Map<dynamic, dynamic> json) {
    message = DataHelper.getStringSafely(json, 'message', '');
    emailBatchId = DataHelper.getStringSafely(json, 'email_batch_id', '');
    status = DataHelper.getStringSafely(json, 'status', '');
    createdAt = DataHelper.getStringSafely(json, 'created_at', '');
  }
}

class EmailBatchSendResult {
  String message = '';
  String emailBatchId = '';
  String status = '';
  int sentCount = 0;
  int failedCount = 0;

  EmailBatchSendResult();

  EmailBatchSendResult.fromJson(Map<dynamic, dynamic> json) {
    message = DataHelper.getStringSafely(json, 'message', '');
    emailBatchId = DataHelper.getStringSafely(json, 'email_batch_id', '');
    status = DataHelper.getStringSafely(json, 'status', '');
    sentCount = DataHelper.getIntSafely(json, 'sent_count', 0);
    failedCount = DataHelper.getIntSafely(json, 'failed_count', 0);
  }
}

class WorkOrderEmailHistoryItem {
  String emailBatchId = '';
  String subject = '';
  List<String> toEmails = [];
  String batchStatus = '';
  String provider = '';
  String providerMessageId = '';
  String status = '';
  String error = '';
  String sentAt = '';
  String mergedPdfUrl = '';
  String linkedAt = '';

  WorkOrderEmailHistoryItem();

  WorkOrderEmailHistoryItem.fromJson(Map<dynamic, dynamic> json) {
    emailBatchId = DataHelper.getStringSafely(json, 'email_batch_id', '');
    subject = DataHelper.getStringSafely(json, 'subject', '');
    toEmails = DataHelper.getListOfStringSafely(json, 'to_emails');
    batchStatus = DataHelper.getStringSafely(json, 'batch_status', '');
    provider = DataHelper.getStringSafely(json, 'provider', '');
    providerMessageId = DataHelper.getStringSafely(
      json,
      'provider_message_id',
      '',
    );
    status = DataHelper.getStringSafely(json, 'status', '');
    error = DataHelper.getStringSafely(json, 'error', '');
    sentAt = DataHelper.getStringSafely(json, 'sent_at', '');
    mergedPdfUrl = DataHelper.getStringSafely(json, 'merged_pdf_url', '');
    linkedAt = DataHelper.getStringSafely(json, 'linked_at', '');
  }
}

class WorkOrderEmailHistoryResult {
  List<WorkOrderEmailHistoryItem> items = [];

  WorkOrderEmailHistoryResult();

  WorkOrderEmailHistoryResult.fromJson(Map<dynamic, dynamic> json) {
    items = DataHelper.getListOfMapSafely(json, 'items')
        .map((item) => WorkOrderEmailHistoryItem.fromJson(item))
        .toList();
  }
}
