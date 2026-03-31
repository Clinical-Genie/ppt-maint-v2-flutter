import 'package:maintapp/common/data_helper.dart';

class FormTemplateChoiceGroupSummary {
  String id = '';
  String code = '';
  String name = '';
  String description = '';
  bool isActive = false;
  String createdAt = '';
  String updatedAt = '';
  int itemCount = 0;

  FormTemplateChoiceGroupSummary();

  FormTemplateChoiceGroupSummary.fromJson(Map<dynamic, dynamic> json) {
    id = DataHelper.getStringSafely(json, 'id', '');
    code = DataHelper.getStringSafely(json, 'code', '');
    name = DataHelper.getStringSafely(json, 'name', '');
    description = DataHelper.getStringSafely(json, 'description', '');
    isActive = DataHelper.getBoolSafely(json, 'is_active', false);
    createdAt = DataHelper.getStringSafely(json, 'created_at', '');
    updatedAt = DataHelper.getStringSafely(json, 'updated_at', '');
    itemCount = DataHelper.getIntSafely(json, 'item_count', 0);
  }
}

class FormTemplateChoiceGroupList {
  List<FormTemplateChoiceGroupSummary> items = [];

  FormTemplateChoiceGroupList();

  FormTemplateChoiceGroupList.fromJson(Map<dynamic, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is List) {
      items = rawItems
          .whereType<Map>()
          .map(
            (item) =>
                FormTemplateChoiceGroupSummary.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    }
  }
}

class FormTemplateChoiceItem {
  String id = '';
  String code = '';
  String labelEn = '';
  String labelZh = '';
  int sort = 0;
  bool isActive = false;
  Map<String, dynamic> metaJson = {};
  String createdAt = '';
  String updatedAt = '';

  FormTemplateChoiceItem();

  FormTemplateChoiceItem.fromJson(Map<dynamic, dynamic> json) {
    id = DataHelper.getStringSafely(json, 'id', '');
    code = DataHelper.getStringSafely(json, 'code', '');
    labelEn = DataHelper.getStringSafely(json, 'label_en', '');
    labelZh = DataHelper.getStringSafely(json, 'label_zh', '');
    sort = DataHelper.getIntSafely(json, 'sort', 0);
    isActive = DataHelper.getBoolSafely(json, 'is_active', false);
    metaJson = DataHelper.getMapSafely(json, 'meta_json');
    createdAt = DataHelper.getStringSafely(json, 'created_at', '');
    updatedAt = DataHelper.getStringSafely(json, 'updated_at', '');
  }
}

class FormTemplateChoiceGroupRef {
  String id = '';
  String code = '';
  String name = '';
  String description = '';
  bool isActive = false;

  FormTemplateChoiceGroupRef();

  FormTemplateChoiceGroupRef.fromJson(Map<dynamic, dynamic> json) {
    id = DataHelper.getStringSafely(json, 'id', '');
    code = DataHelper.getStringSafely(json, 'code', '');
    name = DataHelper.getStringSafely(json, 'name', '');
    description = DataHelper.getStringSafely(json, 'description', '');
    isActive = DataHelper.getBoolSafely(json, 'is_active', false);
  }
}

class FormTemplateFieldOption {
  String value = '';
  String code = '';
  String label = '';
  String labelEn = '';
  String labelZh = '';
  bool active = false;
  int sort = 0;
  Map<String, dynamic> metaJson = {};

  FormTemplateFieldOption();

  FormTemplateFieldOption.fromJson(Map<dynamic, dynamic> json) {
    value = DataHelper.getStringSafely(json, 'value', '');
    code = DataHelper.getStringSafely(json, 'code', '');
    label = DataHelper.getStringSafely(json, 'label', '');
    labelEn = DataHelper.getStringSafely(json, 'label_en', '');
    labelZh = DataHelper.getStringSafely(json, 'label_zh', '');
    active = DataHelper.getBoolSafely(json, 'active', false);
    sort = DataHelper.getIntSafely(json, 'sort', 0);
    metaJson = DataHelper.getMapSafely(json, 'meta_json');
  }
}

class FormTemplateField {
  String key = '';
  String label = '';
  String type = '';
  bool required = false;
  String captureStage = '';
  String choiceGroupCode = '';
  FormTemplateChoiceGroupRef? choiceGroup;
  List<FormTemplateFieldOption> options = [];
  Map<String, dynamic> raw = {};

  FormTemplateField();

  FormTemplateField.fromJson(Map<dynamic, dynamic> json) {
    raw = Map<String, dynamic>.from(json);
    key = DataHelper.getStringSafely(json, 'key', '');
    label = DataHelper.getStringSafely(json, 'label', '');
    type = DataHelper.getStringSafely(json, 'type', '');
    required = DataHelper.getBoolSafely(json, 'required', false);
    captureStage = DataHelper.getStringSafely(json, 'capture_stage', '');
    choiceGroupCode = DataHelper.getStringSafely(json, 'choice_group_code', '');
    if (json['choice_group'] is Map) {
      choiceGroup = FormTemplateChoiceGroupRef.fromJson(
        Map<String, dynamic>.from(json['choice_group']),
      );
    }
    final rawOptions = json['options'];
    if (rawOptions is List) {
      options = rawOptions
          .whereType<Map>()
          .map((item) => FormTemplateFieldOption.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
  }

  bool get isSignStage => captureStage.trim().toLowerCase() == 'sign';

  bool get isFillStage => !isSignStage;
}

class FormTemplateChoiceGroupDetail {
  String id = '';
  String code = '';
  String name = '';
  String description = '';
  bool isActive = false;
  String createdAt = '';
  String updatedAt = '';
  List<FormTemplateChoiceItem> items = [];

  FormTemplateChoiceGroupDetail();

  FormTemplateChoiceGroupDetail.fromJson(Map<dynamic, dynamic> json) {
    id = DataHelper.getStringSafely(json, 'id', '');
    code = DataHelper.getStringSafely(json, 'code', '');
    name = DataHelper.getStringSafely(json, 'name', '');
    description = DataHelper.getStringSafely(json, 'description', '');
    isActive = DataHelper.getBoolSafely(json, 'is_active', false);
    createdAt = DataHelper.getStringSafely(json, 'created_at', '');
    updatedAt = DataHelper.getStringSafely(json, 'updated_at', '');
    final rawItems = json['items'];
    if (rawItems is List) {
      items = rawItems
          .whereType<Map>()
          .map((item) => FormTemplateChoiceItem.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
  }
}
