// import 'package:flutter/foundation.dart' show kIsWeb;
// import 'dart:io';
import 'package:connection_network_type/connection_network_type.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'platform_helper.dart';
import 'device_id.dart';
import 'version_helper.dart';

//Implement the logic of handling device registration here
class DeviceInfoController {
  static DeviceInfoController instance =
      DeviceInfoController(); //the single instance

  bool isSetupCompleted = false;

  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  IosDeviceInfo? iosInfo;
  AndroidDeviceInfo? androidInfo;
  WebBrowserInfo? webInfo;
  LinuxDeviceInfo? linuxInfo;
  MacOsDeviceInfo? macOSInfo;
  WindowsDeviceInfo? windowsInfo;
  late final ConnectionNetworkType _connectionNetworkTypePlugin;
  NetworkStatus networkStatus = NetworkStatus.unreachable;

  String deviceID = "";

  Future<bool> init() async {
    if (isSetupCompleted) {
      return true;
    }
    deviceID = await DeviceId.getDeviceId();

    switch (PlatformHelper.instance.currentPlatform) {
      case PlatformName.iOS:
        return await _initIOS();
      case PlatformName.android:
        return await _initAndroid();
      case PlatformName.web:
        return await _initWeb();
      case PlatformName.linux:
        return await _initLinux();
      case PlatformName.macOS:
        return await _initMacOS();
      case PlatformName.windows:
        return await _initWindows();
      default:
        return false;
    }
  }

  Future<void> setupNetworkInfo() async {
    if (PlatformHelper.instance.currentPlatform == PlatformName.android) {
      // Request phone permission for Android to access network state
      await Permission.phone.request();
    }

    networkStatus = await _connectionNetworkTypePlugin.currentNetworkStatus();

    //Setup listener for network status change
    _connectionNetworkTypePlugin.onNetworkStateChanged.listen((
      NetworkStatus newStatus,
    ) {
      if (newStatus.name != networkStatus.name) {
        networkStatus = newStatus;
      }
    });
  }

  Future<bool> _initWindows() async {
    windowsInfo = await deviceInfo.windowsInfo;
    _connectionNetworkTypePlugin = ConnectionNetworkType();
    await setupNetworkInfo();
    isSetupCompleted = windowsInfo != null;
    return isSetupCompleted;
  }

  Future<bool> _initLinux() async {
    linuxInfo = await deviceInfo.linuxInfo;
    _connectionNetworkTypePlugin = ConnectionNetworkType();
    await setupNetworkInfo();
    isSetupCompleted = linuxInfo != null;
    return isSetupCompleted;
  }

  Future<bool> _initMacOS() async {
    macOSInfo = await deviceInfo.macOsInfo;
    _connectionNetworkTypePlugin = ConnectionNetworkType();
    await setupNetworkInfo();
    isSetupCompleted = macOSInfo != null;
    return isSetupCompleted;
  }

  Future<bool> _initIOS() async {
    iosInfo = await deviceInfo.iosInfo;
    _connectionNetworkTypePlugin = ConnectionNetworkType();
    await setupNetworkInfo();
    isSetupCompleted = iosInfo != null;
    return isSetupCompleted;
  }

  Future<bool> _initWeb() async {
    webInfo = await deviceInfo.webBrowserInfo;
    isSetupCompleted = webInfo != null;
    return isSetupCompleted;
  }

  Future<bool> _initAndroid() async {
    androidInfo = await deviceInfo.androidInfo;
    _connectionNetworkTypePlugin = ConnectionNetworkType();
    await setupNetworkInfo();
    isSetupCompleted = androidInfo != null;
    return isSetupCompleted;
  }

  String getDeviceId() {
    // return "#${deviceID.substring(1)}";
    return deviceID;
  }

  String getAppVersion() {
    return "${VersionHelper.appVersion()}_build${VersionHelper.appBuildNumber()}";
  }

  String getOSVersion() {
    switch (PlatformHelper.instance.currentPlatform) {
      case PlatformName.iOS:
        return iosInfo!.systemVersion;
      case PlatformName.android:
        return androidInfo!.version.release;
      case PlatformName.web:
        return webInfo!.appVersion ?? "Unknown";
      case PlatformName.linux:
        return linuxInfo!.version ?? "Unknown";
      case PlatformName.macOS:
        return macOSInfo!.osRelease;
      case PlatformName.windows:
        return "${windowsInfo!.displayVersion} build${windowsInfo!.buildNumber}";
      default:
        return '';
    }
  }

  bool isSimulator() {
    if (PlatformHelper.instance.currentPlatform == PlatformName.iOS) {
      return iosInfo!.isPhysicalDevice == false;
    } else if (PlatformHelper.instance.currentPlatform ==
        PlatformName.android) {
      return androidInfo!.isPhysicalDevice == false;
    }
    return false; // For other platforms, we assume it's not a simulator
  }

  String getPlatform() {
    return PlatformHelper.instance.currentPlatform;
  }

  String getManufacturer() {
    switch (PlatformHelper.instance.currentPlatform) {
      case PlatformName.iOS:
        return "Apple";
      case PlatformName.android:
        return androidInfo!.manufacturer;
      case PlatformName.web:
        return "Web";
      case PlatformName.linux:
        return linuxInfo!.prettyName;
      case PlatformName.macOS:
        return "Apple";
      case PlatformName.windows:
        return windowsInfo!.computerName;
      default:
        return '';
    }
  }

  String getModel() {
    switch (PlatformHelper.instance.currentPlatform) {
      case PlatformName.iOS:
        return iosInfo!.modelName;
      case PlatformName.android:
        return androidInfo!.model;
      case PlatformName.web:
        return "Web";
      case PlatformName.linux:
        return linuxInfo!.id;
      case PlatformName.macOS:
        return macOSInfo!.model;
      case PlatformName.windows:
        return windowsInfo!.productName;
      default:
        return '';
    }
  }

  String getNetworkType() {
    if (PlatformHelper.instance.currentPlatform == PlatformName.web) {
      return "Web";
    } else {
      return networkStatus.name;
    }
  }
}
