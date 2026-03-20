import 'package:maintapp/common/data_helper.dart';

class WorkOrder {
  String id = '';
  String message = '';
  String woNo = '';
  String woType = ''; //CM or PM
  String status =
      ''; // pending, in_progress, completed, etc. updated by backend based on workflow
  bool isTransferring = false;

  String contactName = '';
  String contactNumber = '';
  String locationCode = '';
  String institutionCode = '';

  String assetNumber = '';
  String serialNumber = '';
  String deviceBrand = '';
  String deviceModel = '';
  String remark = '';
  String description = '';

  String haCreatedAt = '';
  String haOutboundAt = '';
  String cmBreakdownAt = '';
  String pmDeadlineAt = '';
  String priority = ''; //normal or high, updated by user in this app

  String plannedDate = '';
  String dueDate = '';
  String plannedHalfDay = ''; //AM or PM if only for half day

  String ownerUserId = '';
  String ownerFullName = '';

  String sourceFileId = '';
  String sourceFileName = '';
  String sourceFileUrl = '';
  String ocrJobId = '';

  String approvedAt = '';
  String emailSentAt = '';
  String mergedPdfUrl = '';
  String createdBy = '';
  String createdAt = '';
  String updatedAt = '';

  Map<String, dynamic> raw = {};

  WorkOrder();

  WorkOrder.fromJson(Map<dynamic, dynamic> json) {
    raw = Map<String, dynamic>.from(json);

    id = DataHelper.getStringSafely(json, 'id', '');
    message = DataHelper.getStringSafely(json, 'message', '');
    woNo = DataHelper.getStringSafely(json, 'wo_no', '');
    woType = DataHelper.getStringSafely(json, 'wo_type', '');
    status = DataHelper.getStringSafely(json, 'status', '');
    isTransferring = DataHelper.getBoolSafely(json, 'is_transferring', false);

    locationCode = DataHelper.getStringSafely(
      json,
      'location_code',
      DataHelper.getStringSafely(json, 'location', ''),
    );
    institutionCode = DataHelper.getStringSafely(json, 'institution_code', '');

    assetNumber = DataHelper.getStringSafely(json, 'asset_number', '');
    serialNumber = DataHelper.getStringSafely(json, 'serial_number', '');
    deviceBrand = DataHelper.getStringSafely(json, 'device_brand', '');
    deviceModel = DataHelper.getStringSafely(json, 'device_model', '');
    contactName = DataHelper.getStringSafely(json, 'contact_name', '');
    contactNumber = DataHelper.getStringSafely(json, 'contact_number', '');

    haCreatedAt = DataHelper.getStringSafely(json, 'ha_created_at', '');
    haOutboundAt = DataHelper.getStringSafely(json, 'ha_outbound_at', '');
    cmBreakdownAt = DataHelper.getStringSafely(json, 'cm_breakdown_at', '');
    pmDeadlineAt = DataHelper.getStringSafely(json, 'pm_deadline_at', '');
    priority = DataHelper.getStringSafely(json, 'priority', '');

    plannedDate = DataHelper.getStringSafely(json, 'planned_date', '');
    dueDate = DataHelper.getStringSafely(json, 'due_date', '');
    plannedHalfDay = DataHelper.getStringSafely(json, 'planned_half_day', '');
    remark = DataHelper.getStringSafely(json, 'remark', '');
    description = DataHelper.getStringSafely(json, 'description', '');

    ownerUserId = DataHelper.getStringSafely(json, 'owner_user_id', '');
    ownerFullName = DataHelper.getStringSafely(json, 'owner_full_name', '');

    sourceFileId = DataHelper.getStringSafely(json, 'source_file_id', '');
    sourceFileName = DataHelper.getStringSafely(json, 'source_file_name', '');
    sourceFileUrl = DataHelper.getStringSafely(json, 'source_file_url', '');
    ocrJobId = DataHelper.getStringSafely(json, 'ocr_job_id', '');

    approvedAt = DataHelper.getStringSafely(json, 'approved_at', '');
    emailSentAt = DataHelper.getStringSafely(json, 'email_sent_at', '');
    mergedPdfUrl = DataHelper.getStringSafely(json, 'merged_pdf_url', '');
    createdBy = DataHelper.getStringSafely(json, 'created_by', '');
    createdAt = DataHelper.getStringSafely(json, 'created_at', '');
    updatedAt = DataHelper.getStringSafely(json, 'updated_at', '');
  }

  Map<String, dynamic> toCreatePayload() {
    return {
      if (woNo.isNotEmpty) 'wo_no': woNo,
      if (woType.isNotEmpty) 'wo_type': woType,
      if (woType.isNotEmpty) 'woType': woType,
      if (status.isNotEmpty) 'status': status,
      'is_transferring': isTransferring,
      if (locationCode.isNotEmpty) 'location_code': locationCode,
      if (institutionCode.isNotEmpty) 'institution_code': institutionCode,
      if (institutionCode.isNotEmpty) 'institutionCode': institutionCode,
      if (assetNumber.isNotEmpty) 'asset_number': assetNumber,
      if (assetNumber.isNotEmpty) 'assetNumber': assetNumber,
      if (serialNumber.isNotEmpty) 'serial_number': serialNumber,
      if (serialNumber.isNotEmpty) 'serialNumber': serialNumber,
      if (deviceBrand.isNotEmpty) 'device_brand': deviceBrand,
      if (deviceModel.isNotEmpty) 'device_model': deviceModel,
      if (contactName.isNotEmpty) 'contact_name': contactName,
      if (contactNumber.isNotEmpty) 'contact_number': contactNumber,
      if (haCreatedAt.isNotEmpty) 'ha_created_at': haCreatedAt,
      if (haOutboundAt.isNotEmpty) 'ha_outbound_at': haOutboundAt,
      if (cmBreakdownAt.isNotEmpty) 'cm_breakdown_at': cmBreakdownAt,
      if (pmDeadlineAt.isNotEmpty) 'pm_deadline_at': pmDeadlineAt,
      if (priority.isNotEmpty) 'priority': priority,
      if (plannedDate.isNotEmpty) 'planned_date': plannedDate,
      if (dueDate.isNotEmpty) 'due_date': dueDate,
      if (plannedHalfDay.isNotEmpty) 'planned_half_day': plannedHalfDay,
      if (remark.isNotEmpty) 'remark': remark,
      if (description.isNotEmpty) 'description': description,
      if (ownerUserId.isNotEmpty) 'owner_user_id': ownerUserId,
      if (sourceFileId.isNotEmpty) 'source_file_id': sourceFileId,
      if (ocrJobId.isNotEmpty) 'ocr_job_id': ocrJobId,
      if (sourceFileName.isNotEmpty) 'source_file_name': sourceFileName,
      if (sourceFileUrl.isNotEmpty) 'source_file_url': sourceFileUrl,
    };
  }

  Map<String, dynamic> toJson() {
    final data = Map<String, dynamic>.from(raw);
    data['id'] = id;
    data['message'] = message;
    data['wo_no'] = woNo;
    data['wo_type'] = woType;
    data['status'] = status;
    data['is_transferring'] = isTransferring;
    data['location_code'] = locationCode;
    data['institution_code'] = institutionCode;
    data['asset_number'] = assetNumber;
    data['serial_number'] = serialNumber;
    data['device_brand'] = deviceBrand;
    data['device_model'] = deviceModel;
    data['contact_name'] = contactName;
    data['contact_number'] = contactNumber;
    data['ha_created_at'] = haCreatedAt;
    data['ha_outbound_at'] = haOutboundAt;
    data['cm_breakdown_at'] = cmBreakdownAt;
    data['pm_deadline_at'] = pmDeadlineAt;
    data['priority'] = priority;
    data['planned_date'] = plannedDate;
    data['due_date'] = dueDate;
    data['planned_half_day'] = plannedHalfDay;
    data['remark'] = remark;
    data['description'] = description;
    data['owner_user_id'] = ownerUserId;
    data['owner_full_name'] = ownerFullName;
    data['source_file_id'] = sourceFileId;
    data['source_file_name'] = sourceFileName;
    data['source_file_url'] = sourceFileUrl;
    data['ocr_job_id'] = ocrJobId;
    data['approved_at'] = approvedAt;
    data['email_sent_at'] = emailSentAt;
    data['merged_pdf_url'] = mergedPdfUrl;
    data['created_by'] = createdBy;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    return data;
  }

  String get referenceNumber => woNo.isEmpty ? id : woNo;

  String get displayLabel {
    if (woNo.isNotEmpty) return woNo;
    if (woType.isNotEmpty) return 'Work order ($woType)';
    return 'Work order';
  }

  String get institutionCodeOrFromLocation {
    if (institutionCode.isNotEmpty) return institutionCode;
    final hasDash = locationCode.contains('-');
    return hasDash ? locationCode.split('-').first : '';
  }
}

class WorkOrderList {
  List<WorkOrder> items = [];
  int total = 0;
  int limit = 0;
  int offset = 0;
  int page = 0;
  int pageSize = 0;
  int count = 0;

  WorkOrderList({List<WorkOrder>? items, int? total, int? count}) {
    this.items = items ?? [];
    this.total = total ?? 0;
    this.count = count ?? this.items.length;
  }

  WorkOrderList.fromJson(Map<dynamic, dynamic> json) {
    final dynamic directItems =
        json['items'] ??
        json['rows'] ??
        json['work_orders'] ??
        json['workOrders'];
    items = _extractItems(directItems);
    if (items.isEmpty && json['data'] is Map) {
      final dynamic nested = json['data'];
      items = _extractItems(
        nested['items'] ??
            nested['rows'] ??
            nested['work_orders'] ??
            nested['workOrders'],
      );
    }

    total = DataHelper.getIntSafely(json, 'total', items.length);
    count = DataHelper.getIntSafely(json, 'count', items.length);
    limit = DataHelper.getIntSafely(json, 'limit', 0);
    offset = DataHelper.getIntSafely(json, 'offset', 0);
    page = DataHelper.getIntSafely(json, 'page', 0);
    pageSize = DataHelper.getIntSafely(json, 'pageSize', 0);

    if ((total == 0 || count == 0) && items.isNotEmpty) {
      total = items.length;
      count = items.length;
    }

    if ((total == 0 || total == 0) && json['data'] is Map) {
      total = DataHelper.getIntSafely(json['data'], 'total', items.length);
      count = DataHelper.getIntSafely(json['data'], 'count', count);
    }
  }

  List<WorkOrder> _extractItems(dynamic source) {
    if (source is List) {
      return source
          .whereType<Map<dynamic, dynamic>>()
          .map((item) => WorkOrder.fromJson(item))
          .toList();
    }
    return [];
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((item) => item.toJson()).toList(),
      'total': total,
      'count': count,
      'limit': limit,
      'offset': offset,
      'page': page,
      'pageSize': pageSize,
    };
  }
}

class WorkOrderOcrResult {
  bool ok = false;
  String sourceFileId = '';
  String sourceFileName = '';
  String sourceFileUrl = '';
  String ocrJobId = '';
  String extractionMode = '';
  String extractionLabel = '';
  WorkOrder workOrderDraft = WorkOrder();
  Map<String, dynamic> ocrFields = {};
  String message = '';
  String rawOcrText = '';
  String errorMessage = '';
  num confidence = 0;
  Map<String, dynamic> raw = {};

  WorkOrderOcrResult();

  WorkOrderOcrResult.fromJson(Map<dynamic, dynamic> json) {
    raw = Map<String, dynamic>.from(json);
    final dynamic okValue = json['ok'];
    ok = okValue is bool
        ? okValue
        : okValue is String
        ? okValue.toLowerCase() == 'true'
        : true;
    sourceFileId = DataHelper.getStringSafely(json, 'source_file_id', '');
    sourceFileName = DataHelper.getStringSafely(json, 'source_file_name', '');
    sourceFileUrl = DataHelper.getStringSafely(
      json,
      'source_file_url',
      '',
    );
    ocrJobId = DataHelper.getStringSafely(json, 'ocr_job_id', '');
    extractionMode = DataHelper.getStringSafely(
      json,
      'extraction_mode',
      DataHelper.getStringSafely(json, 'extract_mode', ''),
    );
    extractionLabel = DataHelper.getStringSafely(
      json,
      'extraction_label',
      DataHelper.getStringSafely(json, 'extract_label', ''),
    );
    message = DataHelper.getStringSafely(json, 'message', '');
    rawOcrText = DataHelper.getStringSafely(json, 'raw_text', '');

    if (json['work_order_draft'] is Map) {
      workOrderDraft = WorkOrder.fromJson(
        Map<String, dynamic>.from(json['work_order_draft']),
      );
    } else if (json['draft_data'] is Map) {
      workOrderDraft = WorkOrder.fromJson(
        Map<String, dynamic>.from(json['draft_data']),
      );
    } else if (json['data'] is Map &&
        DataHelper.getMapSafely(json['data'], 'work_order_draft').isNotEmpty) {
      workOrderDraft = WorkOrder.fromJson(
        DataHelper.getMapSafely(json['data'], 'work_order_draft'),
      );
    }

    ocrFields = DataHelper.getMapSafely(json, 'ocr_fields');
    errorMessage = DataHelper.getStringSafely(json, 'error', '');
    confidence = DataHelper.getNumSafely(json, 'confidence', 0);
  }

  Map<String, dynamic> toJson() {
    return {
      'ok': ok,
      'source_file_id': sourceFileId,
      'source_file_name': sourceFileName,
      'source_file_url': sourceFileUrl,
      'ocr_job_id': ocrJobId,
      'extraction_mode': extractionMode,
      'extraction_label': extractionLabel,
      'work_order_draft': workOrderDraft.toJson(),
      'ocr_fields': ocrFields,
      'confidence': confidence,
      'message': message,
      'raw_text': rawOcrText,
      'error': errorMessage,
    };
  }
}
