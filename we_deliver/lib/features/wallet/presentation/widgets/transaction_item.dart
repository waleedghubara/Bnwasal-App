import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/transaction_entity.dart';

class TransactionItem extends StatelessWidget {
  final TransactionEntity transaction;

  const TransactionItem({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isDeposit = transaction.type == 'deposit';
    
    // Status resolution
    Color statusColor;
    String statusText;
    switch (transaction.status) {
      case 'success':
        statusColor = Colors.green;
        statusText = 'ناجحة';
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'قيد المراجعة';
        break;
      case 'failed':
      default:
        statusColor = Colors.red;
        statusText = 'ملغية';
        break;
    }

    // Type styling
    final IconData icon = isDeposit 
        ? Icons.arrow_downward_rounded 
        : Icons.arrow_upward_rounded;
    final Color typeColor = isDeposit ? Colors.green : Colors.red;
    final Color typeBgColor = isDeposit ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);
    
    // Amount prefix and style
    final amountPrefix = isDeposit ? '+' : '-';
    final Color amountColor = transaction.status == 'failed' 
        ? Colors.grey 
        : typeColor;
    final textStyle = TextStyle(
      color: amountColor,
      fontSize: 14.sp,
      fontWeight: FontWeight.bold,
      decoration: transaction.status == 'failed' ? TextDecoration.lineThrough : null,
    );

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF5F5F5)),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: typeBgColor,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(
              icon,
              color: typeColor,
              size: 20.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: GoogleFonts.tajawal(
                    color: Colors.black,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  transaction.date,
                  style: TextStyle(
                    color: const Color(0xFF9E9E9E),
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$amountPrefix${transaction.amount.toStringAsFixed(2)} ج.م',
                style: textStyle,
                textDirection: TextDirection.ltr,
              ),
              SizedBox(height: 4.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  statusText,
                  style: GoogleFonts.tajawal(
                    color: statusColor,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
