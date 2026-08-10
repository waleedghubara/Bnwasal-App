// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';
import 'package:animate_do/animate_do.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../core/api/end_point.dart';
import '../bloc/support_cubit.dart';
import '../bloc/support_state.dart';
import '../../data/models/support_message_model.dart';

class ChatSupportScreen extends StatefulWidget {
  const ChatSupportScreen({super.key});

  @override
  State<ChatSupportScreen> createState() => _ChatSupportScreenState();
}

class _ChatSupportScreenState extends State<ChatSupportScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  bool _userIsTyping = false;

  @override
  void initState() {
    super.initState();
    NotificationService.isChatSupportScreenActive = true;
    _messageController.addListener(_onTextChanged);
    // Scroll to bottom on load after rendering
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    NotificationService.isChatSupportScreenActive = false;
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final isTyping = _messageController.text.isNotEmpty;
    if (isTyping != _userIsTyping) {
      _userIsTyping = isTyping;
      context.read<SupportCubit>().sendTypingState(isTyping);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage({String? text, String? imagePath}) {
    if ((text == null || text.trim().isEmpty) && imagePath == null) return;
    context.read<SupportCubit>().sendSupportMessage(
      text: text ?? '',
      imagePath: imagePath,
    );
    _messageController.clear();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        _sendMessage(imagePath: image.path);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('فشل تحميل الصورة، يرجى المحاولة مجدداً.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.r),
          ),
        ),
      );
    }
  }

  Widget _buildAvatar(
    String? avatarPath,
    double radius, {
    IconData defaultIcon = Icons.support_agent,
  }) {
    if (avatarPath != null && avatarPath.isNotEmpty) {
      final fullUrl = avatarPath.startsWith('http')
          ? avatarPath
          : avatarPath.startsWith('/')
          ? '${EndPoint.imageBaseUrl}$avatarPath'
          : '${EndPoint.imageBaseUrl}/$avatarPath';
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(fullUrl),
        backgroundColor: const Color(0xFF204CB3).withOpacity(0.1),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF204CB3).withOpacity(0.1),
      child: Icon(
        defaultIcon,
        color: const Color(0xFF204CB3),
        size: (radius * 1.1).sp,
      ),
    );
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
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 200.w,
            height: 150.h,
            color: Colors.grey.withOpacity(0.1),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => Container(
          width: 200.w,
          height: 150.h,
          color: Colors.grey.withOpacity(0.1),
          child: const Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    } else {
      imageWidget = Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 200.w,
          height: 150.h,
          color: Colors.grey.withOpacity(0.1),
          child: const Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showFullImageDialog(context, path, isRemote),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 250.w,
          maxHeight: 250.h,
        ),
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
                    : Image.file(
                        File(path),
                        fit: BoxFit.contain,
                      ),
              ),
            ),
            Positioned(
              top: 20.h,
              right: 20.w,
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.5),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: BlocConsumer<SupportCubit, SupportState>(
        listener: (context, state) {
          if (state is SupportChatError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            );
          } else if (state is SupportChatLoaded) {
            _scrollToBottom();
          }
        },
        builder: (context, state) {
          String lastSeen = "خارج الشكاوي";
          bool isTyping = false;
          String? typingAdminName;
          String? typingAdminAvatar;
          List<SupportMessageModel> messagesList = [];
          bool isLoading = true;
          String appBarName = 'الدعم الفني بنوصل';
          String? appBarAvatar;

          if (state is SupportChatLoaded) {
            isLoading = false;
            lastSeen = state.lastSeenText;
            isTyping = state.isSupportTyping;
            typingAdminName = state.typingAdminName;
            typingAdminAvatar = state.typingAdminAvatar;
            messagesList = state.messages;

            // Find the last admin message to get their name and avatar
            final lastAdminMsgIdx = messagesList.lastIndexWhere((m) => !m.isUser);
            if (lastAdminMsgIdx != -1) {
              final lastAdminMsg = messagesList[lastAdminMsgIdx];
              appBarName = lastAdminMsg.senderName.isNotEmpty ? lastAdminMsg.senderName : 'الدعم الفني';
              appBarAvatar = lastAdminMsg.senderAvatar;
            }

            // Override with active admin details if online
            if (state.activeAdminName != null) {
              appBarName = state.activeAdminName!;
              appBarAvatar = state.activeAdminAvatar;
            }

            // Override with typing details if currently typing
            if (isTyping && typingAdminName != null) {
              appBarName = typingAdminName;
              appBarAvatar = typingAdminAvatar;
            }
          } else if (state is SupportChatError) {
            isLoading = false;
          }

          return Scaffold(
            backgroundColor: isDarkMode
                ? const Color(0xFF121212)
                : const Color(0xFFF7F9FC),
            appBar: AppBar(
              backgroundColor: isDarkMode
                  ? const Color(0xFF1E1E1E)
                  : Colors.white,
              elevation: 1,
              titleSpacing: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios,
                  color: isDarkMode ? Colors.white : Colors.black,
                  size: 20.sp,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: Row(
                children: [
                  Stack(
                    children: [
                      _buildAvatar(
                        appBarAvatar,
                        20.r,
                        defaultIcon: Icons.support_agent,
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        child: Container(
                          width: 12.w,
                          height: 12.w,
                          decoration: BoxDecoration(
                            color: lastSeen == "متصل الآن"
                                ? Colors.green
                                : (lastSeen == "خارج المحادثة" ? Colors.amber : Colors.grey),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDarkMode
                                  ? const Color(0xFF1E1E1E)
                                  : Colors.white,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 12.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appBarName,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        lastSeen,
                        style: TextStyle(
                          color: lastSeen == "متصل الآن"
                              ? Colors.green
                              : (lastSeen == "خارج المحادثة"
                                  ? Colors.amber
                                  : const Color(0xFF9E9E9E)),
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.phone_in_talk_outlined,
                    color: const Color(0xFF204CB3),
                    size: 22.sp,
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'جاري الاتصال بمركز خدمة العملاء...',
                        ),
                        backgroundColor: const Color(0xFF204CB3),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(width: 8.w),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  child: isLoading
                      ? _buildSkeletonLoader()
                      : messagesList.isEmpty
                      ? _buildEmptyState()
                      : _buildMessageList(messagesList, isDarkMode),
                ),
                if (isTyping)
                  _buildTypingIndicator(
                    typingAdminName,
                    typingAdminAvatar,
                    isDarkMode,
                  ),
                _buildMessageComposer(isDarkMode),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        itemCount: 4,
        itemBuilder: (context, index) {
          final isLeft = index % 2 == 0;
          return Align(
            alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              margin: EdgeInsets.only(bottom: 16.h),
              width: 200.w,
              height: 60.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16.r),
                  topRight: Radius.circular(16.r),
                  bottomLeft: isLeft
                      ? Radius.circular(4.r)
                      : Radius.circular(16.r),
                  bottomRight: isLeft
                      ? Radius.circular(16.r)
                      : Radius.circular(4.r),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: FadeIn(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 60.sp,
              color: const Color(0xFFBDBDBD),
            ),
            SizedBox(height: 16.h),
            Text(
              'لا توجد رسائل بعد',
              style: TextStyle(
                fontSize: 16.sp,
                color: const Color(0xFF888888),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'ابدأ المحادثة مع الدعم الفني الآن',
              style: TextStyle(fontSize: 13.sp, color: const Color(0xFFBDBDBD)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(
    List<SupportMessageModel> messages,
    bool isDarkMode,
  ) {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return _buildMessageRow(message, isDarkMode);
      },
    );
  }

  Widget _buildMessageRow(SupportMessageModel message, bool isDarkMode) {
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: _buildMessageBubble(message, isDarkMode),
      );
    } else {
      return Align(
        alignment: Alignment.centerLeft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.ltr,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 4.h),
              child: _buildAvatar(
                message.senderAvatar,
                14.r,
                defaultIcon: Icons.support_agent,
              ),
            ),
            SizedBox(width: 8.w),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMessageBubble(message, isDarkMode),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildMessageBubble(SupportMessageModel message, bool isDarkMode) {
    final Color bubbleColor = message.isUser
        ? const Color(0xFF204CB3)
        : (isDarkMode ? const Color(0xFF2C2C2C) : Colors.white);
    final Color textColor = message.isUser
        ? Colors.white
        : (isDarkMode ? Colors.white : const Color(0xFF333333));
    final double bottomLeftRadius = message.isUser ? 16.r : 4.r;
    final double bottomRightRadius = message.isUser ? 4.r : 16.r;

    return FadeInUp(
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4.h),
        constraints: BoxConstraints(maxWidth: 0.7.sw),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16.r),
            topRight: Radius.circular(16.r),
            bottomLeft: Radius.circular(bottomLeftRadius),
            bottomRight: Radius.circular(bottomRightRadius),
          ),
          border: !message.isUser
              ? Border.all(
                  color: isDarkMode ? Colors.transparent : Colors.grey.shade200,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.imagePath != null && message.imagePath!.isNotEmpty) ...[
              _buildImageWidget(message.imagePath!),
              SizedBox(height: 6.h),
            ],
            if (message.text.isNotEmpty)
              Text(
                message.text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14.sp,
                  height: 1.4,
                ),
              ),
            SizedBox(height: 4.h),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    color: message.isUser
                        ? Colors.white.withOpacity(0.7)
                        : const Color(0xFF9E9E9E),
                    fontSize: 10.sp,
                  ),
                ),
                if (message.isUser) ...[
                  SizedBox(width: 4.w),
                  _buildStatusIcon(message.status),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(SupportMessageStatus status) {
    switch (status) {
      case SupportMessageStatus.sent:
        return Icon(
          Icons.check,
          color: Colors.white.withOpacity(0.7),
          size: 13.sp,
        );
      case SupportMessageStatus.delivered:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check,
              color: Colors.white.withOpacity(0.7),
              size: 10.sp,
            ),
            Icon(
              Icons.check,
              color: Colors.white.withOpacity(0.7),
              size: 10.sp,
            ),
          ],
        );
      case SupportMessageStatus.read:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, color: const Color(0xFFFFC107), size: 10.sp),
            Icon(Icons.check, color: const Color(0xFFFFC107), size: 10.sp),
          ],
        );
    }
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final amPm = time.hour >= 12 ? 'م' : 'ص';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $amPm';
  }

  Widget _buildTypingIndicator(
    String? adminName,
    String? adminAvatar,
    bool isDarkMode,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.ltr,
          children: [
            _buildAvatar(adminAvatar, 12.r, defaultIcon: Icons.support_agent),
            SizedBox(width: 8.w),
            Text(
              '${adminName ?? "الدعم الفني"} يكتب الآن',
              style: TextStyle(
                color: const Color(0xFF9E9E9E),
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: 8.w),
            _BouncingDots(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageComposer(bool isDarkMode) {
    return SafeArea(
      child: Container(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.camera_alt_outlined,
                color: const Color(0xFF204CB3),
                size: 24.sp,
              ),
              onPressed: _pickImage,
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF2C2C2C)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(24.r),
                ),
                child: TextField(
                  controller: _messageController,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: 'اكتب رسالة...',
                    hintStyle: TextStyle(
                      color: const Color(0xFF9E9E9E),
                      fontSize: 13.sp,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 10.h,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8.w),
            GestureDetector(
              onTap: () {
                _sendMessage(text: _messageController.text);
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFF204CB3),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.send, color: Colors.white, size: 20.sp),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BouncingDots extends StatefulWidget {
  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double delay = index * 0.2;
            double value = (_controller.value - delay).clamp(0.0, 1.0);
            if (value > 0.5) value = 1.0 - value;
            return Transform.translate(
              offset: Offset(0, -6 * value * 2),
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 2.w),
                width: 6.w,
                height: 6.w,
                decoration: const BoxDecoration(
                  color: Color(0xFF9E9E9E),
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
