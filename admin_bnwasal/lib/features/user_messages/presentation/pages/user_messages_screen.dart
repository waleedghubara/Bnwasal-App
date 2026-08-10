// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:admin_bnwasal/core/theme/colors.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../cubit/user_messages_cubit.dart';
import '../cubit/user_messages_state.dart';
import '../../../../core/utils/text_sanitizer.dart';


class UserMessagesScreen extends StatefulWidget {
  const UserMessagesScreen({super.key});

  @override
  State<UserMessagesScreen> createState() => _UserMessagesScreenState();
}

class _UserMessagesScreenState extends State<UserMessagesScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<UserMessagesCubit>().loadMessages();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 950;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: BlocConsumer<UserMessagesCubit, UserMessagesState>(
        listener: (context, state) {
          if (state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.successMessage!,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
            context.read<UserMessagesCubit>().clearMessages();
          }
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.error!,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
            context.read<UserMessagesCubit>().clearMessages();
          }
        },
        builder: (context, state) {
          final filteredMessages = state.messages.where((msg) {
            final sourceMatch = state.sourceFilter == 'all' ||
                (msg['source'] ?? 'app').toString() == state.sourceFilter;
            if (!sourceMatch) return false;
            final query = state.searchQuery.trim().toLowerCase();
            if (query.isEmpty) return true;
            final name = (msg['name'] ?? '').toString().toLowerCase();
            final email = (msg['email'] ?? '').toString().toLowerCase();
            final subject = (msg['subject'] ?? '').toString().toLowerCase();
            final content = (msg['message'] ?? '').toString().toLowerCase();
            return name.contains(query) ||
                email.contains(query) ||
                subject.contains(query) ||
                content.contains(query);
          }).toList();

          final isDark = Theme.of(context).brightness == Brightness.dark;
          if (isWide) {
            // Desktop Split Layout
            return Scaffold(
              backgroundColor: isDark ? const Color(0xFF0a0a1a) : const Color(0xFFf8f9fa),
              body: Row(
                children: [
                  // Left/List Pane
                  Container(
                    width: 350.w,
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade300),
                      ),
                      color: isDark ? const Color(0xFF0b0b1e) : Colors.white,
                    ),
                    child: _buildMessagesListColumn(state, filteredMessages, isWide),
                  ),
                  // Right/Details Pane
                  Expanded(
                    child: state.selectedMessage == null
                        ? _buildNoSelectedMessagePlaceholder()
                        : _buildMessageDetailsPane(state.selectedMessage!, state.isDeleting),
                  ),
                ],
              ),
            );
          } else {
            // Mobile Stack Layout (if message selected, push detail page or show dialog)
            return Scaffold(
              backgroundColor: isDark ? const Color(0xFF0a0a1a) : const Color(0xFFf8f9fa),
              body: _buildMessagesListColumn(state, filteredMessages, isWide),
            );
          }
        },
      ),
    );
  }

  Widget _buildMessagesListColumn(
    UserMessagesState state,
    List<Map<String, dynamic>> messages,
    bool isWide,
  ) {
    return Column(
      children: [
        _buildHeader(),
        _buildSearchBar(),
        _buildSourceFilter(state),
        Expanded(
          child: state.isLoading && messages.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.secondary),
                )
              : messages.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 8.h,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (_, i) {
                        final msg = messages[i];
                        final isSelected = state.selectedMessage != null && state.selectedMessage!['id'] == msg['id'];
                        return _buildMessageCard(msg, isSelected, isWide);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'رسائل تواصل المستخدمين',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                'طلبات واستفسارات الزوار والعملاء من نموذج تواصل معنا',
                style: TextStyle(
                  fontSize: 10.sp,
                  color: isDark ? Colors.white.withOpacity(0.4) : Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade300),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
        decoration: InputDecoration(
          icon: Icon(Icons.search_rounded, color: isDark ? Colors.white70 : Colors.black45, size: 18),
          hintText: 'البحث بالاسم، العنوان، المحتوى...',
          hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 11.sp),
          fillColor: Colors.transparent,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10.h),
        ),
        onChanged: (val) {
          context.read<UserMessagesCubit>().setSearchQuery(val);
        },
      ),
    );
  }

  Widget _buildSourceFilter(UserMessagesState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const filters = ['all', 'website', 'app'];
    final labels = ['الكل', 'الموقع الإلكتروني', 'التطبيق'];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      child: Row(
        children: List.generate(filters.length, (i) {
          final selected = state.sourceFilter == filters[i];
          return Padding(
            padding: EdgeInsetsDirectional.only(end: 8.w),
            child: GestureDetector(
              onTap: () => context.read<UserMessagesCubit>().setSourceFilter(filters[i]),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: selected ? AppColors.secondary.withOpacity(0.15) : (isDark ? Colors.white.withOpacity(0.02) : Colors.white),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? AppColors.secondary.withOpacity(0.4) : (isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade300),
                  ),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: selected ? AppColors.secondary : (isDark ? Colors.white.withOpacity(0.5) : Colors.black54),
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMessageCard(
    Map<String, dynamic> msg,
    bool isSelected,
    bool isWide,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = msg['name'] ?? '';
    final subject = msg['subject'] ?? '';
    final snippet = msg['message'] ?? '';
    final timeStr = msg['createdAt'] != null ? _fmtDate(msg['createdAt'].toString()) : '';
    final isRegistered = msg['userId'] != null;

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.secondary.withOpacity(0.2) : (isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade300),
        ),
        gradient: LinearGradient(
          colors: isSelected
              ? [AppColors.secondary.withOpacity(0.08), AppColors.secondary.withOpacity(0.01)]
              : [isDark ? Colors.white.withOpacity(0.02) : Colors.white, isDark ? Colors.transparent : Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (isWide) {
              context.read<UserMessagesCubit>().selectMessage(msg);
            } else {
              // Mobile Page details view
              context.read<UserMessagesCubit>().selectMessage(msg);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => BlocProvider.value(
                    value: context.read<UserMessagesCubit>(),
                    child: Scaffold(
                      backgroundColor: isDark ? const Color(0xFF0a0a1a) : const Color(0xFFf8f9fa),
                      appBar: AppBar(
                        backgroundColor: isDark ? const Color(0xFF0b0b1e) : Colors.white,
                        title: Text('تفاصيل الرسالة', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                        leading: IconButton(
                          icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black87),
                          onPressed: () {
                            context.read<UserMessagesCubit>().clearSelectedMessage();
                            Navigator.pop(ctx);
                          },
                        ),
                      ),
                      body: _buildMessageDetailsPane(msg, false, isMobile: true),
                    ),
                  ),
                ),
              );
            }
          },
          child: Padding(
            padding: EdgeInsets.all(12.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18.r,
                  backgroundColor: isSelected ? AppColors.secondary.withOpacity(0.2) : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
                  child: Text(
                    safeFirstChar(name, '?'),
                    style: TextStyle(
                      color: isSelected ? AppColors.secondary : (isDark ? Colors.white70 : Colors.black87),
                      fontWeight: FontWeight.bold,
                      fontSize: 13.sp,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildSourceBadge(msg['source']?.toString() ?? 'app'),
                          SizedBox(width: 4.w),
                          _buildUserBadge(isRegistered),
                        ],
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        subject,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        snippet,
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: isDark ? Colors.white.withOpacity(0.35) : Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 8.sp,
                    color: isDark ? Colors.white.withOpacity(0.3) : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSourceBadge(String source) {
    final isWebsite = source == 'website';
    final label = isWebsite ? 'الموقع' : 'التطبيق';
    final color = isWebsite ? Colors.amber : Colors.cyan;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8.sp,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildUserBadge(bool isRegistered) {
    final label = isRegistered ? 'مستخدم' : 'زائر';
    final color = isRegistered ? AppColors.success : Colors.blueAccent;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8.sp,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMessageDetailsPane(Map<String, dynamic> msg, bool isDeleting, {bool isMobile = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = msg['name'] ?? '';
    final email = msg['email'] ?? '';
    final subject = msg['subject'] ?? '';
    final content = msg['message'] ?? '';
    final date = msg['createdAt'] != null ? _fmtFullDate(msg['createdAt'].toString()) : '';

    final user = msg['user'] != null ? Map<String, dynamic>.from(msg['user'] as Map) : null;
    final phone = user != null ? (user['phone'] ?? '') : '';
    final role = user != null ? (user['role'] ?? '') : '';

    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0b0b1e) : Colors.white,
        borderRadius: isMobile ? null : BorderRadius.circular(20),
        boxShadow: isMobile || isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28.r,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text(
                  safeFirstChar(name, '?'),
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 22.sp,
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: isDark ? Colors.white.withOpacity(0.4) : Colors.black54,
                      ),
                    ),
                    if (phone.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        'الهاتف: $phone',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: isDark ? Colors.white.withOpacity(0.4) : Colors.black54,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildSourceBadge(msg['source']?.toString() ?? 'app'),
                  SizedBox(height: 6.h),
                  _buildUserBadge(user != null),
                  if (role.isNotEmpty) ...[
                    SizedBox(height: 6.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade300),
                      ),
                      child: Text(
                        role == 'merchant' ? 'تاجر' : (role == 'captain' ? 'كابتن' : role),
                        style: TextStyle(fontSize: 10.sp, color: isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          Divider(color: isDark ? Colors.white12 : Colors.grey.shade300, height: 32),
          Text(
            'موضوع الرسالة:',
            style: TextStyle(
              fontSize: 11.sp,
              color: isDark ? Colors.white.withOpacity(0.4) : Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            subject,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            date,
            style: TextStyle(
              fontSize: 10.sp,
              color: isDark ? Colors.white.withOpacity(0.3) : Colors.black45,
            ),
          ),
          Divider(color: isDark ? Colors.white12 : Colors.grey.shade300, height: 32),
          Text(
            'محتوى الرسالة:',
            style: TextStyle(
              fontSize: 11.sp,
              color: isDark ? Colors.white.withOpacity(0.4) : Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10.h),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.01) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade300),
              ),
              child: SingleChildScrollView(
                child: Text(
                  content,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: isDark ? Colors.white.withOpacity(0.85) : Colors.black87,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 20.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: isDeleting
                    ? null
                    : () {
                        _showDeleteConfirmDialog(context, msg['id'], isMobile);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error.withOpacity(0.1),
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                  elevation: 0,
                ),
                icon: isDeleting
                    ? SizedBox(
                        width: 16.w,
                        height: 16.w,
                        child: const CircularProgressIndicator(color: AppColors.error, strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_sweep_rounded, size: 20),
                label: Text(
                  'حذف هذه الرسالة',
                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext ctx, int id, bool isMobile) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF14142a) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
        ),
        title: Text(
          'تأكيد الحذف ⚠️',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16.sp, fontWeight: FontWeight.bold),
          textDirection: TextDirection.rtl,
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في حذف هذه الرسالة نهائياً؟ لا يمكن التراجع عن هذا الإجراء.',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13.sp),
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('إلغاء', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx); // Close dialog
              if (isMobile) {
                Navigator.pop(ctx); // Close detail page
              }
              ctx.read<UserMessagesCubit>().deleteMessage(id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSelectedMessagePlaceholder() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(
            FontAwesomeIcons.solidEnvelopeOpen,
            size: 100,
            color: AppColors.primary.withOpacity(0.15),
          ),
          SizedBox(height: 16.h),
          Text(
            'الرجاء اختيار رسالة من القائمة لعرض تفاصيلها',
            style: TextStyle(
              color: isDark ? Colors.white.withOpacity(0.4) : Colors.black38,
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(
            FontAwesomeIcons.solidEnvelope,
            size: 100,
            color: AppColors.primary.withOpacity(0.1),
          ),
          SizedBox(height: 12.h),
          Text(
            'لا توجد رسائل مستخدمين حالياً',
            style: TextStyle(
              color: isDark ? Colors.white.withOpacity(0.4) : Colors.black38,
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      if (date.year == now.year && date.month == now.month && date.day == now.day) {
        final hr = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
        final ampm = date.hour >= 12 ? 'م' : 'ص';
        final min = date.minute.toString().padLeft(2, '0');
        return '$hr:$min $ampm';
      }
      return '${date.year}/${date.month}/${date.day}';
    } catch (_) {
      return dateStr;
    }
  }

  String _fmtFullDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final hr = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
      final ampm = date.hour >= 12 ? 'م' : 'ص';
      final min = date.minute.toString().padLeft(2, '0');
      return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} - $hr:$min $ampm';
    } catch (_) {
      return dateStr;
    }
  }
}
