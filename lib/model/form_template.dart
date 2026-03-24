import 'package:maintapp/common/data_helper.dart';
import 'package:maintapp/model/form_template_choice_group.dart';

class FormTemplateList {
  List<FormTemplate> items = [];

  FormTemplateList();

  FormTemplateList.fromJson(Map<dynamic, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is List) {
      items = rawItems
          .whereType<Map>()
          .map((item) => FormTemplate.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
  }
}

class FormTemplate {
  String id = '';
  String code = '';
  String name = '';
  String woType = '';
  int version = 0;
  FormTemplateSchema schema = FormTemplateSchema();
  String uiTemplateHtml = '';
  bool isActive = false;
  String createdAt = '';
  Map<String, dynamic> raw = {};

  FormTemplate();

  FormTemplate.fromJson(Map<dynamic, dynamic> json) {
    raw = Map<String, dynamic>.from(json);
    id = DataHelper.getStringSafely(json, 'id', '');
    code = DataHelper.getStringSafely(json, 'code', '');
    name = DataHelper.getStringSafely(json, 'name', '');
    woType = DataHelper.getStringSafely(json, 'wo_type', '');
    version = DataHelper.getIntSafely(json, 'version', 0);
    uiTemplateHtml = DataHelper.getStringSafely(json, 'ui_template_html', '');
    isActive = DataHelper.getBoolSafely(json, 'is_active', false);
    createdAt = DataHelper.getStringSafely(json, 'created_at', '');
    if (json['schema_json'] is Map) {
      schema = FormTemplateSchema.fromJson(
        Map<String, dynamic>.from(json['schema_json']),
      );
    }
  }
}

class FormTemplateSchema {
  String templateKey = '';
  String templateName = '';
  String reportType = '';
  int version = 0;
  Map<String, dynamic> hardcoded = {};
  Map<String, dynamic> readonlyMappings = {};
  Map<String, dynamic> defaultDataJson = {};
  List<FormTemplateField> fields = [];

  FormTemplateSchema();

  FormTemplateSchema.fromJson(Map<dynamic, dynamic> json) {
    templateKey = DataHelper.getStringSafely(json, 'template_key', '');
    templateName = DataHelper.getStringSafely(json, 'template_name', '');
    reportType = DataHelper.getStringSafely(json, 'report_type', '');
    version = DataHelper.getIntSafely(json, 'version', 0);
    hardcoded = DataHelper.getMapSafely(json, 'hardcoded');
    readonlyMappings = DataHelper.getMapSafely(json, 'readonly_mappings');
    defaultDataJson = DataHelper.getMapSafely(json, 'default_data_json');
    final rawFields = json['fields'];
    if (rawFields is List) {
      fields = rawFields
          .whereType<Map>()
          .map((item) => FormTemplateField.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
  }
}
