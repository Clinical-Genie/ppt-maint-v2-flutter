import 'dart:developer';

import 'package:maintapp/api/api_controller.dart';
import 'package:maintapp/model/work_order.dart';
import 'package:maintapp/state/login_session_controller.dart';

class PostAuthNavigationService {
  const PostAuthNavigationService();

  static const PostAuthNavigationService instance = PostAuthNavigationService();

  Future<String?> activeWorkingWorkOrderId() async {
    try {
      final currentUserId = LoginSessionController.instance.userInfo.id.trim();
      final activeWorkOrders = await ApiController.listWorkOrders(
        user: 'me',
        status: 'working',
        pageSize: 1,
      );
      if (activeWorkOrders.items.isEmpty) return null;

      final WorkOrder activeWorkOrder = activeWorkOrders.items.first;
      final ownerUserId = activeWorkOrder.ownerUserId.trim();
      if (activeWorkOrder.id.trim().isEmpty ||
          ownerUserId.isEmpty ||
          currentUserId.isEmpty ||
          ownerUserId != currentUserId) {
        return null;
      }
      return activeWorkOrder.id;
    } catch (error, stackTrace) {
      log('Active working work-order lookup failed: $error');
      log(stackTrace.toString());
      return null;
    }
  }
}
