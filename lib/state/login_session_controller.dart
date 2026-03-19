import 'dart:developer';
import 'package:maintapp/api/api_controller.dart';
import 'package:maintapp/model/login_info.dart';
import 'package:maintapp/model/user_info.dart';
import 'package:maintapp/state/app_state.dart';

// import 'dart:developer';

class LoginSessionController {
  static final LoginSessionController instance =
      LoginSessionController(); //the single instance

  bool isRefreshingToken = false;
  String username = "";
  //static const String apiBaseUrl = "http://api.clinicalgenie.com/";
  LoginInfo loginInfo = LoginInfo();
  UserInfo userInfo = UserInfo();

  void debugCheckLoginInfo({String condition = "Check Login Info"}) {
    log("========== $condition ==========");
    log(loginInfo.toJson().toString());
    log(userInfo.toJson().toString());
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
      this.username = username;
      userInfo = await ApiController.getMyUserInfo();
    }
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
          } else {
            //If refresh token failed, logout locally
            logoutLocally(resetLoginInfo: true);
          }
        } finally {
          isRefreshingToken = false;
        }
      }
    }
  }

  //Logout
  Future<void> logout({bool resetLoginInfo = true}) async {
    await ApiController.userLogout();
    logoutLocally(resetLoginInfo: resetLoginInfo);
  }

  void logoutLocally({bool resetLoginInfo = true}) {
    if (resetLoginInfo) {
      loginInfo = LoginInfo();
      userInfo = UserInfo();
    }

    username = "";
    AppState.instance.resetState();
  }

  bool hasUserRole(String role) {
    return userInfo.roles.contains(role);
  }
}
