import 'package:maintapp/common/data_helper.dart';

class EmailTemplate {
  String id = '';
  String name = '';
  String subject = '';
  String bodyHtml = '';
  String bodyText = '';
  bool isActive = true;
  String createdBy = '';
  String createdAt = '';
  String updatedAt = '';

  EmailTemplate();

  EmailTemplate.fromJson(Map<dynamic, dynamic> json) {
    id = DataHelper.getStringSafely(json, 'id', '');
    name = DataHelper.getStringSafely(json, 'name', '');
    subject = DataHelper.getStringSafely(json, 'subject', '');
    bodyHtml = DataHelper.getStringSafely(json, 'body_html', '');
    bodyText = DataHelper.getStringSafely(json, 'body_text', '');
    isActive = DataHelper.getBoolSafely(json, 'is_active', true);
    createdBy = DataHelper.getStringSafely(json, 'created_by', '');
    createdAt = DataHelper.getStringSafely(json, 'created_at', '');
    updatedAt = DataHelper.getStringSafely(json, 'updated_at', '');
  }
}

class EmailTemplateList {
  List<EmailTemplate> items = [];

  EmailTemplateList();

  EmailTemplateList.fromJson(Map<dynamic, dynamic> json) {
    items = DataHelper.getListOfMapSafely(
      json,
      'items',
    ).map(EmailTemplate.fromJson).toList();
  }
}
