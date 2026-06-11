import 'dart:convert';
import 'dart:developer';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:maintapp/common/platform_helper.dart';

class SecureStorage {
  static SecureStorage instance = SecureStorage();
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  Map<String, Map<String, dynamic>> data = {};

  Future<void> saveDataToSecureStorage(String group) async {
    if (!PlatformHelper.instance.supportSecureStorage()) {
      return;
    }
    if (data.containsKey(group)) {
      String dataStr = json.encode(data[group]!);
      await _storage.write(key: group, value: dataStr);
    }
  }

  Future<bool> loadDataFromSecureStorage(String group) async {
    if (!PlatformHelper.instance.supportSecureStorage()) {
      return false;
    }
    String dataStr = await _storage.read(key: group) ?? "";

    try {
      if (dataStr.isNotEmpty) {
        Map<String, dynamic> dataLoaded = json.decode(dataStr);
        data[group] = dataLoaded;
        return true;
      } else {
        return false;
      }
    } catch (e) {
      log("Failed to load secure storage group $group: $e");
      return false;
    }
  }

  void saveAllDataToSecureStorage() async {
    for (String group in data.keys) {
      String dataStr = json.encode(data[group]!);
      await _storage.write(key: group, value: dataStr);
    }
  }

  //============================================================
  void replaceCategoryWithDataSet(
    String group,
    Map<String, String> newDataSet,
  ) {
    data[group] = newDataSet;
  }

  void setData(String group, String key, String value) {
    if (!data.containsKey(group)) {
      data[group] = {};
    }
    data[group]![key] = value;

    // log("SecureStorage after setData to [$group]: ${json.encode(data[group]!)}");
  }

  void removeData(String group, String key) {
    if (!data.containsKey(group)) {
      return;
    }
    data[group]!.remove(key);
  }

  String getData(String group, String key, String defaultValue) {
    if (!data.containsKey(group)) {
      return defaultValue;
    }
    return data[group]![key] ?? defaultValue;
  }
}
