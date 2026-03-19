import "package:maintapp/common/data_helper.dart";

class UserList {
  List<UserInfo> items = [];
  int total = 0;
  int limit = 0;
  int offset = 0;

  UserList({
    this.items = const [],
    this.total = 0,
    this.limit = 0,
    this.offset = 0,
  });

  UserList.fromJson(Map<String, dynamic> json) {
    items = DataHelper.getListOfMapSafely(
      json,
      'items',
    ).map((userJson) => UserInfo.fromJson(userJson)).toList();

    total = DataHelper.getIntSafely(json, 'total', 0);
    limit = DataHelper.getIntSafely(json, 'limit', 0);
    offset = DataHelper.getIntSafely(json, 'offset', 0);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['users'] = items.map((user) => user.toJson()).toList();
    data['total'] = total;
    data['limit'] = limit;
    data['offset'] = offset;
    return data;
  }
}

class UserInfo {
  String id = "";
  String username = "";
  String email = "";
  String phone = "";
  String fullName = "";
  String position = "";
  String department = "";
  String timezone = "";
  List<String> roles = [];
  Map<String, dynamic> profile = {};
  String signatureUrl = "";
  bool isActive = false;
  bool isEmailVerified = false;

  UserInfo({
    this.id = "",
    this.username = "",
    this.email = "",
    this.phone = "",
    this.fullName = "",
    this.position = "",
    this.department = "",
    this.timezone = "",
    this.roles = const [],
    this.profile = const {},
    this.signatureUrl = "",
    this.isActive = false,
    this.isEmailVerified = false,
  });

  UserInfo.fromJson(Map<dynamic, dynamic> json) {
    id = DataHelper.getStringSafely(json, 'id', '');
    username = DataHelper.getStringSafely(json, 'username', '');
    email = DataHelper.getStringSafely(json, 'email', '');
    phone = DataHelper.getStringSafely(json, 'phone', '');
    fullName = DataHelper.getStringSafely(json, 'full_name', '');
    position = DataHelper.getStringSafely(json, 'position', '');
    department = DataHelper.getStringSafely(json, 'department', '');
    timezone = DataHelper.getStringSafely(json, 'timezone', '');
    roles = DataHelper.getListOfStringSafely(json, 'roles');
    profile = DataHelper.getMapSafely(json, 'profile');
    signatureUrl = DataHelper.getStringSafely(json, 'signature_url', '');
    isActive = DataHelper.getBoolSafely(json, 'is_active', false);
    isEmailVerified = DataHelper.getBoolSafely(
      json,
      'is_email_verified',
      false,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['email'] = email;
    data['phone'] = phone;
    data['full_name'] = fullName;
    data['position'] = position;
    data['department'] = department;
    data['timezone'] = timezone;
    data['roles'] = roles;
    data['profile'] = profile;
    data['signature_url'] = signatureUrl;
    data['is_active'] = isActive;
    data['is_email_verified'] = isEmailVerified;
    return data;
  }
}

class RoleList {
  List<Role> items = [];

  RoleList({this.items = const []});

  RoleList.fromJson(List<dynamic> json) {
    items = json.map((roleJson) => Role.fromJson(roleJson)).toList();
  }

  List<dynamic> toJson() {
    return items.map((role) => role.toJson()).toList();
  }

  List<String> containsRoleCodes(List<String> roleCodes) {
    return items
        .where((role) => roleCodes.contains(role.code))
        .map((role) => role.code)
        .toList();
  }
}

class Role {
  String code = "";
  String name = "";

  Role({this.code = "", this.name = ""});

  Role.fromJson(Map<String, dynamic> json) {
    code = DataHelper.getStringSafely(json, 'code', '');
    name = DataHelper.getStringSafely(json, 'name', '');
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['code'] = code;
    data['name'] = name;
    return data;
  }
}
