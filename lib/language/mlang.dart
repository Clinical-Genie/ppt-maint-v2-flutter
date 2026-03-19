import 'dart:convert';
import 'dart:developer';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:maintapp/common/secure_storage.dart';

class MLang {
  static init(Function refreshScreenCallback) async {
    await MultiLanguageController.instance.loadAllDefaultLibraies();
    await MultiLanguageController.instance.setInitLanguage(() {
      refreshScreenCallback();
    });
  }

  static String text(String key, String defaultValue) {
    return MultiLanguageController.instance.getText(key, defaultValue);
  }

  static void addSupportedLangauge(String lang) {
    MultiLanguageController.instance.addSupportedLangauge(lang);
  }

  static String get currentLangCode {
    return MultiLanguageController.instance.currentLangCode;
  }
}

class MultiLanguageController {
  static MultiLanguageController instance = MultiLanguageController();
  static const secureStorageName = "language";
  static const logModuleName = "MultiLanguage";

  Map<String, Map<String, dynamic>> library = {};
  Map<String, Map<String, dynamic>> defaultLibrary = {};
  String currentLangCode = "en-us";

  String getCurrentLangDesc() {
    return getLangDesc(currentLangCode);
  }

  List<String> supportedLangauges = [];

  void addSupportedLangauge(String lang) {
    if (!supportedLangauges.contains(lang)) {
      supportedLangauges.add(lang);
    }
  }

  String getSupportedLangaugeAfterChecking(String lang) {
    if (supportedLangauges.contains(lang)) {
      return lang;
    } else {
      return "en-us";
    }
  }

  //Reference: https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPInternational/LanguageandLocaleIDs/LanguageandLocaleIDs.html
  //Reference: https://www.loc.gov/standards/iso639-2/php/English_list.php
  String platformLanguageToLangCode(String platformLang) {
    String lang = platformLang.substring(0, 2).toLowerCase();

    switch (lang) {
      case "en":
        return getSupportedLangaugeAfterChecking("en-us");
      case "ja":
        return getSupportedLangaugeAfterChecking("ja-jp");
      case "ko":
        return getSupportedLangaugeAfterChecking("ko-kr");
      case "zh":
        if (platformLang.contains("Hant")) {
          return getSupportedLangaugeAfterChecking("zh-hk");
        } else if (platformLang.contains("Hans")) {
          return getSupportedLangaugeAfterChecking("zh-cn");
        } else {
          return getSupportedLangaugeAfterChecking("zh-hk");
        }
      case "vi":
        return getSupportedLangaugeAfterChecking("vi-vn");
      default:
        return getSupportedLangaugeAfterChecking("en-us");
    }
  }

  String getLangDesc(String langCode) {
    switch (langCode) {
      case "en-us":
        return "English";
      case "zh-hk":
        return "繁體中文";
      case "zh-cn":
        return "简体中文";
      case "ja-jp":
        return "日本語";
      case "ko-kr":
        return "한국어";
      case "vi-vn":
        return "Tiếng Việt";
      default:
        return langCode;
    }
  }

  bool initLanguageIsSet = false;

  Future<void> setInitLanguage(Function refreshScreenCallBack) async {
    if (!initLanguageIsSet) {
      if (!(await SecureStorage.instance.loadDataFromSecureStorage(
        secureStorageName,
      ))) {
        //get system langauge
        String platformLanguage = PlatformDispatcher.instance.locale
            .toLanguageTag();
        log("Use platform language: $platformLanguage");
        String platformLangCode = platformLanguageToLangCode(platformLanguage);
        // changeLanguageWithDefault(platformLangCode, refreshScreenCallBack);
        changeLangaage(platformLangCode, refreshScreenCallBack);
      } else {
        String langCodeLoaded = SecureStorage.instance.getData(
          secureStorageName,
          secureStorageName,
          currentLangCode,
        );
        log("Language is saved in secure storage before: $langCodeLoaded");
        // changeLanguageWithDefault(langCodeLoaded, refreshScreenCallBack);
        changeLangaage(langCodeLoaded, refreshScreenCallBack);
      }
      initLanguageIsSet = true;
    }
  }

  // Future<bool> changeLanguage(
  //   String langCode,
  //   Function refreshScreenCallBack,
  // ) async {
  //   if (LoginSessionController.instance.isLoggedIn()) {
  //     log("change language to: $langCode");
  //     if (!library.containsKey(langCode)) {
  //       // await ApiController.collectMultiLanguageLibrary(
  //       //   langCode,
  //       // ); //try load the language library server

  //       //log("langCode not found.");
  //       //return false;
  //     }

  //     log("update current lang code to $langCode");
  //     currentLangCode = langCode;

  //     //Save the selected language
  //     SecureStorage.instance.setData(
  //       secureStorageName,
  //       secureStorageName,
  //       currentLangCode,
  //     );
  //     SecureStorage.instance.saveDataToSecureStorage(secureStorageName);
  //     log("after save secure lang to secure storage");

  //     refreshScreenCallBack();
  //     return true;
  //   } else {
  //     return changeLanguageWithDefault(langCode, refreshScreenCallBack);
  //   }
  // }

  // Future<bool> changeLanguageWithDefault(
  Future<bool> changeLangaage(
    String langCode,
    Function refreshScreenCallBack,
  ) async {
    log("change language to: $langCode with default");
    currentLangCode = langCode;

    //Save the selected language
    SecureStorage.instance.setData(
      secureStorageName,
      secureStorageName,
      currentLangCode,
    );
    SecureStorage.instance.saveDataToSecureStorage(secureStorageName);
    log("after save secure lang to secure storage");

    refreshScreenCallBack();
    return true;
  }

  bool isLanguageReady(String langCode) {
    return library.containsKey(langCode);
  }

  // String getText(String key, String defaultValue) {
  //   try {
  //     if (library.containsKey(currentLangCode)) {
  //       if (library[currentLangCode]!.containsKey(key)) {
  //         return library[currentLangCode]![key] ?? defaultValue;
  //       } else {
  //         // log("key $key not fonnd");
  //         return getTextWithDefault(key, defaultValue);
  //       }
  //     } else {
  //       // log("langCode $currentLangCode of library not found");
  //       return getTextWithDefault(key, defaultValue);
  //     }
  //   } catch (e) {
  //     log("cannot get text $key, throw exception $e");
  //     return getTextWithDefault(key, defaultValue);
  //   }
  // }

  // String getTextWithDefault(String key, String defaultValue) {
  String getText(String key, String defaultValue) {
    // log("use default library: $currentLangCode");
    try {
      if (defaultLibrary.containsKey(currentLangCode)) {
        if (defaultLibrary[currentLangCode]!.containsKey(key)) {
          return defaultLibrary[currentLangCode]![key] ?? defaultValue;
        } else {
          log(
            "default key $key not found, return default value: $defaultValue",
          );
          return defaultValue;
        }
      } else {
        log(
          "langCode $currentLangCode for $key not found, return default value: $defaultValue",
        );
        return defaultValue;
      }
    } catch (e) {
      log(
        "cannot get default text $key, throw exception $e, return default value: $defaultValue",
      );
      return defaultValue;
    }
  }

  bool libraryIsLoaded = false;
  Future<void> loadAllDefaultLibraies() async {
    if (!libraryIsLoaded) {
      await loadDefaultLibrary("en-us");
      await loadDefaultLibrary("zh-hk");
      // await loadDefaultLibrary("zh-cn");
      // await loadDefaultLibrary("ja-jp");
      // await loadDefaultLibrary("ko-kr");
      // await loadDefaultLibrary("vi-vn");
      libraryIsLoaded = true;
    }
  }

  Future<void> loadDefaultLibrary(String langCode) async {
    String path = "assets/language/$langCode.json";
    String result = await rootBundle.loadString(path);
    Map<String, dynamic> valueMap = json.decode(result);
    defaultLibrary[langCode] = valueMap;
  }
}
