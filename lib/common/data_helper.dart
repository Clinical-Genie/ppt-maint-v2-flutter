class DataHelper {
  static String getStringSafely(
    Map<dynamic, dynamic> json,
    String key,
    String defaultValue,
  ) {
    // return json[key] ?? defaultValue;
    return json.containsKey(key) ? (json[key] ?? defaultValue) : defaultValue;
  }

  static int getIntSafely(
    Map<dynamic, dynamic> json,
    String key,
    int defaultValue,
  ) {
    return json.containsKey(key) ? (json[key] ?? defaultValue) : defaultValue;
  }

  static num getNumSafely(
    Map<dynamic, dynamic> json,
    String key,
    num defaultValue,
  ) {
    if (json.containsKey(key)) {
      if (json[key] is String) {
        return num.tryParse(json[key]) ?? defaultValue;
      } else {
        return json[key] ?? defaultValue;
      }
    } else {
      return defaultValue;
    }
    // return json.containsKey(key) ? (json[key] ?? defaultValue) : defaultValue;
  }

  static bool getBoolSafely(
    Map<dynamic, dynamic> json,
    String key,
    bool defaultValue,
  ) {
    return json.containsKey(key) ? (json[key] ?? defaultValue) : defaultValue;
  }

  static List<String> getListOfStringSafely(
    Map<dynamic, dynamic> json,
    String key,
  ) {
    if (json.containsKey(key) && json[key] is List) {
      return List<String>.from(json[key].whereType<String>());
    } else {
      return [];
    }
  }

  static Map<String, dynamic> getMapSafely(
    Map<dynamic, dynamic> json,
    String key,
  ) {
    if (json.containsKey(key) && json[key] is Map) {
      return Map<String, dynamic>.from(json[key]);
    } else {
      return {};
    }
  }

  static List<Map<String, dynamic>> getListOfMapSafely(
    Map<dynamic, dynamic> json,
    String key,
  ) {
    if (json.containsKey(key) && json[key] is List) {
      return List<Map<String, dynamic>>.from(
        json[key].whereType<Map<dynamic, dynamic>>().map((item) {
          return Map<String, dynamic>.from(item);
        }),
      );
    } else {
      return [];
    }
  }
}
