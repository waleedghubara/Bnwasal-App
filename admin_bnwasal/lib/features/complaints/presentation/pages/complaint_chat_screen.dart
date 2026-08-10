// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:admin_bnwasal/core/theme/colors.dart';
import 'package:admin_bnwasal/core/api/end_point.dart';
import 'package:admin_bnwasal/features/auth/presentation/cubit/auth_cubit.dart';
import '../cubit/complaints_cubit.dart';
import '../cubit/complaints_state.dart';
import '../../../../core/utils/text_sanitizer.dart';


class ComplaintChatScreen extends StatefulWidget {
  final Map<String, dynamic> thread;
  final bool embedded;

  const ComplaintChatScreen({
    super.key,
    required this.thread,
    required this.embedded,
  });

  @override
  State<ComplaintChatScreen> createState() => _ComplaintChatScreenState();
}

class _ComplaintChatScreenState extends State<ComplaintChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  bool _adminIsTyping = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    // Fetch initial chat messages on loading the screen
    final adminUser = context.read<AuthCubit>().state.user;
    final adminId = adminUser?['id']?.toString();
    context.read<ComplaintsCubit>().openChat(widget.thread, adminId: adminId);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final isTyping = _messageController.text.isNotEmpty;
    if (isTyping != _adminIsTyping) {
      _adminIsTyping = isTyping;

      // Get admin details from AuthCubit
      final adminUser = context.read<AuthCubit>().state.user;
      final name = adminUser?['firstName'] != null
          ? '${adminUser!['firstName']} ${adminUser['lastName'] ?? ''}'
          : 'الدعم الفني بنوصل';
      final avatar = adminUser?['profileImage']?.toString();

      context.read<ComplaintsCubit>().sendTypingState(
        isTyping,
        senderName: name,
        senderAvatar: avatar,
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    context.read<ComplaintsCubit>().sendReply(text);
    _messageController.clear();
    // Delay scroll to bottom slightly to allow optimistic message to render
    Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        context.read<ComplaintsCubit>().sendReply('', imagePath: image.path);
        Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فشل تحميل الصورة، يرجى المحاولة مجدداً.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildImageWidget(String path) {
    final isRemote =
        path.startsWith('http') ||
        path.contains('uploads') ||
        path.startsWith('/uploads');
    Widget imageWidget;

    if (isRemote) {
      final fullUrl = path.startsWith('http')
          ? path
          : path.startsWith('/')
          ? '${EndPoint.imageBaseUrl}$path'
          : '${EndPoint.imageBaseUrl}/$path';
      imageWidget = Image.network(
        fullUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 200.w,
          height: 150.h,
          color: Colors.white.withOpacity(0.02),
          child: Icon(Icons.broken_image, color: Colors.white.withOpacity(0.1)),
        ),
      );
    } else {
      imageWidget = Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 200.w,
          height: 150.h,
          color: Colors.white.withOpacity(0.02),
          child: Icon(Icons.broken_image, color: Colors.white.withOpacity(0.1)),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showFullImageDialog(context, path, isRemote),
      child: Container(
        constraints: BoxConstraints(maxWidth: 250.w, maxHeight: 250.h),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.r),
          child: imageWidget,
        ),
      ),
    );
  }

  void _showFullImageDialog(BuildContext context, String path, bool isRemote) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(10.w),
        child: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                color: Colors.black.withOpacity(0.85),
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(16.r),
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: isRemote
                    ? Image.network(
                        path.startsWith('http')
                            ? path
                            : path.startsWith('/')
                            ? '${EndPoint.imageBaseUrl}$path'
                            : '${EndPoint.imageBaseUrl}/$path',
                        fit: BoxFit.contain,
                      )
                    : Image.file(File(path), fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 20.h,
              right: 20.w,
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.5),
                child: IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _presenceIndicator(bool isOnline) {
    return Container(
      width: 8.w,
      height: 8.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOnline
            ? const Color(0xFF10b981)
            : Colors.white.withOpacity(0.2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final showSidebar = screenWidth >= 1200;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Retrieve admin avatar from auth state
    final adminUser = context.read<AuthCubit>().state.user;
    final adminAvatar =
        adminUser?['profileImage']?.toString() ?? '/uploads/default-admin.png';
    final adminAvatarUrl = adminAvatar.startsWith('http')
        ? adminAvatar
        : EndPoint.imageBaseUrl + adminAvatar;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: BlocConsumer<ComplaintsCubit, ComplaintsState>(
        listener: (context, state) {
          // Scroll down when new messages arrive
          Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
        },
        builder: (context, state) {
          final activeChat = Row(
            children: [
              // Main Chat Window
              Expanded(
                child: Column(
                  children: [
                    if (widget.embedded) _buildEmbeddedHeader(context, state),
                    Expanded(
                      child: state.isLoadingChat
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.secondary,
                              ),
                            )
                          : _buildMessagesList(
                              state.activeMessages,
                              adminAvatarUrl,
                            ),
                    ),
                    if (state.isClientTyping)
                      _buildClientTypingIndicator(widget.thread['name'] ?? ''),
                    _buildInputBar(),
                  ],
                ),
              ),
              // Account Detail Sidebar (only shown if viewport is wide enough)
              if (showSidebar)
                Container(
                  width: 280.w,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade300),
                    ),
                    color: isDark ? const Color(0xFF0b0b1e) : Colors.white,
                  ),
                  child: _buildDetailsSidebar(context),
                ),
            ],
          );

          if (widget.embedded) {
            return Scaffold(
              backgroundColor: isDark ? const Color(0xFF0a0a1a) : const Color(0xFFf8f9fa),
              body: activeChat,
            );
          } else {
            // Mobile full page wrapper
            return Scaffold(
              backgroundColor: isDark ? const Color(0xFF0a0a1a) : const Color(0xFFf8f9fa),
              appBar: _buildMobileAppBar(context, state),
              body: SafeArea(child: activeChat),
            );
          }
        },
      ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar(
    BuildContext context,
    ComplaintsState state,
  ) {
    final name = widget.thread['name'] ?? '';
    final role = widget.thread['role']?.toString() ?? 'merchant';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      backgroundColor: isDark ? const Color(0xFF0a0a1a) : const Color(0xFFf8f9fa),
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black87, size: 18.sp),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          _presenceIndicator(state.isClientOnline),
          SizedBox(width: 8.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              Text(
                role == 'merchant'
                    ? (state.isClientOnline
                          ? 'تاجر • متصل الآن'
                          : 'تاجر • غير متصل')
                    : (state.isClientOnline
                          ? 'كابتن • متصل الآن'
                          : 'كابتن • غير متصل'),
                style: TextStyle(
                  fontSize: 9.sp,
                  color: state.isClientOnline
                      ? AppColors.success
                      : (isDark ? Colors.white.withOpacity(0.4) : Colors.black54),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.info_outline_rounded,
            color: isDark ? Colors.white : Colors.black87,
            size: 20.sp,
          ),
          onPressed: () => _showMobileDetailsSheet(context),
        ),
      ],
    );
  }

  Widget _buildEmbeddedHeader(BuildContext context, ComplaintsState state) {
    final name = widget.thread['name'] ?? '';
    final role = widget.thread['role']?.toString() ?? 'merchant';
    final double screenWidth = MediaQuery.of(context).size.width;
    final showSidebar = screenWidth >= 1200;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0b0b1e) : Colors.white,
        border: Border(
          bottom: BorderSide(color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.close_rounded, color: Colors.red, size: 26.sp),
            onPressed: () => context.read<ComplaintsCubit>().leaveChat(),
          ),
          SizedBox(width: 8.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _presenceIndicator(state.isClientOnline),
                  SizedBox(width: 8.w),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 2.h),
              Text(
                role == 'merchant' ? 'حساب تاجر' : 'حساب كابتن',
                style: TextStyle(
                  fontSize: 10.sp,
                  color: isDark ? Colors.white.withOpacity(0.4) : Colors.black54,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (!showSidebar)
            IconButton(
              icon: Icon(
                Icons.info_outline_rounded,
                color: isDark ? Colors.white.withOpacity(0.7) : Colors.black54,
                size: 20.sp,
              ),
              onPressed: () => _showMobileDetailsSheet(context),
            ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(List<dynamic> messages, String adminAvatarUrl) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              FontAwesomeIcons.commentDots,
              size: 40.sp,
              color: isDark ? Colors.white.withOpacity(0.04) : Colors.black12,
            ),
            SizedBox(height: 12.h),
            Text(
              'لا توجد رسائل سابقة. ابدأ المحادثة الآن.',
              style: TextStyle(
                color: isDark ? Colors.white.withOpacity(0.3) : Colors.black38,
                fontSize: 11.sp,
              ),
            ),
          ],
        ),
      );
    }

    return BlocBuilder<ComplaintsCubit, ComplaintsState>(
      builder: (context, state) {
        // Build flat list: message + optional auto-lookup card
        final items = <Widget>[];
        for (int i = 0; i < messages.length; i++) {
          final msg = Map<String, dynamic>.from(messages[i] as Map);
          final isMe = msg['isUser'] == true;
          items.add(_buildMessageBubble(msg, isMe, adminAvatarUrl));

          final msgKey = msg['id']?.toString() ?? (msg['text'] as String? ?? '');
          final lookupResult = state.autoLookupResults[msgKey];
          if (lookupResult != null) {
            items.add(_buildAutoLookupCard(lookupResult));
          }
        }

        return ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          itemCount: items.length,
          itemBuilder: (_, i) => items[i],
        );
      },
    );
  }

  Widget _buildAutoLookupCard(Map<String, dynamic> result) {
    return _AutoLookupResultCard(result: result);
  }

  Widget _buildClientTypingIndicator(String clientName) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$clientName يكتب الآن...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    Map<String, dynamic> msg,
    bool isMe,
    String adminAvatarUrl,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = msg['text'] ?? '';
    final imagePath = msg['imagePath']?.toString() ?? '';
    final timeStr = msg['timestamp'] != null
        ? _fmtTime(msg['timestamp'].toString())
        : '';
    final avatar = msg['senderAvatar']?.toString() ?? '';

    final clientAvatarUrl = avatar.isNotEmpty
        ? (avatar.startsWith('http') ? avatar : EndPoint.imageBaseUrl + avatar)
        : '';

    final showAvatar = isMe ? adminAvatarUrl : clientAvatarUrl;

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // If message is sent by admin, show avatar on the left
          if (isMe) ...[
            _messageAvatar(
              showAvatar,
              widget.thread['name']?.toString() ?? 'أ',
            ),
            SizedBox(width: 8.w),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16.r),
                  topRight: Radius.circular(16.r),
                  bottomLeft: isMe ? Radius.circular(16.r) : Radius.zero,
                  bottomRight: isMe ? Radius.zero : Radius.circular(16.r),
                ),
                color: isMe
                    ? AppColors.primary.withOpacity(0.2)
                    : (isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade100),
                border: Border.all(
                  color: isMe
                      ? AppColors.primary.withOpacity(0.3)
                      : (isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade300),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imagePath.isNotEmpty) ...[
                    _buildImageWidget(imagePath),
                    SizedBox(height: 6.h),
                  ],
                  if (text.isNotEmpty)
                    Text(
                      text,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  SizedBox(height: 4.h),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 14.sp, // Note: preserved original font size 14.sp
                          color: isDark ? Colors.white.withOpacity(0.3) : Colors.black38,
                        ),
                      ),
                      if (isMe) ...[
                        SizedBox(width: 4.w),
                        Icon(
                          Icons.done_all_rounded,
                          size: 14.sp,
                          color: msg['status'] == 'read'
                              ? AppColors.success
                              : (isDark ? Colors.white.withOpacity(0.3) : Colors.black38),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          // If message is sent by client, show avatar on the right
          if (!isMe) ...[
            SizedBox(width: 8.w),
            _messageAvatar(
              showAvatar,
              widget.thread['name']?.toString() ?? '?',
            ),
          ],
        ],
      ),
    );
  }

  Widget _messageAvatar(String avatarUrl, String fallbackLetter) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CircleAvatar(
      radius: 14.r,
      backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
      backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
      child: avatarUrl.isEmpty
          ? Text(
              safeFirstChar(fallbackLetter, '?'),
              style: TextStyle(
                fontSize: 10.sp,
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }

  Widget _buildInputBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0b0b1e) : Colors.white,
        border: Border(top: BorderSide(color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: FaIcon(
              FontAwesomeIcons.paperclip,
              color: AppColors.secondary,
              size: 18.sp,
            ),
            onPressed: _pickImage,
          ),
          SizedBox(width: 6.w),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade300),
              ),
              child: TextField(
                controller: _messageController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
                maxLines: null,
                decoration: InputDecoration(
                  hintText: 'اكتب الرد هنا...',
                  hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 12),
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          SizedBox(width: 10.w),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.secondary.withOpacity(0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(Icons.send_rounded, size: 24.sp, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSidebar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = widget.thread['name'] ?? '';
    final phone = widget.thread['phone'] ?? 'غير متوفر';
    final email = widget.thread['email'] ?? 'غير متوفر';
    final userId = widget.thread['userId']?.toString() ?? '';
    final role = widget.thread['role']?.toString() ?? 'merchant';
    final avatar = widget.thread['avatar']?.toString() ?? '';

    final avatarUrl = avatar.isNotEmpty
        ? (avatar.startsWith('http') ? avatar : EndPoint.imageBaseUrl + avatar)
        : '';

    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'بيانات العميل',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white.withOpacity(0.7) : Colors.black54,
            ),
          ),
          SizedBox(height: 24.h),
          Align(
            alignment: Alignment.center,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40.r,
                  backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
                  backgroundImage: avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl.isEmpty
                      ? Text(
                          safeFirstChar(name, '?'),
                          style: TextStyle(
                            fontSize: 24.sp,
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                SizedBox(height: 12.h),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 6.h),
                _roleBadge(role),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          _buildInfoRow(context, 'الاسم الكامل', name),
          _buildInfoRow(context, 'رقم الحساب ID', userId, copyable: true),
          _buildInfoRow(
            context,
            'نوع الحساب',
            role == 'merchant' ? 'تاجر' : 'كابتن توصيل',
          ),
          _buildInfoRow(context, 'رقم الهاتف', phone, copyable: true),
          _buildInfoRow(context, 'البريد الإلكتروني', email, copyable: true),
          SizedBox(height: 30.h),
          Divider(color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade300, height: 1),
          SizedBox(height: 20.h),
          Text(
            'خيارات الدعم',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white.withOpacity(0.4) : Colors.black54,
            ),
          ),
          SizedBox(height: 12.h),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error.withOpacity(0.15),
              foregroundColor: AppColors.error,
              elevation: 0,
              minimumSize: Size(double.infinity, 38.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: AppColors.error.withOpacity(0.2)),
              ),
            ),
            icon: Icon(Icons.block_rounded, size: 14.sp),
            label: const Text('حظر الحساب مؤقتاً'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('سيتم حظر الحساب بعد مراجعة الإدارة العليا'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }



  Widget _roleBadge(String role) {
    final isMerchant = role == 'merchant';
    final label = isMerchant ? 'تاجر' : 'كابتن توصيل';
    final color = isMerchant ? AppColors.secondary : AppColors.primary;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.sp,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value, {
    bool copyable = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13.sp,
              color: isDark ? Colors.white.withOpacity(0.3) : Colors.black38,
            ),
          ),
          SizedBox(height: 4.h),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: isDark ? Colors.white.withOpacity(0.85) : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (copyable && value.isNotEmpty && value != 'غير متوفر') ...[
                SizedBox(width: 8.w),
                IconButton(
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.copy_rounded,
                    size: 13.sp,
                    color: isDark ? Colors.white.withOpacity(0.35) : Colors.black38,
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'تم نسخ $label بنجاح',
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: AppColors.primary,
                        behavior: SnackBarBehavior.floating,
                        width: 200,
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showMobileDetailsSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0b0b1e) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: _buildDetailsSidebar(context),
          ),
        );
      },
    );
  }

  String _fmtTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final hr = date.hour > 12
          ? date.hour - 12
          : (date.hour == 0 ? 12 : date.hour);
      final ampm = date.hour >= 12 ? 'م' : 'ص';
      final min = date.minute.toString().padLeft(2, '0');
      return '$hr:$min $ampm';
    } catch (_) {
      return dateStr;
    }
  }
}

class _AutoLookupResultCard extends StatefulWidget {
  final Map<String, dynamic> result;
  const _AutoLookupResultCard({required this.result});

  @override
  State<_AutoLookupResultCard> createState() => _AutoLookupResultCardState();
}

class _AutoLookupResultCardState extends State<_AutoLookupResultCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = true;
  late AnimationController _animController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    _expandAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_isExpanded) {
      _animController.reverse();
    } else {
      _animController.forward();
    }
    setState(() => _isExpanded = !_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final users = (widget.result['users'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final orders = (widget.result['orders'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final shipments = (widget.result['shipments'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: EdgeInsetsDirectional.only(start: 40.w, bottom: 12.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.06),
            isDark ? const Color(0xFF0b0b1e) : Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: isDark ? AppColors.primary.withValues(alpha: 0.15) : Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: isDark ? AppColors.primary.withValues(alpha: 0.06) : Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.vertical(top: Radius.circular(14.r)),
            onTap: _toggle,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6.w),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.auto_fix_high_rounded,
                        size: 14.sp, color: AppColors.secondary),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text('نتائج البحث التلقائي',
                        style: TextStyle(
                            fontSize: 11.sp,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.w600)),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${users.length + orders.length + shipments.length}',
                      style: TextStyle(
                          fontSize: 9.sp, color: isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black54),
                    ),
                  ),
                  SizedBox(width: 6.w),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(Icons.keyboard_arrow_up_rounded,
                        size: 18.sp,
                        color: isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black38),
                  ),
                ],
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _expandAnimation,
            axisAlignment: -1,
            child: Padding(
              padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 14.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade300, height: 1),
                  SizedBox(height: 10.h),
                  if (users.isNotEmpty) ...[
                    _sectionHeader(Icons.person_rounded, 'المستخدمين',
                        AppColors.secondary, users.length),
                    SizedBox(height: 6.h),
                    ...users.map((u) => _ResultItemCard(
                          icon: Icons.person_rounded,
                          color: AppColors.secondary,
                          fields: _buildUserFields(u),
                        )),
                    SizedBox(height: 10.h),
                  ],
                  if (orders.isNotEmpty) ...[
                    _sectionHeader(Icons.receipt_long_rounded, 'الطلبات',
                        AppColors.primary, orders.length),
                    SizedBox(height: 6.h),
                    ...orders.map((o) => _ResultItemCard(
                          icon: Icons.receipt_long_rounded,
                          color: AppColors.primary,
                          fields: _buildOrderFields(o),
                        )),
                    SizedBox(height: 10.h),
                  ],
                  if (shipments.isNotEmpty) ...[
                    _sectionHeader(Icons.local_shipping_rounded, 'الشحنات',
                        AppColors.success, shipments.length),
                    SizedBox(height: 6.h),
                    ...shipments.map((s) => _ResultItemCard(
                          icon: Icons.local_shipping_rounded,
                          color: AppColors.success,
                          fields: _buildShipmentFields(s),
                        )),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title, Color color, int count) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 12.sp, color: color),
        SizedBox(width: 6.w),
        Text(title,
            style: TextStyle(
                fontSize: 10.sp,
                color: color,
                fontWeight: FontWeight.bold)),
        SizedBox(width: 4.w),
        Text('($count)',
            style: TextStyle(
                fontSize: 9.sp, color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black45)),
      ],
    );
  }

  List<_ResultField> _buildUserFields(Map<String, dynamic> u) {
    return [
      _ResultField(label: 'الاسم', value: u['name'] ?? ''),
      _ResultField(label: 'البريد', value: u['email'] ?? '', copyable: true),
      _ResultField(label: 'الهاتف', value: u['phone'] ?? '', copyable: true),
      if (u['storeName'] != null)
        _ResultField(label: 'المتجر', value: u['storeName']),
      if (u['city'] != null)
        _ResultField(label: 'المدينة', value: u['city']),
      _ResultField(label: 'الرصيد', value: '${u['walletBalance'] ?? 0} ج.م'),
      _ResultField(
          label: 'الحالة',
          value: u['status'] ?? '',
          badge: u['status']?.toString()),
      _ResultField(label: 'مسجل منذ', value: _fmtDate(u['createdAt'])),
    ];
  }

  List<_ResultField> _buildOrderFields(Map<String, dynamic> o) {
    return [
      _ResultField(
          label: 'رقم الطلب',
          value: o['orderNumber'] ?? '',
          copyable: true),
      _ResultField(
          label: 'الحالة',
          value: o['status'] ?? '',
          badge: o['status']?.toString()),
      _ResultField(label: 'العميل', value: o['clientName'] ?? ''),
      _ResultField(
          label: 'هاتف العميل',
          value: o['phone'] ?? '',
          copyable: true),
      _ResultField(
          label: 'سعر الطلب',
          value: '${o['orderPrice'] ?? 0} ج.م'),
      _ResultField(
          label: 'رسوم التوصيل',
          value: '${o['deliveryFee'] ?? 0} ج.م'),
      _ResultField(label: 'التاجر', value: o['merchant'] ?? ''),
      if (o['deliveryAddress'] != null)
        _ResultField(
            label: 'عنوان التوصيل',
            value: o['deliveryAddress'],
            copyable: true),
      if (o['details'] != null)
        _ResultField(
            label: 'التفاصيل',
            value: o['details'],
            copyable: true),
      _ResultField(label: 'تاريخ الطلب', value: _fmtDate(o['createdAt'])),
    ];
  }

  List<_ResultField> _buildShipmentFields(Map<String, dynamic> s) {
    return [
      _ResultField(
          label: 'رقم الشحنة',
          value: s['shipmentNumber'] ?? '',
          copyable: true),
      _ResultField(
          label: 'العنوان', value: s['title'] ?? ''),
      _ResultField(
          label: 'الحالة',
          value: s['status'] ?? '',
          badge: s['status']?.toString()),
      _ResultField(
          label: 'من', value: s['fromAddress'] ?? '', copyable: true),
      _ResultField(
          label: 'إلى', value: s['toAddress'] ?? '', copyable: true),
      if (s['fromGovernorate'] != null)
        _ResultField(
            label: 'محافظة المصدر',
            value: s['fromGovernorate']),
      if (s['toGovernorate'] != null)
        _ResultField(
            label: 'محافظة الوجهة',
            value: s['toGovernorate']),
      _ResultField(
          label: 'السعر', value: '${s['price'] ?? 0} ج.م'),
      _ResultField(
          label: 'الوزن', value: '${s['weight'] ?? 0} كجم'),
      _ResultField(label: 'التاجر', value: s['merchant'] ?? ''),
      _ResultField(
          label: 'تاريخ الإنشاء', value: _fmtDate(s['createdAt'])),
    ];
  }

  String _fmtDate(dynamic date) {
    if (date == null || date == '') return '-';
    try {
      final d = DateTime.parse(date.toString()).toLocal();
      return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return date.toString();
    }
  }
}

class _ResultField {
  final String label;
  final String value;
  final bool copyable;
  final String? badge;
  const _ResultField({
    required this.label,
    required this.value,
    this.copyable = false,
    this.badge,
  });
}

class _ResultItemCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final List<_ResultField> fields;
  const _ResultItemCard({
    required this.icon,
    required this.color,
    required this.fields,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 6.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: fields.map((f) => _buildFieldRow(context, f)).toList(),
      ),
    );
  }

  Widget _buildFieldRow(BuildContext context, _ResultField field) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70.w,
            child: Text(field.label,
                style: TextStyle(
                    fontSize: 9.sp,
                    color: isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black45)),
          ),
          Expanded(
            child: field.badge != null
                ? _statusBadge(field.badge!)
                : Text(field.value,
                    style: TextStyle(
                        fontSize: 10.sp, color: isDark ? Colors.white : Colors.black87)),
          ),
          if (field.copyable && field.value.isNotEmpty)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: field.value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تم نسخ ${field.label}',
                        style: const TextStyle(color: Colors.white)),
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 1),
                    width: 160,
                  ),
                );
              },
              child: Padding(
                padding: EdgeInsetsDirectional.only(start: 8.w),
                child: Icon(Icons.copy_rounded,
                    size: 12.sp,
                    color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black38),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = status == 'active' || status == 'delivered'
        ? AppColors.success
        : status == 'pending'
            ? AppColors.secondary
            : status == 'cancelled' || status == 'rejected'
                ? AppColors.error
                : AppColors.primary;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(status,
          style: TextStyle(
              fontSize: 9.sp, color: color, fontWeight: FontWeight.w500)),
    );
  }
}


