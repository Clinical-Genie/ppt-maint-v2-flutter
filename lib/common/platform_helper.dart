import 'package:flutter/foundation.dart';
import 'package:web_browser_detect/web_browser_detect.dart';

class PlatformName {
  static const String iOS = "iOS";
  static const String android = "android";
  static const String macOS = "macOS";
  static const String windows = "windows";
  static const String linux = "linux";
  static const String web = "web";
  static const String others = "others";
}

class PlatformHelper {
  static PlatformHelper instance = PlatformHelper(); //the single instance

  Browser? b;
  String currentPlatform = "";

  // static void init() {
  //   instance = PlatformHelper();
  // }

  void setup() {
    if (kIsWeb) {
      b = Browser.detectOrNull();
      currentPlatform = PlatformName.web;
    } else {
      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
          currentPlatform = PlatformName.iOS;
          break;
        case TargetPlatform.android:
          currentPlatform = PlatformName.android;
          break;
        case TargetPlatform.macOS:
          currentPlatform = PlatformName.macOS;
          break;
        case TargetPlatform.linux:
          currentPlatform = PlatformName.linux;
          break;
        case TargetPlatform.windows:
          currentPlatform = PlatformName.windows;
          break;
        default:
          currentPlatform = PlatformName.others;
      }
    }
  }

  bool supportSettingBundle() {
    return currentPlatform == PlatformName.iOS ||
        currentPlatform == PlatformName.macOS;
  }

  bool supportLocalAssets() {
    return true;
  }

  bool supportSecureStorage() {
    return currentPlatform == PlatformName.iOS ||
        currentPlatform == PlatformName.macOS ||
        currentPlatform == PlatformName.android ||
        currentPlatform == PlatformName.windows ||
        currentPlatform == PlatformName.linux ||
        currentPlatform == PlatformName.web;
  }
}
