import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:maintapp/common/device_info_controller.dart';
import 'package:maintapp/common/secure_storage.dart';
import 'package:maintapp/main.dart';
import 'package:maintapp/model/login_info.dart';
import 'package:maintapp/model/user_info.dart';
import 'package:maintapp/model/session.dart';
import 'package:maintapp/model/admin_email_log.dart';
import 'package:maintapp/model/admin_result.dart';
import 'package:maintapp/model/api_result.dart';
import 'package:maintapp/model/email_batch.dart';
import 'package:maintapp/model/form_template.dart';
import 'package:maintapp/model/form_template_choice_group.dart';
import 'package:maintapp/model/user_status_result.dart';
import 'package:maintapp/model/user_visit.dart';
import 'package:maintapp/model/work_order_history.dart';
import 'package:maintapp/model/work_order_form.dart';
import 'package:maintapp/model/work_order_attachment.dart';
import 'package:maintapp/model/work_order.dart';
import 'package:maintapp/model/work_order_source_file.dart';
import 'package:maintapp/model/transfer_request.dart';
import 'package:maintapp/state/app_state.dart';
import 'package:maintapp/state/login_session_controller.dart';

class Server {
  String host;
  int port;
  bool useHttps;
  bool useWebProxy;

  Server({
    this.host = 'localhost',
    this.port = 3500,
    this.useHttps = false,
    this.useWebProxy = false,
  });

  String get base => '${useHttps ? 'https' : 'http'}://$host:$port';

  Map<String, String> toStorageMap() {
    return {
      'host': host,
      'port': port.toString(),
      'useHttps': useHttps.toString(),
      'useWebProxy': useWebProxy.toString(),
    };
  }
}

class ApiPaths {
  static Server server = Server();
  static const String _serverSettingsGroup = 'server_settings';

  static Future<void> loadServerSettings() async {
    if (!await SecureStorage.instance.loadDataFromSecureStorage(
      _serverSettingsGroup,
    )) {
      return;
    }

    log("Loading server settings...");

    server = Server(
      host: SecureStorage.instance.getData(
        _serverSettingsGroup,
        'host',
        server.host,
      ),
      port:
          int.tryParse(
            SecureStorage.instance.getData(
              _serverSettingsGroup,
              'port',
              server.port.toString(),
            ),
          ) ??
          server.port,
      useHttps:
          SecureStorage.instance.getData(
            _serverSettingsGroup,
            'useHttps',
            server.useHttps.toString(),
          ) ==
          'true',
      useWebProxy:
          SecureStorage.instance.getData(
            _serverSettingsGroup,
            'useWebProxy',
            server.useWebProxy.toString(),
          ) ==
          'true',
    );
    log(
      "Server settings loaded: host=${server.host}, port=${server.port}, useHttps=${server.useHttps}, useWebProxy=${server.useWebProxy}",
    );
  }

  static Future<void> saveServerSettings(Server newServer) async {
    server = newServer;
    SecureStorage.instance.replaceCategoryWithDataSet(
      _serverSettingsGroup,
      server.toStorageMap(),
    );
    await SecureStorage.instance.saveDataToSecureStorage(_serverSettingsGroup);
  }

  static const String health = '/api/health';
  static const String login = '/api/auth/login';
  static const String changePassword = '/api/auth/change-password';
  static const String forgotPassword = '/api/auth/forgot';
  static const String resetPassword = '/api/auth/reset';
  static const String refreshToken = '/api/auth/refresh';
  static const String logout = '/api/auth/logout';
  static const String sessions = '/api/auth/sessions';
  static String revokeSession(String sessionId) =>
      '/api/auth/sessions/$sessionId/revoke';
  static const String revokeAllSessions = '/api/auth/sessions/revoke-all';
  static const String requestVerifyEmail = '/api/auth/verify-email/request';
  static const String confirmVerifyEmail = '/api/auth/verify-email/confirm';
  static const String users = '/api/users';
  static String userById(String userId) => '/api/users/$userId';
  static String resetUserPassword(String userId) =>
      '/api/users/$userId/reset-password';
  static const String getMyUserInfo = '/api/users/me';
  static const String mySignature = '/api/users/me/signature';
  static String userStatus(String userId) => '/api/users/$userId/status';
  static const String userRoles = '/api/users/roles';
  static String replaceUserRoles(String userId) => '/api/users/$userId/roles';
  static String userVisits(String userId) => '/api/users/$userId/visits';
  static const String workOrders = '/api/work-orders';
  static String workOrderById(String workOrderId) =>
      '/api/work-orders/$workOrderId';
  static String workOrderAttachments(String workOrderId) =>
      '/api/work-orders/$workOrderId/attachments';
  static String workOrderAttachmentById(
    String workOrderId,
    String attachmentId,
  ) => '/api/work-orders/$workOrderId/attachments/$attachmentId';
  static String createTransferRequest(String workOrderId) =>
      '/api/work-orders/$workOrderId/transfer-requests';
  static const String incomingTransferRequests =
      '/api/work-orders/transfer-requests/incoming';
  static const String outgoingTransferRequests =
      '/api/work-orders/transfer-requests/outgoing';
  static String acceptTransferRequest(String requestId) =>
      '/api/work-orders/transfer-requests/$requestId/accept';
  static String rejectTransferRequest(String requestId) =>
      '/api/work-orders/transfer-requests/$requestId/reject';
  static String cancelTransferRequest(String requestId) =>
      '/api/work-orders/transfer-requests/$requestId/cancel';
  static String assignWorkOrder(String workOrderId) =>
      '/api/work-orders/$workOrderId/assign';
  static String cancelWorkOrder(String workOrderId) =>
      '/api/work-orders/$workOrderId/cancel';
  static String cannotCompleteWorkOrder(String workOrderId) =>
      '/api/work-orders/$workOrderId/cannot-completed';
  static String completeWorkOrder(String workOrderId) =>
      '/api/work-orders/$workOrderId/completed';
  static String workOrderEmails(String workOrderId) =>
      '/api/work-orders/$workOrderId/emails';
  static String workOrderHistory(String workOrderId) =>
      '/api/work-orders/$workOrderId/history';
  static String editWorkOrderForm(String workOrderId) =>
      '/api/work-orders/$workOrderId/form/admin-edit';
  static String remarkWorkOrderForm(String workOrderId) =>
      '/api/work-orders/$workOrderId/form/remark';
  static String regenerateWorkOrderFormPdf(String workOrderId) =>
      '/api/work-orders/$workOrderId/form/regenerate-pdf';
  static String mergeWorkOrderPdf(String workOrderId) =>
      '/api/work-orders/$workOrderId/merge-pdf';
  static String approveWorkOrder(String workOrderId) =>
      '/api/work-orders/$workOrderId/approve';
  static String rejectWorkOrder(String workOrderId) =>
      '/api/work-orders/$workOrderId/reject';
  static String workOrderForm(String workOrderId) =>
      '/api/work-orders/$workOrderId/form';
  static String submitWorkOrderForm(String workOrderId) =>
      '/api/work-orders/$workOrderId/form/submit';
  static String updateWorkOrderForm(String workOrderId) =>
      '/api/work-orders/$workOrderId/form/update';
  static String signWorkOrderForm(String workOrderId) =>
      '/api/work-orders/$workOrderId/form/sign';
  static const String workOrderOcr = '/api/work-orders/ocr';
  static String workOrderSourceFile(String fileId) =>
      '/api/work-order-files/$fileId';
  static String workOrderSourceFileDownload(String fileId) =>
      '/api/work-order-files/$fileId/download';
  static String pickWorkOrder(String workOrderId) =>
      '/api/work-orders/$workOrderId/pick';
  static String planWorkOrder(String workOrderId) =>
      '/api/work-orders/$workOrderId/plan';
  static String releaseWorkOrder(String workOrderId) =>
      '/api/work-orders/$workOrderId/release';
  static String startWorkOrder(String workOrderId) =>
      '/api/work-orders/$workOrderId/start-work';
  static const String emailBatches = '/api/email-batches';
  static const String formTemplates = '/api/form-templates';
  static String formTemplateById(String templateId) =>
      '/api/form-templates/$templateId';
  static String emailBatchById(String batchId) => '/api/email-batches/$batchId';
  static String sendEmailBatch(String batchId) =>
      '/api/email-batches/$batchId/send';
  static String emailBatchItem(String batchId, String workOrderId) =>
      '/api/email-batches/$batchId/items/$workOrderId';
  static const String adminEmailLogs = '/api/admin/email-logs';
  static String adminEmailLogById(String logId) =>
      '/api/admin/email-logs/$logId';
  static const String formTemplateChoiceGroups =
      '/api/form-template-choice-groups';
  static String formTemplateChoiceGroupById(String groupId) =>
      '/api/form-template-choice-groups/$groupId';
  static String formTemplateChoiceGroupItems(String groupId) =>
      '/api/form-template-choice-groups/$groupId/items';
  static String formTemplateChoiceGroupItemById(
    String groupId,
    String itemId,
  ) => '/api/form-template-choice-groups/$groupId/items/$itemId';
  static const String institutions = '/api/institutions';
  static const String adminPing = '/api/admin/ping';
  static const String runHousekeeping = '/api/ops/housekeeping/run';
}

class ApiController {
  static String resolveServerUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) {
      return trimmed;
    }
    final normalizedPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '${ApiPaths.server.base}$normalizedPath';
  }

  static Future<ApiMessageResult> healthCheck() async {
    final result = await _callJsonMap(
      apiNameForLog: 'healthCheck',
      subPath: ApiPaths.health,
      method: 'get',
      postParameters: const {},
      requireLogin: false,
    );
    return ApiMessageResult.fromJson(result);
  }

  static Future<LoginInfo> userLogin(String username, String password) async {
    LoginInfo output = LoginInfo();

    // log("Attempting to login with username: $username, $password");

    try {
      await ApiAction.callAPI(
        "userLogin",
        ApiPaths.login,
        {},
        {"username": username, "password": password},
        "post",
        (data) {
          // log("Login API call successful, data: $data");
          output = LoginInfo.fromJson(data);
        },
        (data) {
          log("Login API call failed ${data['message'] ?? ''}");
          // throw Exception("Login failed");
        },
        requireLogin: false,
      );
    } catch (e) {
      log("Exception during userLogin API call: $e");
      output = LoginInfo();
    }
    return output;
  }

  static Future<String> changePassword(
    String oldPassword,
    String newPassword,
  ) async {
    return _callMessage(
      apiNameForLog: 'changePassword',
      subPath: ApiPaths.changePassword,
      method: 'post',
      postParameters: {
        'old_password': oldPassword,
        'new_password': newPassword,
      },
    );
  }

  static Future<String> requestPasswordReset(String email) async {
    return _callMessage(
      apiNameForLog: 'requestPasswordReset',
      subPath: ApiPaths.forgotPassword,
      method: 'post',
      postParameters: {'email': email},
      requireLogin: false,
    );
  }

  static Future<String> resetPassword(
    String resetToken,
    String newPassword,
  ) async {
    return _callMessage(
      apiNameForLog: 'resetPassword',
      subPath: ApiPaths.resetPassword,
      method: 'post',
      postParameters: {'reset_token': resetToken, 'new_password': newPassword},
      requireLogin: false,
    );
  }

  static Future<LoginInfo> userRefreshToken() async {
    LoginInfo output = LoginInfo();

    try {
      await ApiAction.callAPI(
        "userRefreshToken",
        ApiPaths.refreshToken,
        {},
        {
          "refresh_token":
              LoginSessionController.instance.loginInfo.refreshToken,
        },
        "post",
        (data) {
          output = LoginInfo.fromJson(data);
        },
        (data) {
          log("Refresh token API failed ${data['message'] ?? ''}");
          // throw Exception("Refresh token failed");
        },
      );
    } catch (e) {
      log("Exception during userRefreshToken API call: $e");
      output = LoginInfo();
    }
    return output;
  }

  static Future<String> userLogout() async {
    return _callMessage(
      apiNameForLog: 'userLogout',
      subPath: ApiPaths.logout,
      method: 'post',
      postParameters: {
        'refresh_token': LoginSessionController.instance.loginInfo.refreshToken,
      },
      fallbackMessage: 'Logout successful',
    );
  }

  static Future<UserInfo> getMyUserInfo() async {
    UserInfo output = UserInfo();

    try {
      await ApiAction.callAPI(
        "getUserInfo",
        ApiPaths.getMyUserInfo,
        {},
        {},
        "get",
        (data) {
          output = UserInfo.fromJson(data);
        },
        (data) {
          log("Get user info API call failed ${data['message'] ?? ''}");
          // throw Exception("Get user info failed");
        },
      );
    } catch (e) {
      log("Exception during getMyUserInfo API call: $e");
      output = UserInfo();
    }
    return output;
  }

  static Future<UserInfo> getUserById(String userId) async {
    UserInfo output = UserInfo();

    try {
      await ApiAction.callAPI(
        'getUserById',
        ApiPaths.userById(userId),
        {},
        const {},
        'get',
        (data) {
          output = UserInfo.fromJson(data);
        },
        (data) {
          log('Get user by id API call failed ${data['message'] ?? ''}');
        },
      );
    } catch (e) {
      log('Exception during getUserById API call: $e');
      output = UserInfo();
    }

    return output;
  }

  static Future<bool> createUser({
    required String username,
    required String fullName,
    required String password,
    String? email,
  }) async {
    Map<String, dynamic> output = await _callJsonMap(
      apiNameForLog: 'createUser',
      subPath: ApiPaths.users,
      method: 'post',
      postParameters: {
        'username': username,
        'full_name': fullName,
        'password': password,
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      },
      successStatusCodes: const [201],
    );

    return output['username'] != null;
  }

  static Future<UserList> listUsers({
    String? q,
    int? limit,
    int? offset,
    String? role,
    bool? includeInactive,
  }) async {
    try {
      final result = await _callJsonMap(
        apiNameForLog: 'listUsers',
        subPath: ApiPaths.users,
        method: 'get',
        postParameters: const {},
        queryParameters: {
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
          if (limit != null) 'limit': limit,
          if (offset != null) 'offset': offset,
          if (role != null && role.trim().isNotEmpty) 'role': role.trim(),
          if (includeInactive != null) 'include_inactive': includeInactive,
        },
      );
      log("user list loaded: ${result['total'] ?? 'unknown total'} users");
      return UserList.fromJson(result);
    } catch (e) {
      log('Exception during listUsers API call: $e');
      return UserList();
    }
  }

  static Future<UserInfo> updateUserProfile(
    String userId, {
    String? fullName,
    String? email,
    String? phone,
    String? timezone,
    Map<String, dynamic>? profile,
  }) async {
    UserInfo output = UserInfo();

    try {
      await ApiAction.callAPI(
        'updateUserProfile',
        ApiPaths.userById(userId),
        {},
        {
          if (fullName != null) 'full_name': fullName,
          if (email != null) 'email': email,
          if (phone != null) 'phone': phone,
          if (timezone != null) 'timezone': timezone,
          if (profile != null) 'profile': profile,
        },
        'patch',
        (data) {
          output = UserInfo.fromJson(data);
        },
        (data) {
          log('Update user profile API call failed ${data['message'] ?? ''}');
        },
      );
    } catch (e) {
      log('Exception during updateUserProfile API call: $e');
      output = UserInfo();
    }

    return output;
  }

  static Future<AdminResetPasswordResult> adminResetUserPassword(
    String userId, {
    String? newPassword,
    bool generate = false,
    bool revokeSessions = false,
  }) async {
    final result = await _callJsonMap(
      apiNameForLog: 'adminResetUserPassword',
      subPath: ApiPaths.resetUserPassword(userId),
      method: 'post',
      postParameters: {
        if (newPassword != null && newPassword.trim().isNotEmpty)
          'new_password': newPassword.trim(),
        if (generate) 'generate': true,
        'revoke_sessions': revokeSessions,
      },
    );
    return AdminResetPasswordResult.fromJson(result);
  }

  static Future<String> uploadMySignature(
    Uint8List signatureBytes, {
    String filename = 'signature.png',
  }) async {
    String output = '';

    try {
      await ApiAction.callMultipartAPI(
        'uploadMySignature',
        ApiPaths.mySignature,
        {},
        files: [
          ApiMultipartFile(
            fieldName: 'signature',
            bytes: signatureBytes,
            filename: filename,
            contentType: 'image/png',
          ),
        ],
        dataHandlingCallback: (data) {
          output = '${data['message'] ?? 'Signature uploaded.'}';
        },
        failAction: () {
          log('Upload signature API call failed');
        },
      );
    } catch (e) {
      log('Exception during uploadMySignature API call: $e');
      output = '$e';
    }

    return output;
  }

  static Future<UserStatusUpdateResult> updateUserStatus(
    String userId,
    bool isActive,
  ) async {
    final result = await _callJsonMap(
      apiNameForLog: 'updateUserStatus',
      subPath: ApiPaths.userStatus(userId),
      method: 'patch',
      postParameters: {'is_active': isActive},
    );
    return UserStatusUpdateResult.fromJson(result);
  }

  static Future<RoleList> getAvailableRoles() async {
    try {
      final result = await _callJsonMap(
        apiNameForLog: 'getAvailableRoles',
        subPath: ApiPaths.userRoles,
        method: 'get',
        postParameters: const {},
      );

      final output = RoleList.fromJson(result['data']);
      log("Available roles loaded: ${output.toJson()}");
      return output;
    } catch (e) {
      log('Exception during getAvailableRoles API call: $e');
      return RoleList();
    }
  }

  static Future<List<String>> replaceRolesForUser(
    String userId,
    List<String> roles,
  ) async {
    final result = await _callJsonMap(
      apiNameForLog: 'replaceRolesForUser',
      subPath: ApiPaths.replaceUserRoles(userId),
      method: 'put',
      postParameters: {'roles': roles},
    );

    final rawRoles = result['roles'] ?? result['items'] ?? result['data'];
    if (rawRoles is List) {
      return rawRoles.map((item) => '$item').toList();
    }
    return [];
  }

  static Future<UserVisitList> getUserVisits(
    String userId, {
    String? institutionCode,
    String? from,
    String? to,
    int? limit,
    int? offset,
  }) async {
    final result = await _callJsonMap(
      apiNameForLog: 'getUserVisits',
      subPath: ApiPaths.userVisits(userId),
      method: 'get',
      postParameters: const {},
      queryParameters: {
        if (institutionCode != null && institutionCode.trim().isNotEmpty)
          'institution_code': institutionCode.trim(),
        if (from != null && from.trim().isNotEmpty) 'from': from.trim(),
        if (to != null && to.trim().isNotEmpty) 'to': to.trim(),
        if (limit != null) 'limit': limit,
        if (offset != null) 'offset': offset,
      },
    );
    return UserVisitList.fromJson(result);
  }

  static Future<WorkOrder> createWorkOrder(dynamic payload) async {
    final normalizedPayload = _buildCreateWorkOrderPayload(payload);
    final result = await _callJsonMap(
      apiNameForLog: 'createWorkOrder',
      subPath: ApiPaths.workOrders,
      method: 'post',
      postParameters: normalizedPayload,
      successStatusCodes: const [201],
    );

    final errorMessage = _extractApiErrorMessage(result);
    if (errorMessage.isNotEmpty) {
      throw Exception(errorMessage);
    }
    if (result.isEmpty) {
      throw Exception('Create work order failed.');
    }
    return WorkOrder.fromJson(_extractCreateWorkOrderPayload(result));
  }

  static Future<FormTemplateList> listFormTemplates({String? type}) async {
    final result = await _callJsonMap(
      apiNameForLog: 'listFormTemplates',
      subPath: ApiPaths.formTemplates,
      method: 'get',
      postParameters: const {},
      queryParameters: {
        if (type != null && type.trim().isNotEmpty) 'type': type.trim(),
      },
    );
    return FormTemplateList.fromJson(result);
  }

  static Future<FormTemplate> getFormTemplateById(String templateId) async {
    final result = await _callJsonMap(
      apiNameForLog: 'getFormTemplateById',
      subPath: ApiPaths.formTemplateById(templateId),
      method: 'get',
      postParameters: const {},
    );
    return FormTemplate.fromJson(result);
  }

  static Future<FormTemplateChoiceGroupList> listFormTemplateChoiceGroups({
    bool includeInactive = false,
  }) async {
    final result = await _callJsonMap(
      apiNameForLog: 'listFormTemplateChoiceGroups',
      subPath: ApiPaths.formTemplateChoiceGroups,
      method: 'get',
      postParameters: const {},
      queryParameters: {'includeInactive': includeInactive},
    );
    return FormTemplateChoiceGroupList.fromJson(result);
  }

  static Future<FormTemplateChoiceGroupDetail> getFormTemplateChoiceGroup(
    String groupId, {
    bool includeInactive = false,
  }) async {
    final result = await _callJsonMap(
      apiNameForLog: 'getFormTemplateChoiceGroup',
      subPath: ApiPaths.formTemplateChoiceGroupById(groupId),
      method: 'get',
      postParameters: const {},
      queryParameters: {'includeInactive': includeInactive},
    );
    return FormTemplateChoiceGroupDetail.fromJson(result);
  }

  static Future<FormTemplateChoiceGroupDetail?>
  getFormTemplateChoiceGroupByCode(
    String code, {
    bool includeInactive = false,
  }) async {
    final list = await listFormTemplateChoiceGroups(
      includeInactive: includeInactive,
    );
    final normalizedCode = code.trim().toLowerCase();
    if (normalizedCode.isEmpty) return null;
    final match = list.items.where((item) {
      return item.code.trim().toLowerCase() == normalizedCode;
    });
    if (match.isEmpty) return null;
    return getFormTemplateChoiceGroup(
      match.first.id,
      includeInactive: includeInactive,
    );
  }

  static Future<FormTemplateChoiceGroupDetail> createFormTemplateChoiceGroup({
    required String code,
    required String name,
    String? description,
    bool isActive = true,
  }) async {
    final result = await _callJsonMap(
      apiNameForLog: 'createFormTemplateChoiceGroup',
      subPath: ApiPaths.formTemplateChoiceGroups,
      method: 'post',
      postParameters: {
        'code': code,
        'name': name,
        'description': description,
        'is_active': isActive,
      },
      successStatusCodes: const [200, 201],
    );
    return FormTemplateChoiceGroupDetail.fromJson(result);
  }

  static Future<FormTemplateChoiceGroupDetail> updateFormTemplateChoiceGroup(
    String groupId, {
    String? name,
    String? description,
    bool? isActive,
  }) async {
    final result = await _callJsonMap(
      apiNameForLog: 'updateFormTemplateChoiceGroup',
      subPath: ApiPaths.formTemplateChoiceGroupById(groupId),
      method: 'patch',
      postParameters: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (isActive != null) 'is_active': isActive,
      },
    );
    return FormTemplateChoiceGroupDetail.fromJson(result);
  }

  static Future<FormTemplateChoiceItem> addFormTemplateChoiceItem(
    String groupId, {
    required String code,
    required String labelEn,
    String? labelZh,
    int sort = 0,
    bool isActive = true,
    Map<String, dynamic> metaJson = const {},
  }) async {
    final result = await _callJsonMap(
      apiNameForLog: 'addFormTemplateChoiceItem',
      subPath: ApiPaths.formTemplateChoiceGroupItems(groupId),
      method: 'post',
      postParameters: {
        'code': code,
        'label_en': labelEn,
        'label_zh': labelZh ?? '',
        'sort': sort,
        'is_active': isActive,
        'meta_json': metaJson,
      },
      successStatusCodes: const [200, 201],
    );
    return FormTemplateChoiceItem.fromJson(result);
  }

  static Future<FormTemplateChoiceItem> updateFormTemplateChoiceItem(
    String groupId,
    String itemId, {
    String? labelEn,
    String? labelZh,
    int? sort,
    bool? isActive,
    Map<String, dynamic>? metaJson,
  }) async {
    final result = await _callJsonMap(
      apiNameForLog: 'updateFormTemplateChoiceItem',
      subPath: ApiPaths.formTemplateChoiceGroupItemById(groupId, itemId),
      method: 'patch',
      postParameters: {
        if (labelEn != null) 'label_en': labelEn,
        if (labelZh != null) 'label_zh': labelZh,
        if (sort != null) 'sort': sort,
        if (isActive != null) 'is_active': isActive,
        if (metaJson != null) 'meta_json': metaJson,
      },
    );
    return FormTemplateChoiceItem.fromJson(result);
  }

  static Future<String> deactivateFormTemplateChoiceItem(
    String groupId,
    String itemId,
  ) async {
    return _callMessage(
      apiNameForLog: 'deactivateFormTemplateChoiceItem',
      subPath: ApiPaths.formTemplateChoiceGroupItemById(groupId, itemId),
      method: 'delete',
      postParameters: const {},
      fallbackMessage: 'Choice item deactivated',
    );
  }

  static String _extractApiErrorMessage(dynamic payload) {
    if (payload == null) return '';
    if (payload is String) {
      final value = payload.trim();
      if ((value.startsWith('{') && value.endsWith('}')) ||
          (value.startsWith('[') && value.endsWith(']'))) {
        try {
          return _extractApiErrorMessage(json.decode(value));
        } catch (_) {}
      }
      return value;
    }
    if (payload is List) {
      final messages = payload
          .map(_extractApiErrorMessage)
          .where((message) => message.isNotEmpty)
          .toList();
      return messages.join('\n');
    }
    if (payload is Map) {
      final map = Map<String, dynamic>.from(payload);

      final directKeys = ['message', 'error', 'detail', 'details', 'title'];
      for (final key in directKeys) {
        final message = _extractApiErrorMessage(map[key]);
        if (message.isNotEmpty) {
          return message;
        }
      }

      final issues = map['issues'];
      if (issues is List && issues.isNotEmpty) {
        final messages = issues
            .map((issue) {
              if (issue is Map) {
                final issueMap = Map<String, dynamic>.from(issue);
                final path = issueMap['path'] is List
                    ? (issueMap['path'] as List)
                          .where((part) => part != null)
                          .map((part) => '$part')
                          .join('.')
                    : '';
                final message = '${issueMap['message'] ?? ''}'.trim();
                if (path.isNotEmpty && message.isNotEmpty) {
                  return '$path: $message';
                }
                return message;
              }
              return _extractApiErrorMessage(issue);
            })
            .where((message) => message.isNotEmpty)
            .toList();
        if (messages.isNotEmpty) {
          return messages.join('\n');
        }
      }

      final dataMessage = _extractApiErrorMessage(map['data']);
      if (dataMessage.isNotEmpty) {
        return dataMessage;
      }
    }

    return '';
  }

  static String _extractApiErrorCode(dynamic payload) {
    if (payload == null) return '';
    if (payload is String) {
      final value = payload.trim();
      if ((value.startsWith('{') && value.endsWith('}')) ||
          (value.startsWith('[') && value.endsWith(']'))) {
        try {
          return _extractApiErrorCode(json.decode(value));
        } catch (_) {}
      }
      return '';
    }
    if (payload is List) {
      for (final item in payload) {
        final code = _extractApiErrorCode(item);
        if (code.isNotEmpty) return code;
      }
      return '';
    }
    if (payload is Map) {
      final map = Map<String, dynamic>.from(payload);
      for (final key in const ['code', 'error_code', 'errorCode']) {
        final value = map[key];
        if (value != null) {
          final code = '$value'.trim();
          if (code.isNotEmpty) return code;
        }
      }
      return _extractApiErrorCode(map['data']);
    }
    return '';
  }

  static String _formatApiErrorSummary(dynamic payload) {
    final message = _extractApiErrorMessage(payload);
    final code = _extractApiErrorCode(payload);
    if (code.isNotEmpty && message.isNotEmpty) {
      return '$code: $message';
    }
    if (message.isNotEmpty) {
      return message;
    }
    if (code.isNotEmpty) {
      return code;
    }
    return '';
  }

  static String Function(Map<String, dynamic>, List<String>) extractString =
      (Map<String, dynamic> source, List<String> keys) {
        for (final key in keys) {
          final value = source[key];
          if (value != null) {
            final valueString = '$value'.trim();
            if (valueString.isNotEmpty) {
              return valueString;
            }
          }
        }
        return '';
      };

  static Map<String, dynamic> _buildCreateWorkOrderPayload(dynamic payload) {
    if (payload is WorkOrder) {
      return payload.toCreatePayload();
    }
    if (payload is! Map) {
      return {};
    }
    final Map<String, dynamic> source = Map<String, dynamic>.from(payload);

    final String resolvedWoType = extractString(source, ['wo_type', 'woType']);
    final String resolvedWoNo = extractString(source, ['wo_no', 'woNo']);
    final String resolvedLocationCode = extractString(source, [
      'location_code',
      'locationCode',
    ]);
    final String resolvedLocation = extractString(source, [
      'location',
      'location_code',
      'locationCode',
    ]);
    final String resolvedAssetNumber = extractString(source, [
      'asset_number',
      'assetNumber',
    ]);
    final String resolvedSerialNumber = extractString(source, [
      'serial_number',
      'serialNumber',
    ]);
    final String resolvedTitle = extractString(source, ['title']);
    final String resolvedDescription = extractString(source, ['description']);
    final String resolvedContactName = extractString(source, [
      'contact_name',
      'contactName',
    ]);
    final String resolvedContactNumber = extractString(source, [
      'contact_number',
      'contactNumber',
    ]);
    final String resolvedInstitutionCode = extractString(source, [
      'institution_code',
      'institutionCode',
    ]);
    final String resolvedInstitutionName = extractString(source, [
      'institution_name',
      'institutionName',
    ]);
    final String resolvedInstitution = extractString(source, [
      'institution',
      'institution_name',
      'institutionName',
    ]);
    final String resolvedDeviceBrand = extractString(source, [
      'device_brand',
      'deviceBrand',
    ]);
    final String resolvedDeviceModel = extractString(source, [
      'device_model',
      'deviceModel',
    ]);
    final String resolvedPriority = extractString(source, ['priority']);
    final String resolvedCategory = extractString(source, ['category']);
    final String resolvedPlannedDate = extractString(source, [
      'planned_date',
      'plannedDate',
    ]);
    final String resolvedDueDate = extractString(source, [
      'due_date',
      'dueDate',
    ]);
    final String resolvedHaCreatedAt = extractString(source, [
      'ha_created_at',
      'haCreatedAt',
    ]);
    final String resolvedHaOutboundAt = extractString(source, [
      'ha_outbound_at',
      'haOutboundAt',
    ]);
    final String resolvedCmBreakdownAt = extractString(source, [
      'cm_breakdown_at',
      'cmBreakdownAt',
    ]);
    final String resolvedPmDeadlineAt = extractString(source, [
      'pm_deadline_at',
      'pmDeadlineAt',
    ]);
    final String resolvedStatus = extractString(source, ['status']);
    final String resolvedOwnerUserId = extractString(source, [
      'owner_user_id',
      'ownerUserId',
    ]);
    final String resolvedSourceFileId = extractString(source, [
      'source_file_id',
      'sourceFileId',
    ]);
    final String resolvedSourceFileName = extractString(source, [
      'source_file_name',
      'sourceFileName',
    ]);
    final String resolvedSourceFileUrl = extractString(source, [
      'source_file_url',
      'sourceFileUrl',
    ]);
    final String resolvedOcrJobId = extractString(source, [
      'ocr_job_id',
      'ocrJobId',
    ]);

    final String derivedInstitutionCode = resolvedInstitutionCode.isNotEmpty
        ? resolvedInstitutionCode
        : (resolvedLocationCode.contains('-')
              ? resolvedLocationCode.split('-').first
              : '');

    return {
      if (resolvedWoType.isNotEmpty) 'wo_type': resolvedWoType,
      if (resolvedWoType.isNotEmpty) 'woType': resolvedWoType,
      if (resolvedWoNo.isNotEmpty) 'wo_no': resolvedWoNo,
      if (resolvedLocationCode.isNotEmpty)
        'location_code': resolvedLocationCode,
      if (resolvedLocationCode.isNotEmpty) 'locationCode': resolvedLocationCode,
      if (resolvedLocation.isNotEmpty) 'location': resolvedLocation,
      if (resolvedAssetNumber.isNotEmpty) 'asset_number': resolvedAssetNumber,
      if (resolvedAssetNumber.isNotEmpty) 'assetNumber': resolvedAssetNumber,
      if (resolvedSerialNumber.isNotEmpty)
        'serial_number': resolvedSerialNumber,
      if (resolvedSerialNumber.isNotEmpty) 'serialNumber': resolvedSerialNumber,
      if (resolvedDeviceBrand.isNotEmpty) 'device_brand': resolvedDeviceBrand,
      if (resolvedDeviceBrand.isNotEmpty) 'deviceBrand': resolvedDeviceBrand,
      if (resolvedDeviceModel.isNotEmpty) 'device_model': resolvedDeviceModel,
      if (resolvedDeviceModel.isNotEmpty) 'deviceModel': resolvedDeviceModel,
      if (resolvedContactName.isNotEmpty) 'contact_name': resolvedContactName,
      if (resolvedContactName.isNotEmpty) 'contactName': resolvedContactName,
      if (resolvedContactNumber.isNotEmpty)
        'contact_number': resolvedContactNumber,
      if (resolvedContactNumber.isNotEmpty)
        'contactNumber': resolvedContactNumber,
      if (resolvedInstitution.isNotEmpty) 'institution': resolvedInstitution,
      if (resolvedInstitutionCode.isNotEmpty)
        'institution_code': resolvedInstitutionCode,
      if (resolvedInstitutionCode.isNotEmpty)
        'institutionCode': resolvedInstitutionCode,
      if (derivedInstitutionCode.isNotEmpty)
        'institution_code': derivedInstitutionCode,
      if (derivedInstitutionCode.isNotEmpty)
        'institutionCode': derivedInstitutionCode,
      if (resolvedInstitutionName.isNotEmpty)
        'institution_name': resolvedInstitutionName,
      if (resolvedInstitutionName.isNotEmpty)
        'institutionName': resolvedInstitutionName,
      if (resolvedTitle.isNotEmpty) 'title': resolvedTitle,
      if (resolvedDescription.isNotEmpty) 'description': resolvedDescription,
      if (resolvedPriority.isNotEmpty) 'priority': resolvedPriority,
      if (resolvedCategory.isNotEmpty) 'category': resolvedCategory,
      if (resolvedPlannedDate.isNotEmpty) 'planned_date': resolvedPlannedDate,
      if (resolvedPlannedDate.isNotEmpty) 'plannedDate': resolvedPlannedDate,
      if (resolvedDueDate.isNotEmpty) 'due_date': resolvedDueDate,
      if (resolvedDueDate.isNotEmpty) 'dueDate': resolvedDueDate,
      if (resolvedHaCreatedAt.isNotEmpty) 'ha_created_at': resolvedHaCreatedAt,
      if (resolvedHaCreatedAt.isNotEmpty) 'haCreatedAt': resolvedHaCreatedAt,
      if (resolvedHaOutboundAt.isNotEmpty)
        'ha_outbound_at': resolvedHaOutboundAt,
      if (resolvedHaOutboundAt.isNotEmpty) 'haOutboundAt': resolvedHaOutboundAt,
      if (resolvedCmBreakdownAt.isNotEmpty)
        'cm_breakdown_at': resolvedCmBreakdownAt,
      if (resolvedCmBreakdownAt.isNotEmpty)
        'cmBreakdownAt': resolvedCmBreakdownAt,
      if (resolvedPmDeadlineAt.isNotEmpty)
        'pm_deadline_at': resolvedPmDeadlineAt,
      if (resolvedPmDeadlineAt.isNotEmpty) 'pmDeadlineAt': resolvedPmDeadlineAt,
      if (resolvedStatus.isNotEmpty) 'status': resolvedStatus,
      if (resolvedOwnerUserId.isNotEmpty) 'owner_user_id': resolvedOwnerUserId,
      if (resolvedOwnerUserId.isNotEmpty) 'ownerUserId': resolvedOwnerUserId,
      if (resolvedSourceFileId.isNotEmpty)
        'source_file_id': resolvedSourceFileId,
      if (resolvedSourceFileName.isNotEmpty)
        'source_file_name': resolvedSourceFileName,
      if (resolvedSourceFileUrl.isNotEmpty)
        'source_file_url': resolvedSourceFileUrl,
      if (resolvedOcrJobId.isNotEmpty) 'ocr_job_id': resolvedOcrJobId,
      if (source['draft_data'] is Map) 'draft_data': source['draft_data'],
    };
  }

  static Map<String, dynamic> _extractCreateWorkOrderPayload(
    Map<String, dynamic> response,
  ) {
    final dynamic nested = response['data'];
    if (nested is Map<dynamic, dynamic>) {
      final dynamic direct =
          nested['wo'] ??
          nested['work_order'] ??
          nested['data'] ??
          nested['item'];
      if (direct is Map<dynamic, dynamic>) {
        return Map<String, dynamic>.from(direct);
      }
    }

    final dynamic direct =
        response['wo'] ??
        response['work_order'] ??
        response['item'] ??
        response['data'];
    if (direct is Map<dynamic, dynamic>) {
      return Map<String, dynamic>.from(direct);
    }

    return response;
  }

  static Future<WorkOrderList> listWorkOrders({
    String? woType,
    String? user,
    String? institution,
    String? ownerUserId,
    String? plannedDate,
    String? status,
    String? woNo,
    String? assetNumber,
    String? serialNumber,
    String? haCreatedFrom,
    String? haCreatedTo,
    String? haOutboundFrom,
    String? haOutboundTo,
    String? cmBreakdownFrom,
    String? cmBreakdownTo,
    String? pmDeadlineFrom,
    String? pmDeadlineTo,
    bool? approved,
    bool? emailSent,
    int? page,
    int? pageSize,
  }) async {
    final result = await _callJsonMap(
      apiNameForLog: 'listWorkOrders',
      subPath: ApiPaths.workOrders,
      method: 'get',
      postParameters: const {},
      queryParameters: {
        if (woType != null && woType.isNotEmpty) 'woType': woType,
        if (user != null && user.isNotEmpty) 'user': user,
        if (institution != null && institution.isNotEmpty)
          'institution': institution,
        if (ownerUserId != null && ownerUserId.isNotEmpty)
          'ownerUserId': ownerUserId,
        if (plannedDate != null && plannedDate.isNotEmpty)
          'plannedDate': plannedDate,
        if (status != null && status.isNotEmpty) 'status': status,
        if (woNo != null && woNo.isNotEmpty) 'woNo': woNo,
        if (assetNumber != null && assetNumber.isNotEmpty)
          'assetNumber': assetNumber,
        if (serialNumber != null && serialNumber.isNotEmpty)
          'serialNumber': serialNumber,
        if (haCreatedFrom != null && haCreatedFrom.isNotEmpty)
          'haCreatedFrom': haCreatedFrom,
        if (haCreatedTo != null && haCreatedTo.isNotEmpty)
          'haCreatedTo': haCreatedTo,
        if (haOutboundFrom != null && haOutboundFrom.isNotEmpty)
          'haOutboundFrom': haOutboundFrom,
        if (haOutboundTo != null && haOutboundTo.isNotEmpty)
          'haOutboundTo': haOutboundTo,
        if (cmBreakdownFrom != null && cmBreakdownFrom.isNotEmpty)
          'cmBreakdownFrom': cmBreakdownFrom,
        if (cmBreakdownTo != null && cmBreakdownTo.isNotEmpty)
          'cmBreakdownTo': cmBreakdownTo,
        if (pmDeadlineFrom != null && pmDeadlineFrom.isNotEmpty)
          'pmDeadlineFrom': pmDeadlineFrom,
        if (pmDeadlineTo != null && pmDeadlineTo.isNotEmpty)
          'pmDeadlineTo': pmDeadlineTo,
        if (approved != null) 'approved': approved,
        if (emailSent != null) 'emailSent': emailSent,
        if (page != null) 'page': page,
        if (pageSize != null) 'pageSize': pageSize,
      },
    );

    return WorkOrderList.fromJson(result);
  }

  static Future<List<InstitutionOption>> listInstitutions() async {
    final result = await _callJsonMap(
      apiNameForLog: 'listInstitutions',
      subPath: ApiPaths.institutions,
      method: 'get',
      postParameters: const {},
    );

    dynamic rawItems =
        result['items'] ??
        result['rows'] ??
        result['institutions'] ??
        result['data'];
    if (rawItems is Map<dynamic, dynamic>) {
      rawItems =
          rawItems['items'] ?? rawItems['rows'] ?? rawItems['institutions'];
    }

    if (rawItems is! List) {
      return [];
    }

    final output = <InstitutionOption>[];
    for (final item in rawItems) {
      if (item is Map<dynamic, dynamic>) {
        final institution = InstitutionOption.fromJson(item);
        if (institution.code.isNotEmpty) {
          output.add(institution);
        }
      }
    }
    return output;
  }

  static Future<WorkOrder> getWorkOrderById(String workOrderId) async {
    final result = await _callJsonMap(
      apiNameForLog: 'getWorkOrderById',
      subPath: ApiPaths.workOrderById(workOrderId),
      method: 'get',
      postParameters: const {},
    );
    if (result.isEmpty) {
      return WorkOrder();
    }
    final root = result['data'];
    if (root is Map) {
      return WorkOrder.fromJson(Map<String, dynamic>.from(root));
    }
    return WorkOrder.fromJson(result);
  }

  static Future<WorkOrder> updateWorkOrder(
    String workOrderId,
    Map<String, dynamic> payload,
  ) async {
    final result = await _callJsonMap(
      apiNameForLog: 'updateWorkOrder',
      subPath: ApiPaths.workOrderById(workOrderId),
      method: 'patch',
      postParameters: payload,
    );

    final errorMessage = _extractApiErrorMessage(result);
    if (errorMessage.isNotEmpty) {
      throw Exception(errorMessage);
    }
    if (result.isEmpty) {
      throw Exception('Update work order failed.');
    }
    final root = result['data'];
    if (root is Map) {
      return WorkOrder.fromJson(Map<String, dynamic>.from(root));
    }
    return WorkOrder.fromJson(result);
  }

  static Future<WorkOrderAttachmentList> getWorkOrderAttachments(
    String workOrderId, {
    bool showError = true,
  }) async {
    final result = await _callJsonMap(
      apiNameForLog: 'getWorkOrderAttachments',
      subPath: ApiPaths.workOrderAttachments(workOrderId),
      method: 'get',
      postParameters: const {},
      showError: showError,
    );
    return WorkOrderAttachmentList.fromJson(result);
  }

  static Future<String> uploadWorkOrderAttachment(
    String workOrderId, {
    required Uint8List fileBytes,
    required String filename,
    required String contentType,
    String reason = '',
    String description = '',
  }) async {
    String output = '';

    try {
      await ApiAction.callMultipartAPI(
        'uploadWorkOrderAttachment',
        ApiPaths.workOrderAttachments(workOrderId),
        const {},
        files: [
          ApiMultipartFile(
            fieldName: 'file',
            bytes: fileBytes,
            filename: filename,
            contentType: contentType,
          ),
        ],
        fields: {
          if (reason.trim().isNotEmpty) 'reason': reason.trim(),
          if (description.trim().isNotEmpty) 'description': description.trim(),
        },
        dataHandlingCallback: (data) {
          final message = _extractApiErrorMessage(data);
          output = message.isEmpty ? 'Attachment uploaded.' : message;
        },
        failAction: () {
          log('Upload work order attachment API call failed');
        },
        successStatusCodes: const [200, 201],
      );
    } catch (e) {
      log('Exception during uploadWorkOrderAttachment API call: $e');
      output = '$e';
    }

    return output;
  }

  static Future<String> deleteWorkOrderAttachment(
    String workOrderId,
    String attachmentId, {
    String reason = '',
  }) async {
    return _callMessage(
      apiNameForLog: 'deleteWorkOrderAttachment',
      subPath: ApiPaths.workOrderAttachmentById(workOrderId, attachmentId),
      method: 'delete',
      postParameters: {if (reason.trim().isNotEmpty) 'reason': reason.trim()},
      fallbackMessage: 'Attachment deleted.',
    );
  }

  static Future<TransferRequest> createTransferRequest(
    String workOrderId, {
    required String toEngineerId,
    required String reason,
  }) async {
    final result = await _callJsonMap(
      apiNameForLog: 'createTransferRequest',
      subPath: ApiPaths.createTransferRequest(workOrderId),
      method: 'post',
      postParameters: {'toEngineerId': toEngineerId, 'reason': reason},
    );
    return TransferRequest.fromJson(result);
  }

  static Future<TransferRequestListResponse> listIncomingTransferRequests({
    String? status,
    int? limit,
    int? offset,
  }) async {
    final result = await _callJsonMap(
      apiNameForLog: 'listIncomingTransferRequests',
      subPath: ApiPaths.incomingTransferRequests,
      method: 'get',
      postParameters: const {},
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (limit != null) 'limit': limit,
        if (offset != null) 'offset': offset,
      },
    );
    return TransferRequestListResponse.fromJson(result);
  }

  static Future<TransferRequestListResponse> listOutgoingTransferRequests({
    String? status,
    int? limit,
    int? offset,
  }) async {
    final result = await _callJsonMap(
      apiNameForLog: 'listOutgoingTransferRequests',
      subPath: ApiPaths.outgoingTransferRequests,
      method: 'get',
      postParameters: const {},
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (limit != null) 'limit': limit,
        if (offset != null) 'offset': offset,
      },
    );
    return TransferRequestListResponse.fromJson(result);
  }

  static Future<WorkOrderActionResult> acceptTransferRequest(
    String requestId, {
    String? reason,
  }) async {
    final result = await _callJsonMap(
      apiNameForLog: 'acceptTransferRequest',
      subPath: ApiPaths.acceptTransferRequest(requestId),
      method: 'post',
      postParameters: {
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
    return WorkOrderActionResult.fromJson(result);
  }

  static Future<WorkOrderActionResult> rejectTransferRequest(
    String requestId, {
    String? reason,
  }) async {
    final result = await _callJsonMap(
      apiNameForLog: 'rejectTransferRequest',
      subPath: ApiPaths.rejectTransferRequest(requestId),
      method: 'post',
      postParameters: {
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
    return WorkOrderActionResult.fromJson(result);
  }

  static Future<WorkOrderActionResult> cancelTransferRequest(
    String requestId, {
    String? reason,
  }) async {
    final result = await _callJsonMap(
      apiNameForLog: 'cancelTransferRequest',
      subPath: ApiPaths.cancelTransferRequest(requestId),
      method: 'post',
      postParameters: {
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
    return WorkOrderActionResult.fromJson(result);
  }

  static Future<WorkOrderActionResult> assignWorkOrder(
    String workOrderId, {
    required String targetUserId,
    required String reason,
  }) async {
    final result = await _callJsonMap(
      apiNameForLog: 'assignWorkOrder',
      subPath: ApiPaths.assignWorkOrder(workOrderId),
      method: 'post',
      postParameters: {'targetUserId': targetUserId, 'reason': reason},
    );
    return WorkOrderActionResult.fromJson(result);
  }

  static Future<String> cancelWorkOrder(
    String workOrderId,
    String reason,
  ) async {
    return _callMessage(
      apiNameForLog: 'cancelWorkOrder',
      subPath: ApiPaths.cancelWorkOrder(workOrderId),
      method: 'post',
      postParameters: {'reason': reason},
      fallbackMessage: 'Work order cancelled.',
    );
  }

  static Future<String> markWorkOrderCannotCompleted(
    String workOrderId,
    String reason,
  ) async {
    return _callMessage(
      apiNameForLog: 'markWorkOrderCannotCompleted',
      subPath: ApiPaths.cannotCompleteWorkOrder(workOrderId),
      method: 'post',
      postParameters: {'reason': reason},
      fallbackMessage: 'Work order marked as cannot completed.',
    );
  }

  static Future<WorkOrderActionResult> completeWorkOrder(
    String workOrderId,
    String summary,
  ) async {
    final result = await _callJsonMap(
      apiNameForLog: 'completeWorkOrder',
      subPath: ApiPaths.completeWorkOrder(workOrderId),
      method: 'post',
      postParameters: {'summary': summary},
      successStatusCodes: const [200, 410],
    );
    return WorkOrderActionResult.fromJson(result);
  }

  static Future<String> pickWorkOrder(String workOrderId) async {
    return _callMessage(
      apiNameForLog: 'pickWorkOrder',
      subPath: ApiPaths.pickWorkOrder(workOrderId),
      method: 'post',
      postParameters: const {},
      fallbackMessage: 'Work order picked successfully.',
    );
  }

  static Future<String> planWorkOrder(
    String workOrderId, {
    required String plannedDate,
    String? plannedHalfDay,
  }) async {
    return _callMessage(
      apiNameForLog: 'planWorkOrder',
      subPath: ApiPaths.planWorkOrder(workOrderId),
      method: 'post',
      postParameters: {
        'plannedDate': plannedDate,
        if (plannedHalfDay != null && plannedHalfDay.isNotEmpty)
          'plannedHalfDay': plannedHalfDay,
      },
      fallbackMessage: 'Work order planned successfully.',
    );
  }

  static Future<String> releaseWorkOrder(
    String workOrderId,
    String reason,
  ) async {
    return _callMessage(
      apiNameForLog: 'releaseWorkOrder',
      subPath: ApiPaths.releaseWorkOrder(workOrderId),
      method: 'post',
      postParameters: {'reason': reason},
      fallbackMessage: 'Work order released.',
    );
  }

  static Future<String> startWorkOrder(String workOrderId) async {
    return _callMessage(
      apiNameForLog: 'startWorkOrder',
      subPath: ApiPaths.startWorkOrder(workOrderId),
      method: 'post',
      postParameters: const {},
      fallbackMessage: 'Work order started.',
    );
  }

  static Future<String> approveWorkOrder(String workOrderId) async {
    return _callMessage(
      apiNameForLog: 'approveWorkOrder',
      subPath: ApiPaths.approveWorkOrder(workOrderId),
      method: 'post',
      postParameters: const {},
      fallbackMessage: 'Work order approved.',
    );
  }

  static Future<String> rejectWorkOrder(
    String workOrderId, {
    required String reason,
  }) async {
    return _callMessage(
      apiNameForLog: 'rejectWorkOrder',
      subPath: ApiPaths.rejectWorkOrder(workOrderId),
      method: 'post',
      postParameters: {'reason': reason},
      fallbackMessage: 'Work order rejected.',
    );
  }

  static Future<String> regenerateMergedWorkOrderPdf(String workOrderId) async {
    return _callMessage(
      apiNameForLog: 'regenerateMergedWorkOrderPdf',
      subPath: ApiPaths.mergeWorkOrderPdf(workOrderId),
      method: 'post',
      postParameters: const {},
      fallbackMessage: 'Merged PDF updated.',
    );
  }

  static Future<WorkOrderOcrResult> uploadWorkOrderOcr(
    Uint8List pdfBytes, {
    String filename = 'work_order.pdf',
  }) async {
    Map<String, dynamic> output = {};

    try {
      await ApiAction.callMultipartAPI(
        'uploadWorkOrderOcr',
        ApiPaths.workOrderOcr,
        {},
        files: [
          ApiMultipartFile(
            fieldName: 'pdf',
            bytes: pdfBytes,
            filename: filename,
            contentType: 'application/pdf',
          ),
        ],
        dataHandlingCallback: (data) {
          output = Map<String, dynamic>.from(data);
        },
        failAction: () {
          log('Work order OCR API call failed');
        },
      );
    } catch (e) {
      log('Exception during uploadWorkOrderOcr API call: $e');
    }

    if (output.isEmpty) {
      return WorkOrderOcrResult();
    }
    return WorkOrderOcrResult.fromJson(output);
  }

  static Future<WorkOrderSourceFile> getWorkOrderSourceFile(
    String fileId,
  ) async {
    final result = await _callJsonMap(
      apiNameForLog: 'getWorkOrderSourceFile',
      subPath: ApiPaths.workOrderSourceFile(fileId),
      method: 'get',
      postParameters: const {},
    );
    return WorkOrderSourceFile.fromJson(result);
  }

  static String getWorkOrderSourceFileDownloadUrl(String fileId) {
    if (fileId.isEmpty) {
      return '';
    }
    return resolveServerUrl(ApiPaths.workOrderSourceFileDownload(fileId));
  }

  static Future<String> deleteWorkOrderSourceFile(String fileId) async {
    return _callMessage(
      apiNameForLog: 'deleteWorkOrderSourceFile',
      subPath: ApiPaths.workOrderSourceFile(fileId),
      method: 'delete',
      postParameters: const {},
      fallbackMessage: 'Source PDF deleted.',
    );
  }

  static Future<EmailBatchCreateResult> createEmailBatch({
    required List<String> workOrderIds,
    required List<String> toEmails,
    String? subject,
    String? bodyHtml,
    String? bodyText,
  }) async {
    final result = await _callJsonMap(
      apiNameForLog: 'createEmailBatch',
      subPath: ApiPaths.emailBatches,
      method: 'post',
      postParameters: {
        'work_order_ids': workOrderIds,
        'to_emails': toEmails,
        if (subject != null && subject.isNotEmpty) 'subject': subject,
        if (bodyHtml != null && bodyHtml.isNotEmpty) 'body_html': bodyHtml,
        if (bodyText != null && bodyText.isNotEmpty) 'body_text': bodyText,
      },
      successStatusCodes: const [201],
    );
    return EmailBatchCreateResult.fromJson(result);
  }

  static Future<EmailBatchListResult> listEmailBatches({
    String? status,
    int? limit,
    int? offset,
  }) async {
    final result = await _callJsonMap(
      apiNameForLog: 'listEmailBatches',
      subPath: ApiPaths.emailBatches,
      method: 'get',
      postParameters: const {},
      queryParameters: {
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
        if (limit != null) 'limit': limit,
        if (offset != null) 'offset': offset,
      },
    );
    return EmailBatchListResult.fromJson(result);
  }

  static Future<EmailBatchDetail> getEmailBatchById(String batchId) async {
    final result = await _callJsonMap(
      apiNameForLog: 'getEmailBatchById',
      subPath: ApiPaths.emailBatchById(batchId),
      method: 'get',
      postParameters: const {},
    );
    return EmailBatchDetail.fromJson(result);
  }

  static Future<EmailBatchSendResult> sendEmailBatch(String batchId) async {
    final result = await _callJsonMap(
      apiNameForLog: 'sendEmailBatch',
      subPath: ApiPaths.sendEmailBatch(batchId),
      method: 'post',
      postParameters: const {},
      successStatusCodes: const [200, 201],
    );
    return EmailBatchSendResult.fromJson(result);
  }

  static Future<String> removeEmailBatchItem(
    String batchId,
    String workOrderId,
  ) async {
    return _callMessage(
      apiNameForLog: 'removeEmailBatchItem',
      subPath: ApiPaths.emailBatchItem(batchId, workOrderId),
      method: 'delete',
      postParameters: const {},
      fallbackMessage: 'Item removed from batch.',
    );
  }

  static Future<WorkOrderEmailHistoryResult> getWorkOrderEmailHistory(
    String workOrderId,
  ) async {
    final result = await _callJsonMap(
      apiNameForLog: 'getWorkOrderEmailHistory',
      subPath: ApiPaths.workOrderEmails(workOrderId),
      method: 'get',
      postParameters: const {},
    );
    return WorkOrderEmailHistoryResult.fromJson(result);
  }

  static Future<WorkOrderHistoryResponse> getWorkOrderHistory(
    String workOrderId,
  ) async {
    final result = await _callJsonMap(
      apiNameForLog: 'getWorkOrderHistory',
      subPath: ApiPaths.workOrderHistory(workOrderId),
      method: 'get',
      postParameters: const {},
    );
    return WorkOrderHistoryResponse.fromJson(result);
  }

  static Future<WorkOrderForm> createWorkOrderForm(
    String workOrderId,
    String templateId,
  ) async {
    final result = await _callJsonMap(
      apiNameForLog: 'createWorkOrderForm',
      subPath: ApiPaths.workOrderForm(workOrderId),
      method: 'post',
      postParameters: {'templateId': templateId},
      successStatusCodes: const [201],
    );
    return WorkOrderForm.fromJson(result);
  }

  static Future<WorkOrderForm> getWorkOrderForm(String workOrderId) async {
    final result = await _callJsonMap(
      apiNameForLog: 'getWorkOrderForm',
      subPath: ApiPaths.workOrderForm(workOrderId),
      method: 'get',
      postParameters: const {},
    );
    return WorkOrderForm.fromJson(result);
  }

  static Future<WorkOrderForm> saveWorkOrderFormDraft(
    String workOrderId,
    Map<String, dynamic> dataJson,
  ) async {
    final result = await _callJsonMap(
      apiNameForLog: 'saveWorkOrderFormDraft',
      subPath: ApiPaths.workOrderForm(workOrderId),
      method: 'put',
      postParameters: {'data_json': dataJson},
    );
    return WorkOrderForm.fromJson(result);
  }

  static Future<String> submitWorkOrderForm(
    String workOrderId, {
    Map<String, dynamic>? dataJson,
  }) async {
    return _callMessage(
      apiNameForLog: 'submitWorkOrderForm',
      subPath: ApiPaths.submitWorkOrderForm(workOrderId),
      method: 'post',
      postParameters: {if (dataJson != null) 'data_json': dataJson},
      fallbackMessage: 'Form submitted.',
    );
  }

  static Future<String> updateWorkOrderForm(
    String workOrderId, {
    required Map<String, dynamic> dataJson,
  }) async {
    return _callMessage(
      apiNameForLog: 'updateWorkOrderForm',
      subPath: ApiPaths.updateWorkOrderForm(workOrderId),
      method: 'post',
      postParameters: {'data_json': dataJson},
      fallbackMessage: 'Form updated.',
    );
  }

  static Future<WorkOrderFormSignResult> signWorkOrderForm(
    String workOrderId, {
    required Uint8List signatureBytes,
    String signedName = '',
    Map<String, dynamic>? dataJson,
    String filename = 'signature.png',
  }) async {
    WorkOrderFormSignResult output = WorkOrderFormSignResult();

    try {
      final files = <ApiMultipartFile>[
        ApiMultipartFile(
          fieldName: 'signature',
          bytes: signatureBytes,
          filename: filename,
          contentType: 'image/png',
        ),
      ];

      final fields = <String, String>{};
      if (signedName.trim().isNotEmpty) {
        fields['signed_name'] = signedName.trim();
      }
      if (dataJson != null) {
        fields['data_json'] = jsonEncode(dataJson);
      }

      await ApiAction.callMultipartAPI(
        'signWorkOrderForm',
        ApiPaths.signWorkOrderForm(workOrderId),
        {},
        files: files,
        fields: fields,
        dataHandlingCallback: (data) {
          output = WorkOrderFormSignResult.fromJson(data);
          if (output.message.trim().isEmpty) {
            output.message = 'Form signed.';
          }
        },
        failAction: () {
          log('Sign work order form API call failed');
        },
      );
    } catch (e) {
      log('Exception during signWorkOrderForm API call: $e');
      output.message = '$e';
    }

    return output;
  }

  static Future<String> adminEditWorkOrderForm(
    String workOrderId, {
    required Map<String, dynamic> dataJson,
    required String reason,
  }) async {
    return _callMessage(
      apiNameForLog: 'adminEditWorkOrderForm',
      subPath: ApiPaths.editWorkOrderForm(workOrderId),
      method: 'post',
      postParameters: {'data_json': dataJson, 'reason': reason},
      fallbackMessage: 'Form edited.',
    );
  }

  static Future<String> addWorkOrderFormRemark(
    String workOrderId, {
    required String fieldKey,
    required String remark,
    required String reason,
  }) async {
    return _callMessage(
      apiNameForLog: 'addWorkOrderFormRemark',
      subPath: ApiPaths.remarkWorkOrderForm(workOrderId),
      method: 'post',
      postParameters: {
        'field_key': fieldKey,
        'remark': remark,
        'reason': reason,
      },
      fallbackMessage: 'Remark added.',
    );
  }

  static Future<String> regenerateWorkOrderFormPdf(String workOrderId) async {
    return _callMessage(
      apiNameForLog: 'regenerateWorkOrderFormPdf',
      subPath: ApiPaths.regenerateWorkOrderFormPdf(workOrderId),
      method: 'post',
      postParameters: const {},
      fallbackMessage: 'PDF regenerated.',
    );
  }

  static Future<AdminEmailLogList> listAdminEmailLogs({
    String? q,
    String? template,
    String? status,
    int? limit,
    int? offset,
  }) async {
    final result = await _callJsonMap(
      apiNameForLog: 'listAdminEmailLogs',
      subPath: ApiPaths.adminEmailLogs,
      method: 'get',
      postParameters: const {},
      queryParameters: {
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (template != null && template.trim().isNotEmpty)
          'template': template.trim(),
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
        if (limit != null) 'limit': limit,
        if (offset != null) 'offset': offset,
      },
    );
    return AdminEmailLogList.fromJson(result);
  }

  static Future<AdminEmailLog> getAdminEmailLogById(String logId) async {
    final result = await _callJsonMap(
      apiNameForLog: 'getAdminEmailLogById',
      subPath: ApiPaths.adminEmailLogById(logId),
      method: 'get',
      postParameters: const {},
    );
    return AdminEmailLog.fromJson(result);
  }

  static Future<AdminPingResult> adminPing() async {
    final result = await _callJsonMap(
      apiNameForLog: 'adminPing',
      subPath: ApiPaths.adminPing,
      method: 'get',
      postParameters: const {},
    );
    return AdminPingResult.fromJson(result);
  }

  static Future<HousekeepingRunResult> runOpsHousekeeping() async {
    final result = await _callJsonMap(
      apiNameForLog: 'runOpsHousekeeping',
      subPath: ApiPaths.runHousekeeping,
      method: 'post',
      postParameters: const {},
    );
    return HousekeepingRunResult.fromJson(result);
  }

  static Future<SessionList> getActiveSessions() async {
    final payload = await _callJsonMap(
      apiNameForLog: 'getActiveSessions',
      subPath: ApiPaths.sessions,
      method: 'get',
      postParameters: const {},
    );
    return SessionList.fromJson(payload);
  }

  static Future<String> revokeSession(String sessionId) async {
    return _callMessage(
      apiNameForLog: 'revokeSession',
      subPath: ApiPaths.revokeSession(sessionId),
      method: 'post',
      postParameters: const {},
    );
  }

  static Future<int> revokeAllSessions({bool includeCurrent = false}) async {
    int revoked = 0;

    try {
      await ApiAction.callAPI(
        'revokeAllSessions',
        ApiPaths.revokeAllSessions,
        {},
        {'include_current': includeCurrent},
        'post',
        (data) {
          revoked = data['revoked'] is int
              ? data['revoked'] as int
              : int.tryParse('${data['revoked'] ?? 0}') ?? 0;
        },
        (data) {
          log('Revoke all sessions API call failed ${data['message'] ?? ''}');
        },
      );
    } catch (e) {
      log('Exception during revokeAllSessions API call: $e');
    }

    return revoked;
  }

  static Future<String> requestEmailVerification() async {
    return _callMessage(
      apiNameForLog: 'requestEmailVerification',
      subPath: ApiPaths.requestVerifyEmail,
      method: 'post',
      postParameters: const {},
    );
  }

  static Future<String> confirmEmailVerification(String verifyToken) async {
    return _callMessage(
      apiNameForLog: 'confirmEmailVerification',
      subPath: ApiPaths.confirmVerifyEmail,
      method: 'post',
      postParameters: {'verify_token': verifyToken},
      requireLogin: false,
      fallbackMessage: 'Email verification completed.',
    );
  }

  static Future<Map<String, dynamic>> _callJsonMap({
    required String apiNameForLog,
    required String subPath,
    required String method,
    required Object postParameters,
    bool requireLogin = true,
    bool showError = true,
    Map<String, dynamic> queryParameters = const {},
    List<int> successStatusCodes = const [200],
  }) async {
    Map<String, dynamic> output = {};

    try {
      await ApiAction.callAPI(
        apiNameForLog,
        subPath,
        queryParameters,
        postParameters,
        method,
        (data) {
          output = Map<String, dynamic>.from(data);
        },
        (data) {
          log(
            '$apiNameForLog API call failed ${_extractApiErrorMessage(data)}',
          );
          output = Map<String, dynamic>.from(data);
        },
        requireLogin: requireLogin,
        showError: showError,
        successStatusCodes: successStatusCodes,
      );
    } catch (e) {
      log('Exception during $apiNameForLog API call: $e');
    }

    return output;
  }

  static Future<String> _callMessage({
    required String apiNameForLog,
    required String subPath,
    required String method,
    required Object postParameters,
    bool requireLogin = true,
    Map<String, dynamic> queryParameters = const {},
    List<int> successStatusCodes = const [200],
    String fallbackMessage = '',
  }) async {
    String output = fallbackMessage;

    try {
      await ApiAction.callAPI(
        apiNameForLog,
        subPath,
        queryParameters,
        postParameters,
        method,
        (data) {
          final message = _extractApiErrorMessage(data);
          log(message.isEmpty ? 'No message in response' : message);
          output = (message.isNotEmpty ? message : fallbackMessage).trim();
        },
        (data) {
          final message = _extractApiErrorMessage(data);
          log('$apiNameForLog API call failed $message');
          output = 'Failed. ${message.isNotEmpty ? message : fallbackMessage}'
              .trim();
        },
        requireLogin: requireLogin,
        successStatusCodes: successStatusCodes,
      );
    } catch (e) {
      log('Exception during $apiNameForLog API call: $e');
      output = fallbackMessage.isNotEmpty ? fallbackMessage : '$e';
    }

    return output;
  }
}

class ApiAction {
  static bool _sessionExpiredDialogShowing = false;

  static Map<String, String> _buildHeaders({
    Map<String, String>? customHeaders,
    required bool requireLogin,
    bool isMultipart = false,
  }) {
    final headers =
        customHeaders ??
        (requireLogin
            ? {
                if (!isMultipart)
                  'Content-type': 'application/json; charset=UTF-8',
                'Accept': '*/*',
                'Authorization':
                    'Bearer ${LoginSessionController.instance.loginInfo.accessToken}',
              }
            : {
                if (!isMultipart)
                  'Content-type': 'application/json; charset=UTF-8',
                'Accept': '*/*',
              });

    if (!kIsWeb) {
      String deviceID = DeviceInfoController.instance.getDeviceId();
      if (deviceID.isNotEmpty) {
        headers["deviceID"] = deviceID;
      }

      headers["appVersion"] = DeviceInfoController.instance.getAppVersion();
      headers["platform"] = DeviceInfoController.instance.getPlatform();
      headers["osVersion"] = DeviceInfoController.instance.getOSVersion();
      headers["manufacturer"] = DeviceInfoController.instance.getManufacturer();
      headers["model"] = DeviceInfoController.instance.getModel();
      headers["networkType"] = DeviceInfoController.instance.getNetworkType();
    }

    return headers;
  }

  static Uri _buildDefaultUri(
    String subPath,
    Map<String, dynamic> queryParameters,
  ) {
    if (kIsWeb && ApiPaths.server.useWebProxy) {
      return Uri(
        path: subPath,
        queryParameters: queryParameters.isEmpty
            ? null
            : queryParameters.map(
                (key, value) => MapEntry(key, value.toString()),
              ),
      );
    }

    return _buildUri(
      ApiPaths.server.host,
      subPath,
      queryParameters: queryParameters,
      port: ApiPaths.server.port,
      useHttps: ApiPaths.server.useHttps,
    );
  }

  static Uri _buildUri(
    String host,
    String subPath, {
    Map<String, dynamic> queryParameters = const {},
    int? port,
    bool useHttps = false,
  }) {
    return Uri(
      scheme: useHttps ? 'https' : 'http',
      host: host,
      port: port,
      path: subPath,
      queryParameters: queryParameters.isEmpty
          ? null
          : queryParameters.map(
              (key, value) => MapEntry(key, value.toString()),
            ),
    );
  }

  static Uri _buildUriFromBasePath(
    String basePath,
    String subPath,
    Map<String, dynamic> queryParameters,
  ) {
    final parsedBase = Uri.parse(basePath);
    if (parsedBase.hasScheme) {
      return parsedBase.replace(
        path: subPath,
        queryParameters: queryParameters.isEmpty
            ? null
            : queryParameters.map(
                (key, value) => MapEntry(key, value.toString()),
              ),
      );
    }

    final parts = basePath.split(':');
    final host = parts.first;
    final port = parts.length > 1 ? int.tryParse(parts[1]) : null;
    return _buildUri(
      host,
      subPath,
      queryParameters: queryParameters,
      port: port,
      useHttps: ApiPaths.server.useHttps,
    );
  }

  static Future<bool> callAPI(
    String apiNameForLog,
    String subPath,
    Map<String, dynamic> queryParameters,
    // Map<dynamic, dynamic> postParameters,
    Object postParameters,
    String method,
    Function(dynamic) dataHandlingCallback,
    Function(dynamic) failAction, {
    Map<String, String>? customHeaders,
    bool requireLogin = true,
    bool showError = true,
    bool isFullPath = false,
    String basePath = "",
    List<int> successStatusCodes = const [200],
  }) async {
    await DeviceInfoController.instance
        .init(); //try init the device info once again

    try {
      if (requireLogin) {
        await LoginSessionController.instance
            .refreshTokenIfNeeded(); //Try refresh token if needed before every API call that requires login

        if (!LoginSessionController.instance.isLoggedIn()) {
          callAPIFail(
            apiNameForLog,
            "Login session expired.",
            "Please sign in again.",
            true,
          );
          return false;
        }
      }

      Map<String, String> headers = _buildHeaders(
        customHeaders: customHeaders,
        requireLogin: requireLogin,
      );

      final url = isFullPath
          ? _buildUriFromBasePath(basePath, subPath, queryParameters)
          : _buildDefaultUri(subPath, queryParameters);

      http.Response? response;

      Duration? timeLimit = (AppConfig.instance.apiTimeoutLimit > 0)
          ? Duration(seconds: AppConfig.instance.apiTimeoutLimit)
          : null;

      log(
        // "Calling API: $method $url with headers: $headers and body: $postParameters, timeout: ${timeLimit?.inSeconds}s",
        "Calling API: $method $url and body: $postParameters",
      );

      switch (method.toLowerCase()) {
        case "get":
          if (timeLimit != null) {
            response = await http.get(url, headers: headers).timeout(timeLimit);
          } else {
            response = await http.get(url, headers: headers);
          }
          break;
        case "post":
          // log("post parameters: ${json.encode(postParameters)}");
          if (timeLimit != null) {
            response = await http
                .post(
                  url,
                  headers: headers,
                  encoding: Encoding.getByName("utf-8"),
                  body: json.encode(postParameters),
                )
                .timeout(timeLimit);
          } else {
            response = await http.post(
              url,
              headers: headers,
              encoding: Encoding.getByName("utf-8"),
              body: json.encode(postParameters),
            );
          }
          break;
        case "put":
          if (timeLimit != null) {
            response = await http
                .put(
                  url,
                  headers: headers,
                  encoding: Encoding.getByName("utf-8"),
                  body: json.encode(postParameters),
                )
                .timeout(timeLimit);
          } else {
            response = await http.put(
              url,
              headers: headers,
              encoding: Encoding.getByName("utf-8"),
              body: json.encode(postParameters),
            );
          }
          break;
        case "patch":
          if (timeLimit != null) {
            response = await http
                .patch(
                  url,
                  headers: headers,
                  encoding: Encoding.getByName("utf-8"),
                  body: json.encode(postParameters),
                )
                .timeout(timeLimit);
          } else {
            response = await http.patch(
              url,
              headers: headers,
              encoding: Encoding.getByName("utf-8"),
              body: json.encode(postParameters),
            );
          }
          break;
        case "delete":
          if (timeLimit != null) {
            response = await http
                .delete(
                  url,
                  headers: headers,
                  encoding: Encoding.getByName("utf-8"),
                  body: json.encode(postParameters),
                )
                .timeout(timeLimit);
          } else {
            // log("post parameters: ${json.encode(postParameters)}");
            response = await http.delete(
              url,
              headers: headers,
              encoding: Encoding.getByName("utf-8"),
              body: json.encode(postParameters),
            );
          }
          break;

        default:
          if (showError) {
            callAPIFail(
              apiNameForLog,
              "Http method undefined: $method",
              "Calling URL: $url",
              true,
            );
          }
          return false;
      }

      // LogController.logAnalytic(
      //     logModuleName,
      //     "$apiNameForLog | URL: $subPath | query: $queryParameters | paramBody: $postParameters responseCode: ${response.statusCode} | body: ${response.body}",
      //     LogController.debug);

      log(
        "$apiNameForLog | URL: $subPath | query: $queryParameters | paramBody: $postParameters responseCode: ${response.statusCode} | body: ${response.body}",
      );

      if (successStatusCodes.contains(response.statusCode)) {
        final dynamic decodedBody = response.body.isEmpty
            ? <String, dynamic>{}
            : json.decode(response.body);
        final bodyJSON = decodedBody is Map
            ? Map<dynamic, dynamic>.from(decodedBody)
            : <dynamic, dynamic>{'data': decodedBody};
        await dataHandlingCallback(bodyJSON);
        return true;
      } else {
        // callAPIFail(
        //   apiNameForLog,
        //   "Server is not ready (response code: ${response.statusCode})",
        //   // "server response: ${response.body}",
        //   "",
        //   "Please contact technical support",
        //   true,
        // );
        final dynamic decodedBody = response.body.isEmpty
            ? <String, dynamic>{}
            : json.decode(response.body);
        final bodyJSON = decodedBody is Map
            ? Map<String, dynamic>.from(decodedBody)
            : <String, dynamic>{'data': decodedBody};

        if (showError) {
          final formattedError = ApiController._formatApiErrorSummary(bodyJSON);
          callAPIFail(
            apiNameForLog,
            "Api call fail: (${response.statusCode})",
            formattedError,
            false,
          );
        }
        await failAction(bodyJSON);
        return false;
      }
    } catch (e) {
      callAPIFail(
        apiNameForLog,
        "Exception happened during API call: $e",
        e.toString(),
        true,
      );
      await failAction({});
      return false;
    }
  }

  static Future<bool> callMultipartAPI(
    String apiNameForLog,
    String subPath,
    Map<String, dynamic> queryParameters, {
    required List<ApiMultipartFile> files,
    Map<String, String> fields = const {},
    required Function(Map<dynamic, dynamic>) dataHandlingCallback,
    required Function() failAction,
    Map<String, String>? customHeaders,
    bool requireLogin = true,
    bool showError = true,
    bool isFullPath = false,
    String basePath = "",
    List<int> successStatusCodes = const [200],
  }) async {
    await DeviceInfoController.instance.init();

    try {
      if (requireLogin) {
        await LoginSessionController.instance.refreshTokenIfNeeded();

        if (!LoginSessionController.instance.isLoggedIn()) {
          callAPIFail(
            apiNameForLog,
            "Login session expired.",
            "Please sign in again.",
            true,
          );
          return false;
        }
      }

      final headers = _buildHeaders(
        customHeaders: customHeaders,
        requireLogin: requireLogin,
        isMultipart: true,
      );

      final url = isFullPath
          ? _buildUriFromBasePath(basePath, subPath, queryParameters)
          : _buildDefaultUri(subPath, queryParameters);

      final request = http.MultipartRequest('POST', url);
      request.headers.addAll(headers);
      request.fields.addAll(fields);
      for (final file in files) {
        request.files.add(
          http.MultipartFile.fromBytes(
            file.fieldName,
            file.bytes,
            filename: file.filename,
            contentType: file.contentType == null
                ? null
                : MediaType.parse(file.contentType!),
          ),
        );
      }

      log(
        "Calling multipart API: POST $url with headers: $headers, fields: $fields, files: ${files.map((file) => file.fieldName).toList()}",
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      log(
        "$apiNameForLog | URL: $subPath | query: $queryParameters | multipart responseCode: ${response.statusCode} | body: ${response.body}",
      );

      if (successStatusCodes.contains(response.statusCode)) {
        final dynamic decodedBody = response.body.isEmpty
            ? <String, dynamic>{}
            : json.decode(response.body);
        final bodyJSON = decodedBody is Map
            ? Map<dynamic, dynamic>.from(decodedBody)
            : <dynamic, dynamic>{'data': decodedBody};
        await dataHandlingCallback(bodyJSON);
        return true;
      }

      if (showError) {
        final dynamic decodedBody = response.body.isEmpty
            ? <String, dynamic>{}
            : json.decode(response.body);
        final bodyJSON = decodedBody is Map
            ? Map<String, dynamic>.from(decodedBody)
            : <String, dynamic>{'data': decodedBody};
        final formattedError = ApiController._formatApiErrorSummary(bodyJSON);

        callAPIFail(
          apiNameForLog,
          "Api call fail: (${response.statusCode})",
          formattedError,
          false,
        );
      }

      await failAction();
      return false;
    } catch (e) {
      callAPIFail(
        apiNameForLog,
        "Exception happened during multipart API call: $e",
        e.toString(),
        true,
      );
      await failAction();
      return false;
    }
  }

  static void callAPIFail(
    String apiNameForLog,
    String programIssueDesc,
    String infoForDebug,
    // String suggestionToUser,
    bool goHomeAfterTapOK,
  ) {
    goHomeAfterTapOK = false; //Should not go home
    String reason = "";

    if (programIssueDesc.isNotEmpty) {
      reason = programIssueDesc;
    }
    if (infoForDebug.isNotEmpty) {
      // reason = (reason.isEmpty ? infoForDebug : "$infoForDebug: ") + reason;
      reason = reason + (reason.isEmpty ? infoForDebug : "\n$infoForDebug");
    }

    // if (suggestionToUser.isNotEmpty) {
    //   reason =
    //       reason + (reason.isEmpty ? suggestionToUser : "\n$suggestionToUser");
    // }

    //Change to show a full screen later
    // Utils.showMessage(
    //     AppState.instance.context!,
    //     "",
    //     ErrorMessageController.getErrorMessage(
    //         AppState.instance.apiResult.reason));
    log("API call failed: $apiNameForLog, reason: $reason");

    if (apiNameForLog == 'userLogin') {
      _showLoginFailedDialog(reason);
      return;
    }

    if (_isSessionExpiredFailure(reason)) {
      _showSessionExpiredDialog(reason);
    }
  }

  static bool _isSessionExpiredFailure(String reason) {
    final value = reason.toLowerCase();
    if (value.isEmpty) {
      return false;
    }

    const sessionKeywords = [
      'token revoked',
      'refresh token revoked',
      'access token revoked',
      'token expired',
      'refresh token expired',
      'access token expired',
      'jwt expired',
      'unauthorized',
      'invalid token',
      'invalid refresh token',
      'session expired',
      'login expired',
      'not login yet',
      'not logged in',
      'forbidden',
      '401',
      '403',
    ];

    return sessionKeywords.any(value.contains);
  }

  static void _showSessionExpiredDialog(String reason) {
    if (_sessionExpiredDialogShowing) {
      return;
    }

    final navigator = MyApp.navigatorKey.currentState;
    final context = MyApp.navigatorKey.currentContext;
    if (navigator == null || context == null) {
      return;
    }

    _sessionExpiredDialogShowing = true;
    LoginSessionController.instance.logoutLocally(resetLoginInfo: true);

    final message = ApiController._extractApiErrorMessage(reason).isNotEmpty
        ? ApiController._extractApiErrorMessage(reason)
        : 'Your login session has expired. Please sign in again.';

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Please sign in again'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                navigator.pushNamedAndRemoveUntil('/login', (route) => false);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    ).whenComplete(() {
      _sessionExpiredDialogShowing = false;
    });
  }

  static void _showLoginFailedDialog(String reason) {
    final context = MyApp.navigatorKey.currentContext;
    if (context == null) {
      return;
    }

    final message = ApiController._extractApiErrorMessage(reason).isNotEmpty
        ? ApiController._extractApiErrorMessage(reason)
        : 'Login failed. Please check your username and password.';

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Login failed'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}

class ApiMultipartFile {
  const ApiMultipartFile({
    required this.fieldName,
    required this.bytes,
    required this.filename,
    this.contentType,
  });

  final String fieldName;
  final Uint8List bytes;
  final String filename;
  final String? contentType;
}
