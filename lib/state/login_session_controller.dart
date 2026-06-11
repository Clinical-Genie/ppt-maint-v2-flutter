import 'dart:developer';
import 'package:maintapp/api/api_controller.dart';
import 'package:maintapp/common/secure_storage.dart';
import 'package:maintapp/model/login_info.dart';
import 'package:maintapp/model/user_info.dart';
import 'package:maintapp/state/app_state.dart';
import 'package:maintapp/services/mobile_app_lock_service.dart';

// import 'dart:developer';

class LoginSessionController {
  static final LoginSessionController instance =
      LoginSessionController(); //the single instance
  static const String _sessionStorageGroup = 'login_session';

  bool isRefreshingToken = false;
  String username = "";
  //static const String apiBaseUrl = "http://api.clinicalgenie.com/";
  LoginInfo loginInfo = LoginInfo();
  UserInfo userInfo = UserInfo();

  void debugCheckLoginInfo({String condition = "Check Login Info"}) {
    log("========== $condition ==========");
    log(
      'loggedIn=${isLoggedIn()}, tokenExpiry=${loginInfo.expiryDate}, '
      'username=$username, userId=${userInfo.id}',
    );
  }

  bool isLoggedIn() {
    return loginInfo.accessToken.isNotEmpty;
  }

  bool isExpired() {
    if (loginInfo.expiryDate == null) {
      return true;
    } else {
      return (loginInfo.expiryDate!.difference(DateTime.now()).inSeconds < 0);
    }
  }

  Future<void> loginByUsername(String username, String password) async {
    loginInfo = await ApiController.userLogin(username, password);
    if (isLoggedIn()) {
      await adoptAuthenticatedSession(loginInfo, username: username);
    }
  }

  Future<void> adoptAuthenticatedSession(
    LoginInfo authenticatedLoginInfo, {
    required String username,
  }) async {
    loginInfo = authenticatedLoginInfo;
    this.username = username;
    userInfo = await ApiController.getMyUserInfo();
    await _persistSession();
    await MobileAppLockService.instance.unlock();
  }

  Future<void> refreshTokenIfNeeded() async {
    if (isRefreshingToken) {
      return;
    }
    if (loginInfo.expiryDate != null) {
      final now = DateTime.now();
      final expireDT = loginInfo.expiryDate!;
      if (expireDT.difference(now).inSeconds < 10) {
        isRefreshingToken = true;
        try {
          final refreshedLoginInfo = await ApiController.userRefreshToken();
          if (refreshedLoginInfo.accessToken.isNotEmpty) {
            loginInfo = refreshedLoginInfo;
            await _persistSession();
          } else {
            //If refresh token failed, logout locally
            await logoutLocally(resetLoginInfo: true);
          }
        } finally {
          isRefreshingToken = false;
        }
      }
    }
  }

  Future<bool> loadSessionFromStorage({bool fetchUserInfo = true}) async {
    final loaded = await SecureStorage.instance.loadDataFromSecureStorage(
      _sessionStorageGroup,
    );
    if (!loaded) {
      return false;
    }

    final loadedUsername = SecureStorage.instance.getData(
      _sessionStorageGroup,
      'username',
      '',
    );
    final raw = SecureStorage.instance.data[_sessionStorageGroup] ?? {};
    loginInfo = LoginInfo.fromJson(raw);
    username = loadedUsername;

    if (!isLoggedIn()) {
      await _clearPersistedSession();
      return false;
    }

    try {
      await refreshTokenIfNeeded();
      if (!isLoggedIn()) {
        return false;
      }
      if (fetchUserInfo) {
        userInfo = await ApiController.getMyUserInfo();
      }
      await _persistSession();
      return true;
    } catch (_) {
      await logoutLocally(resetLoginInfo: true);
      return false;
    }
  }

  //Logout
  Future<void> logout({bool resetLoginInfo = true}) async {
    await ApiController.userLogout();
    await logoutLocally(resetLoginInfo: resetLoginInfo);
  }

  Future<void> logoutLocally({bool resetLoginInfo = true}) async {
    if (resetLoginInfo) {
      loginInfo = LoginInfo();
      userInfo = UserInfo();
    }

    username = "";
    AppState.instance.resetState();
    await _clearPersistedSession();
  }

  bool hasUserRole(String role) {
    return userInfo.roles.contains(role);
  }

  Future<void> _persistSession() async {
    SecureStorage.instance.replaceCategoryWithDataSet(_sessionStorageGroup, {
      'username': username,
      ...loginInfo.toJson().map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      ),
    });
    await SecureStorage.instance.saveDataToSecureStorage(_sessionStorageGroup);
  }

  Future<void> _clearPersistedSession() async {
    SecureStorage.instance.replaceCategoryWithDataSet(_sessionStorageGroup, {});
    await SecureStorage.instance.saveDataToSecureStorage(_sessionStorageGroup);
  }
}
