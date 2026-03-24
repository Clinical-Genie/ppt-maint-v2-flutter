import '../../common/data_helper.dart';

class LoginInfo {
  //String? result;
  //String? reason;
  String accessToken = "";
  String refreshToken = "";
  String expiresIn = "";
  DateTime? expiryDate = DateTime.fromMicrosecondsSinceEpoch(0);

  LoginInfo({
    //this.result,
    //this.reason,
    this.accessToken = "",
    this.refreshToken = "",
    this.expiresIn = "",
  });

  LoginInfo.fromJson(Map<dynamic, dynamic> json) {
    //result = json['result'];
    accessToken = DataHelper.getStringSafely(json, 'access_token', '');
    refreshToken = DataHelper.getStringSafely(json, 'refresh_token', '');
    expiresIn = DataHelper.getStringSafely(json, 'expires_in', '');
    final expiryDateStr = DataHelper.getStringSafely(json, 'expiry_date', '');
    if (expiryDateStr.isNotEmpty) {
      expiryDate =
          DateTime.tryParse(expiryDateStr) ??
          DateTime.now().add(Duration(seconds: int.tryParse(expiresIn) ?? 900));
    } else {
      expiryDate = DateTime.now().add(
        Duration(seconds: int.tryParse(expiresIn) ?? 900),
      );
    }

    // String expiryDateStr = DataHelper.getStringSafely(json, 'expiry_date', '');
    // try {
    //   expiryDate =
    //       DateTime.tryParse(expiryDateStr) ??
    //       DateTime.now().add(const Duration(days: 1));
    // } catch (e) {
    //   log("expiryDate format not correct: $e");
    //   expiryDate = DateTime.now().add(const Duration(days: 1));
    // }
  }

  //Not verified
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    //data['result'] = result;
    data['access_token'] = accessToken;
    data['refresh_token'] = refreshToken;
    data['expires_in'] = expiresIn;
    data['expiry_date'] = expiryDate?.toIso8601String() ?? '';
    return data;
  }

  // void extractKeys(String username, String hospitalID) {
  //   extractedKey = "";
  //   extractedIV = "";
  //   if (key.isNotEmpty) {
  //     final userK = EncryptionHelper.getByte(
  //       EncryptionHelper.adjustLength(username),
  //     );
  //     final userIV = EncryptionHelper.getByte(
  //       EncryptionHelper.adjustLength(hospitalID),
  //     );
  //     String dKey = EncryptionHelper.decrypt(
  //       key,
  //       base64Encode(userK),
  //       base64Encode(userIV),
  //     );
  //     if (dKey.isNotEmpty) {
  //       final dKeyList = dKey.split("|||");
  //       if (dKeyList.length == 2) {
  //         extractedKey = dKeyList[0];
  //         extractedIV = dKeyList[1];
  //         log("$extractedKey $extractedIV");
  //       }
  //     }
  //   }
}
