import 'package:flutter/material.dart';

class PermissionDef {
  final String key;
  final String label;
  final IconData icon;
  const PermissionDef(this.key, this.label, this.icon);
}

class AllPermissions {
  static const List<PermissionDef> all = [
    PermissionDef('dashboard', 'الإحصائيات', Icons.dashboard_outlined),
    PermissionDef('merchants', 'التجار', Icons.store_outlined),
    PermissionDef('captains', 'الكباتن', Icons.person_pin_outlined),
    PermissionDef('trips', 'الرحلات', Icons.route_outlined),
    PermissionDef('orders', 'الطلبات', Icons.receipt_long_outlined),
    PermissionDef('users', 'المستخدمين', Icons.people_outline),
    PermissionDef('todayOrdersShipments', 'طلبات وشحنات اليوم', Icons.today_rounded),
    PermissionDef('todayTrips', 'الرحلات اليومية', Icons.route_rounded),
    PermissionDef('pendingAccounts', 'قبول الحسابات', Icons.person_add_outlined),
    PermissionDef('complaints', 'الشكاوى', Icons.feedback_outlined),
    PermissionDef('notifications', 'الإشعارات', Icons.notifications_outlined),
    PermissionDef('withdrawals', 'طلبات السحب', Icons.account_balance_wallet_outlined),
    PermissionDef('wallet', 'المحفظة العامة', Icons.account_balance_outlined),
    PermissionDef('userMessages', 'رسائل المستخدمين', Icons.email_outlined),
    PermissionDef('directPayments', 'دفعات الشحنات والطلبات', Icons.payments_outlined),
    PermissionDef('sendNotification', 'إرسال إشعار جماعي', Icons.send_rounded),
    PermissionDef('employees', 'إدارة الموظفين', Icons.badge_outlined),
    PermissionDef('settings', 'الإعدادات العامة', Icons.settings_outlined),
  ];
}
