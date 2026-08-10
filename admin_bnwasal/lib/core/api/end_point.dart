class EndPoint {
  static const String markRead = 'notifications/mark_read.php';

  static const String baseUrl = "https://bnwasal.com/api/";

  static const String imageBaseUrl = "https://bnwasal.com";

  static String getCleanImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    String clean = path;
    if (clean.startsWith('file://')) {
      clean = clean.replaceFirst(RegExp(r'^file://+'), '');
    }
    if (!clean.startsWith('/')) {
      clean = '/$clean';
    }
    final baseUrl = imageBaseUrl.endsWith('/')
        ? imageBaseUrl.substring(0, imageBaseUrl.length - 1)
        : imageBaseUrl;
    return '$baseUrl$clean';
  }
  // Auth Endpoints
  static const String register = 'auth/register';
  static const String login = 'auth/login';
  static const String adminLogin = 'auth/admin-login';
  static const String verifyOtp = 'auth/verify-otp';
  static const String resendOtp = 'auth/resend-otp';
  static const String getProfile = 'auth/profile';
  static const String updateProfile = 'auth/profile';
  static const String changePassword = 'auth/change-password';
  static const String refreshToken = 'auth/refresh-token';
  static const String logout = 'auth/logout';
  static const String uploadDriverDocuments = 'auth/driver/upload-documents';
  static const String forgotPassword = 'auth/forgot-password';
  static const String verifyResetOtp = 'auth/verify-reset-otp';
  static const String resetPassword = 'auth/reset-password';

  // Shipment Endpoints
  static const String createShipment = 'shipments';
  static const String getShipments = 'shipments';

  // Order Endpoints
  static const String createOrder = 'orders';
  static const String getOrders = 'orders';
  static String updateOrderStatus(String orderId) => 'orders/$orderId/status';
  static String updateShipmentStatus(String shipmentId) =>
      'shipments/$shipmentId/status';
  static String getOrderById(String orderId) => 'orders/$orderId';
  static String claimOrder(String id) => 'orders/$id/claim';
  static String claimShipment(String id) => 'shipments/$id/claim';

  // Notifications Endpoints
  static const String getNotifications = 'notifications';
  static String markNotificationRead(String id) => 'notifications/$id/read';
  static const String markAllNotificationsRead = 'notifications/read-all';
  static String deleteNotification(String id) => 'notifications/$id';
  static const String clearAllNotifications = 'notifications/clear-all';
  static const String sendBulkNotification = 'notifications/send';

  // Trips Endpoints
  static const String getTrips = 'trips';
  static const String createTrip = 'trips';
  static String updateTrip(String id) => 'trips/$id';
  static String deleteTrip(String id) => 'trips/$id';

  // Referral Endpoints
  static const String referralSummary = 'referrals/summary';

  // Support Endpoints
  static const String contactUs = 'support/contact';
  static const String supportChat = 'support/chat';
  static const String supportThreads = 'support/threads';

  static const String adminDashboard = 'admin/dashboard';
  static const String adminAllOrdersShipments = 'admin/all-orders-shipments';

  static const String adminMerchants = 'admin/merchants';
  static const String adminCaptains = 'admin/captains';
  static const String adminTrips = 'admin/trips';
  static const String adminPendingAccounts = 'admin/pending-accounts';
  static const String adminEmployees = 'admin/employees';
  static const String adminWithdrawals = 'admin/withdrawals';
  static const String adminWalletTransactions = 'admin/wallet/transactions';
  static const String adminWalletUsers = 'admin/wallet/users';
  static const String adminWalletSummary = 'admin/wallet/summary';
  static const String adminWalletDeposit = 'admin/wallet/deposit';

  static const String socketUrl = "https://bnwasal.com";
  static const String updateFcmToken = "auth/fcm-token";
  static String shipmentMessages(String shipmentId) =>
      'shipments/$shipmentId/messages';

  // Negotiation, Payment & Dispatcher Endpoints
  static const String submitOffer = 'negotiation/offer';
  static const String acceptOffer = 'negotiation/accept';
  static const String rejectOffer = 'negotiation/reject';
  static const String sendNegotiationMessage = 'negotiation/message';
  static const String getNegotiationMessages = 'negotiation/messages';
  static const String availableCaptains = 'dispatcher/available-captains';
  static const String assignCaptain = 'dispatcher/assign';
  static const String payDelivery = 'payments/pay-delivery';
  static const String updateSettingKey = 'settings/update-key';

  static String confirmShipmentPickup(String id) =>
      'shipments/$id/confirm-pickup';
  static String confirmShipmentDelivery(String id) =>
      'shipments/$id/confirm-delivery';
  static String confirmOrderPickup(String id) => 'orders/$id/confirm-pickup';
  static String confirmOrderDelivery(String id) =>
      'orders/$id/confirm-delivery';

  // Pricing Endpoints
  static String computeOrderPricing(String id) => 'orders/$id/compute-pricing';
  static String computeShipmentPricing(String id) =>
      'shipments/$id/compute-pricing';

  // Direct Payment Endpoints
  static const String directPaymentsList = 'direct-payments/list';
  static const String directPaymentMethods = 'direct-payments/methods';
  static const String updateDirectPaymentMethods = 'direct-payments/methods';
  static String directPaymentReview(String id) => 'direct-payments/$id/review';
  static const String couponsAdmin = 'coupons/admin';
}

class ApiKey {
  static String id = 'id';
  static String token = 'token';
  static String message = 'message';
  static String status = 'status';
  static String errormessage = 'ErrorMessage';
  static String name = 'name';
  static String storeName = 'storeName';
  static String tradeType = 'tradeType';
  static String city = 'city';
  static String address = 'address';
  static String email = 'email';
  static String password = 'password';
  static String confirmPassword = 'confirmPassword';
  static String phone = 'phone';
  static String profileImage = 'profileImage';
  static String imageDocument = 'imageDocument';
  static String verifyotpphone = 'verifyotpphone';
  static String verifyotpemail = 'otp_code';
  static String oldPassword = 'Old_password';
  static String newPassword = 'New_password';
  static String count = 'count';
  static String nameAddFayah = 'nameaddFayah';
  static String vehicle = 'vehicle';
  static String plate = 'plate';
}
