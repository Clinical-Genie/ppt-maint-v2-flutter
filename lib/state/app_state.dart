import 'package:maintapp/model/user_info.dart';

//A class to store all configs loaded during login
class AppConfig {
  static AppConfig instance = AppConfig(); //the single instance

  int apiTimeoutLimit = 30;
}

class InstitutionOption {
  final String code;
  final String name;

  const InstitutionOption({required this.code, required this.name});

  factory InstitutionOption.fromJson(Map<dynamic, dynamic> json) {
    String readString(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value == null) continue;
        final text = '$value'.trim();
        if (text.isNotEmpty) return text;
      }
      return '';
    }

    return InstitutionOption(
      code: readString(['code', 'institution_code', 'institutionCode', 'id']),
      name: readString(['name', 'institution_name', 'institutionName']),
    );
  }

  String get displayLabel => name.isEmpty ? code : '$code - $name';
}

//A class to store the app's current state
class AppState {
  static AppState instance = AppState(); //the single instance

  List<InstitutionOption> institutions = [];
  List<UserInfo> activeEngineers = [];
  List<UserInfo> allUsers = [];

  void setInstitutions(List<InstitutionOption> values) {
    institutions = List<InstitutionOption>.from(values);
  }

  void setUsers({
    required List<UserInfo> activeEngineers,
    required List<UserInfo> allUsers,
  }) {
    this.activeEngineers = List<UserInfo>.from(activeEngineers);
    this.allUsers = List<UserInfo>.from(allUsers);
  }

  void resetState() {
    institutions = [];
    activeEngineers = [];
    allUsers = [];
  }
}
