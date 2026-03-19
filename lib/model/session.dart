import 'package:maintapp/common/data_helper.dart';

class Session {
  String id = '';
  String sessionId = '';
  String status = '';
  bool isCurrent = false;
  String createdAt = '';
  String lastActiveAt = '';
  String lastSeenAt = '';
  String ipAddress = '';
  String ip = '';
  String deviceName = '';
  String device = '';
  String userAgent = '';
  String userAgentRaw = '';
  Map<String, dynamic> raw = {};

  Session();

  Session.fromJson(Map<dynamic, dynamic> json) {
    raw = Map<String, dynamic>.from(json);
    sessionId = DataHelper.getStringSafely(json, 'session_id', '');
    id = DataHelper.getStringSafely(json, 'id', '');
    status = DataHelper.getStringSafely(json, 'status', '');
    isCurrent = DataHelper.getBoolSafely(json, 'is_current', false);
    createdAt = DataHelper.getStringSafely(json, 'created_at', '');
    lastActiveAt = DataHelper.getStringSafely(json, 'last_active_at', '');
    lastSeenAt = DataHelper.getStringSafely(json, 'last_seen_at', '');
    ipAddress = DataHelper.getStringSafely(json, 'ip_address', '');
    ip = DataHelper.getStringSafely(json, 'ip', '');
    deviceName = DataHelper.getStringSafely(json, 'device_name', '');
    device = DataHelper.getStringSafely(json, 'device', '');
    userAgent = DataHelper.getStringSafely(json, 'user_agent', '');
    userAgentRaw = DataHelper.getStringSafely(json, 'userAgent', '');
  }

  String get identifier =>
      sessionId.isNotEmpty ? sessionId : (id.isNotEmpty ? id : '');

  bool get isActive => status.toLowerCase() == 'active';

  String getLabel() {
    return deviceName.isNotEmpty
        ? deviceName
        : device.isNotEmpty
        ? device
        : userAgent.isNotEmpty
        ? userAgent
        : 'Unknown device';
  }

  String getIp() {
    return ipAddress.isNotEmpty ? ipAddress : ip;
  }

  String getUserAgent() {
    return userAgent.isNotEmpty ? userAgent : userAgentRaw;
  }

  String getLastActive() {
    return lastActiveAt.isNotEmpty ? lastActiveAt : lastSeenAt;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = Map<String, dynamic>.from(raw);
    data['id'] = id;
    data['session_id'] = sessionId;
    data['status'] = status;
    data['is_current'] = isCurrent;
    data['created_at'] = createdAt;
    data['last_active_at'] = lastActiveAt;
    data['last_seen_at'] = lastSeenAt;
    data['ip_address'] = ipAddress;
    data['ip'] = ip;
    data['device_name'] = deviceName;
    data['device'] = device;
    data['user_agent'] = userAgent;
    data['userAgent'] = userAgentRaw;
    return data;
  }
}

class SessionList {
  List<Session> items = [];
  int total = 0;
  int count = 0;

  SessionList({List<Session>? items, int? total, int? count}) {
    this.items = items ?? [];
    this.total = total ?? 0;
    this.count = count ?? 0;
  }

  SessionList.fromJson(Map<dynamic, dynamic> json) {
    final dynamic directItems =
        json['items'] ?? json['rows'] ?? json['sessions'];
    if (directItems is List) {
      items = directItems
          .whereType<Map<dynamic, dynamic>>()
          .map((sessionJson) => Session.fromJson(sessionJson))
          .toList();
    } else if (json['data'] is Map) {
      final dynamic nestedItems =
          json['data']['items'] ??
          json['data']['rows'] ??
          json['data']['sessions'];
      if (nestedItems is List) {
        items = nestedItems
            .whereType<Map<dynamic, dynamic>>()
            .map((sessionJson) => Session.fromJson(sessionJson))
            .toList();
      }
    }

    total = DataHelper.getIntSafely(json, 'total', items.length);
    count = DataHelper.getIntSafely(json, 'count', items.length);
    if ((total == 0 || count == 0) && items.isNotEmpty) {
      total = items.length;
      count = items.length;
    }

    if (total == 0 && count == 0 && items.isNotEmpty) {
      total = items.length;
      count = items.length;
    }

    if ((total == 0) && json['data'] is Map) {
      total = DataHelper.getIntSafely(json['data'], 'total', items.length);
    }
    if ((count == 0) && json['data'] is Map) {
      count = DataHelper.getIntSafely(json['data'], 'count', items.length);
    }
  }

  int get activeCount => items.where((session) => session.isActive).length;

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((session) => session.toJson()).toList(),
      'total': total,
      'count': count,
    };
  }
}
