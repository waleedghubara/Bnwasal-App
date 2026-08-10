// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:admin_bnwasal/core/theme/colors.dart';
import 'package:admin_bnwasal/core/api/end_point.dart';
import 'package:admin_bnwasal/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:flutter_svg/svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/theme/app_assets.dart';
import '../cubit/complaints_cubit.dart';
import '../cubit/complaints_state.dart';
import 'complaint_chat_screen.dart';
import '../../../../core/utils/text_sanitizer.dart';

class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final complaintsCubit = context.read<ComplaintsCubit>();

    // Inject current admin's ID into complaints cubit for socket authentication
    final adminUser = context.read<AuthCubit>().state.user;
    if (adminUser != null) {
      final adminId = adminUser['id']?.toString();
      if (adminId != null) {
        complaintsCubit.setAdminId(adminId);
      }
    }

    complaintsCubit.enterComplaintsPage();
    complaintsCubit.loadComplaints();
  }

  @override
  void dispose() {
    context.read<ComplaintsCubit>().leaveComplaintsPage();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 950;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: BlocBuilder<ComplaintsCubit, ComplaintsState>(
        builder: (context, state) {
          final filteredThreads = state.threads.where((t) {
            final query = _searchQuery.trim().toLowerCase();
            if (query.isEmpty) return true;
            final name = (t['name'] ?? '').toString().toLowerCase();
            final phone = (t['phone'] ?? '').toString().toLowerCase();
            final email = (t['email'] ?? '').toString().toLowerCase();
            return name.contains(query) ||
                phone.contains(query) ||
                email.contains(query);
          }).toList();

          final isDark = Theme.of(context).brightness == Brightness.dark;
          if (isWide) {
            // Wide Screen Desktop Layout: Split-Pane
            return Scaffold(
              backgroundColor: isDark
                  ? const Color(0xFF0a0a1a)
                  : const Color(0xFFf8f9fa),
              body: Row(
                children: [
                  // Left Pane: Threads List
                  Container(
                    width: 320.w,
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: isDark
                              ? Colors.white.withOpacity(0.04)
                              : Colors.grey.shade300,
                        ),
                      ),
                      color: isDark ? const Color(0xFF0b0b1e) : Colors.white,
                    ),
                    child: _buildThreadsColumn(state, filteredThreads, isWide),
                  ),
                  // Center Pane: Active Chat Screen
                  Expanded(
                    child: state.selectedUserId == null
                        ? _buildNoActiveChatPlaceholder()
                        : ComplaintChatScreen(
                            key: ValueKey(state.selectedUserId),
                            thread: Map<String, dynamic>.from(
                              state.threads.firstWhere(
                                    (t) => t['userId'] == state.selectedUserId,
                                  )
                                  as Map,
                            ),
                            embedded: true,
                          ),
                  ),
                ],
              ),
            );
          } else {
            // Narrow Screen Mobile Layout: List view only
            return Scaffold(
              backgroundColor: isDark
                  ? const Color(0xFF0a0a1a)
                  : const Color(0xFFf8f9fa),
              body: _buildThreadsColumn(state, filteredThreads, isWide),
            );
          }
        },
      ),
    );
  }

  Widget _buildThreadsColumn(
    ComplaintsState state,
    List<dynamic> threads,
    bool isWide,
  ) {
    return Column(
      children: [
        _buildHeader(),
        _buildSearchBar(),
        Expanded(
          child: state.isLoading && threads.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.secondary),
                )
              : threads.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 8.h,
                  ),
                  itemCount: threads.length,
                  itemBuilder: (_, i) {
                    final thread = Map<String, dynamic>.from(threads[i] as Map);
                    final isSelected = state.selectedUserId == thread['userId'];
                    return _buildThreadCard(thread, isSelected, isWide);
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
                'الشكاوى والطلبات',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textPrimary,
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
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade300,
        ),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 13,
        ),
        decoration: InputDecoration(
          icon: Icon(
            Icons.search_rounded,
            color: isDark ? Colors.white70 : Colors.black,
            size: 18,
          ),
          hintText: 'البحث عن شخص، هاتف، بريد...',
          hintStyle: TextStyle(
            color: isDark ? Colors.white30 : Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          fillColor: Colors.transparent,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10.h),
        ),
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
          });
        },
      ),
    );
  }

  Widget _buildThreadCard(
    Map<String, dynamic> thread,
    bool isSelected,
    bool isWide,
  ) {
    final name = thread['name'] ?? '';
    final avatar = thread['avatar']?.toString() ?? '';
    final lastMsg = thread['lastMessage'] ?? '';
    final timeStr = thread['lastMessageTime'] != null
        ? _fmtDate(thread['lastMessageTime'].toString())
        : '';
    final unread = thread['unreadCount'] as int? ?? 0;
    final role = thread['role']?.toString() ?? 'merchant';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarUrl = avatar.isNotEmpty
        ? (avatar.startsWith('http') ? avatar : EndPoint.imageBaseUrl + avatar)
        : '';

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? AppColors.primary
              : (isDark
                    ? Colors.white.withOpacity(0.03)
                    : Colors.grey.shade300),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final cubit = context.read<ComplaintsCubit>();
            if (isWide) {
              cubit.openChat(thread);
            } else {
              // On mobile, navigate to full chat screen
              cubit.openChat(thread);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: cubit,
                    child: ComplaintChatScreen(thread: thread, embedded: false),
                  ),
                ),
              ).then((_) {
                cubit.leaveChat();
              });
            }
          },
          child: Padding(
            padding: EdgeInsets.all(12.w),
            child: Row(
              children: [
                // User Avatar / Initial
                CircleAvatar(
                  radius: 20.r,
                  backgroundColor: isSelected
                      ? AppColors.secondary.withOpacity(0.2)
                      : (isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.shade200),
                  backgroundImage: avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl.isEmpty
                      ? Text(
                          safeFirstChar(name, '?'),
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.secondary
                                : (isDark ? Colors.white : Colors.black87),
                            fontWeight: FontWeight.bold,
                            fontSize: 14.sp,
                          ),
                        )
                      : null,
                ),
                SizedBox(width: 12.w),
                // Text details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          // Role Badge
                          _roleBadge(role),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        lastMsg.isNotEmpty ? lastMsg : 'لا توجد رسائل',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: unread > 0
                              ? (isDark ? Colors.white : AppColors.textPrimary)
                              : (isDark
                                    ? Colors.white.withOpacity(0.35)
                                    : Colors.black),
                          fontWeight: unread > 0
                              ? FontWeight.bold
                              : FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                // Time & Unread counter
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.white.withOpacity(0.3)
                            : Colors.black,
                      ),
                    ),
                    if (unread > 0) ...[
                      SizedBox(height: 6.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.error.withOpacity(0.3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Text(
                          unread.toString(),
                          style: TextStyle(
                            fontSize: 8.sp,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleBadge(String role) {
    final isMerchant = role == 'merchant';
    final label = isMerchant ? 'تاجر' : 'كابتن';
    final color = isMerchant ? AppColors.secondary : AppColors.primary;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.18)),
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

  Widget _buildNoActiveChatPlaceholder() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(
            FontAwesomeIcons.commentDots,
            size: 130,
            color: AppColors.primary,
          ),
          SizedBox(height: 16.h),
          Text(
            'الرجاء اختيار شكوى من القائمة الجانبية للبدء بالدردشة والرد عليها',
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimary,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
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
          SvgPicture.asset(AppAssets.complaints, width: 130.w, height: 130.h),
          SizedBox(height: 12.h),
          Text(
            'لا توجد شكاوى أو محادثات معلّقة حالياً',
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimary,
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
      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        final hr = date.hour > 12
            ? date.hour - 12
            : (date.hour == 0 ? 12 : date.hour);
        final ampm = date.hour >= 12 ? 'م' : 'ص';
        final min = date.minute.toString().padLeft(2, '0');
        return '$hr:$min $ampm';
      }
      return '${date.year}/${date.month}/${date.day}';
    } catch (_) {
      return dateStr;
    }
  }
}
