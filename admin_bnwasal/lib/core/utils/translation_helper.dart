class TranslationHelper {
  static String getArabicStatus(String status) {
    status = status.trim();
    switch (status) {
      case 'Pending Review':
        return 'قيد المراجعة';
      case 'Ready For Assignment':
        return 'بانتظار تعيين مندوب';
      case 'Assigned To Captain':
      case 'Captain Arrived':
        return 'تم تعيين مندوب';
      case 'Picked Up':
        return 'تم شراء الطلب';
      case 'In Transit':
        return 'جارٍ التوصيل إليك';
      case 'Delivered':
        return 'تم التوصيل';
      case 'Completed':
        return 'مكتمل';
      case 'Cancelled':
        return 'ملغاة';
      case 'Rejected':
        return 'مرفوض';
      default:
        return status;
    }
  }
}
