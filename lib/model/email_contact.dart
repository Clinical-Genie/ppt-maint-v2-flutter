import 'package:maintapp/common/data_helper.dart';

class EmailContact {
  String id = '';
  String name = '';
  String email = '';
  String notes = '';
  bool isActive = true;
  String createdBy = '';
  String createdAt = '';
  String updatedAt = '';

  EmailContact();

  EmailContact.fromJson(Map<dynamic, dynamic> json) {
    id = DataHelper.getStringSafely(json, 'id', '');
    name = DataHelper.getStringSafely(json, 'name', '');
    email = DataHelper.getStringSafely(json, 'email', '');
    notes = DataHelper.getStringSafely(json, 'notes', '');
    isActive = DataHelper.getBoolSafely(json, 'is_active', true);
    createdBy = DataHelper.getStringSafely(json, 'created_by', '');
    createdAt = DataHelper.getStringSafely(json, 'created_at', '');
    updatedAt = DataHelper.getStringSafely(json, 'updated_at', '');
  }
}

class EmailContactList {
  List<EmailContact> items = [];
  int total = 0;
  int limit = 0;
  int offset = 0;

  EmailContactList();

  EmailContactList.fromJson(Map<dynamic, dynamic> json) {
    items = DataHelper.getListOfMapSafely(
      json,
      'items',
    ).map(EmailContact.fromJson).toList();
    total = DataHelper.getIntSafely(json, 'total', items.length);
    limit = DataHelper.getIntSafely(json, 'limit', 0);
    offset = DataHelper.getIntSafely(json, 'offset', 0);
  }
}
