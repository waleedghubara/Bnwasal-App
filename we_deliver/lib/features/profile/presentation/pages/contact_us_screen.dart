// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animate_do/animate_do.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:we_deliver/core/routes/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../bloc/support_cubit.dart';
import '../bloc/support_state.dart';

class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  bool _isSending = false;
  String _whatsapp = '';
  String _facebook = '';
  String _instagram = '';
  String _twitter = '';
  String _linkedin = '';
  String _youtube = '';
  String _supportPhone = '';
  String _supportEmail = '';

  @override
  void initState() {
    super.initState();
    _loadSocialLinks();
  }

  Future<void> _loadSocialLinks() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _whatsapp = prefs.getString('social_whatsapp') ?? '';
        _facebook = prefs.getString('social_facebook') ?? '';
        _instagram = prefs.getString('social_instagram') ?? '';
        _twitter = prefs.getString('social_twitter') ?? '';
        _linkedin = prefs.getString('social_linkedin') ?? '';
        _youtube = prefs.getString('social_youtube') ?? '';
        _supportPhone = prefs.getString('support_phone') ?? '';
        _supportEmail = prefs.getString('support_email') ?? '';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      context.read<SupportCubit>().submitContactMessage(
        name: _nameController.text,
        email: _emailController.text,
        subject: _subjectController.text,
        message: _messageController.text,
      );
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ $label إلى الحافظة'),
        backgroundColor: const Color(0xFF204CB3),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
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
      child: BlocListener<SupportCubit, SupportState>(
        listener: (context, state) {
          if (state is ContactSending) {
            setState(() {
              _isSending = true;
            });
          } else if (state is ContactError) {
            setState(() {
              _isSending = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is ContactSuccess) {
            setState(() {
              _isSending = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 22.sp),
                    SizedBox(width: 8.w),
                    Text(state.message),
                  ],
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            );
            _nameController.clear();
            _emailController.clear();
            _subjectController.clear();
            _messageController.clear();
          }
        },
        child: Scaffold(
          backgroundColor: isDarkMode
              ? const Color(0xFF121212)
              : const Color(0xFFF7F9FC),
          appBar: AppBar(
            backgroundColor: isDarkMode
                ? const Color(0xFF1E1E1E)
                : Colors.white,
            elevation: 0,
            centerTitle: true,
            title: Text(
              'تواصل معنا',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios,
                color: isDarkMode ? Colors.white : Colors.black,
                size: 20.sp,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            automaticallyImplyLeading: false,
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Live Support Banner
                FadeInDown(
                  duration: const Duration(milliseconds: 400),
                  child: _buildLiveChatBanner(context, isDarkMode),
                ),
                SizedBox(height: 20.h),

                // Title for Support Channels
                FadeInUp(
                  duration: const Duration(milliseconds: 450),
                  child: Text(
                    'قنوات الاتصال المباشرة',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? Colors.white
                          : const Color(0xFF333333),
                    ),
                  ),
                ),
                SizedBox(height: 10.h),

                // Direct Contact Cards
                FadeInUp(
                  duration: const Duration(milliseconds: 500),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildContactCard(
                          iconWidget: FaIcon(
                            FontAwesomeIcons.whatsapp,
                            color: Colors.green,
                            size: 22.sp,
                          ),
                          title: 'واتساب',
                          subtitle: 'محادثة فورية',
                          iconColor: Colors.green,
                          onTap: () {
                            final number = _whatsapp.isNotEmpty
                                ? _whatsapp
                                : '+201033190080';
                            _copyToClipboard(number, 'رقم الواتساب');
                          },
                          isDarkMode: isDarkMode,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: _buildContactCard(
                          iconWidget: Icon(
                            Icons.phone_callback_rounded,
                            color: const Color(0xFF204CB3),
                            size: 22.sp,
                          ),
                          title: 'اتصال هاتفى',
                          subtitle: 'خدمة العملاء',
                          iconColor: const Color(0xFF204CB3),
                          onTap: () {
                            final phone = _supportPhone.isNotEmpty
                                ? _supportPhone
                                : '+201033190080';
                            _copyToClipboard(phone, 'رقم الهاتف');
                          },
                          isDarkMode: isDarkMode,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: _buildContactCard(
                          iconWidget: Icon(
                            Icons.alternate_email_rounded,
                            color: Colors.redAccent,
                            size: 22.sp,
                          ),
                          title: 'البريد',
                          subtitle: 'راسلنا مباشرة',
                          iconColor: Colors.redAccent,
                          onTap: () {
                            final email = _supportEmail.isNotEmpty
                                ? _supportEmail
                                : 'contact@bnwasal.com';
                            _copyToClipboard(email, 'البريد الإلكتروني');
                          },
                          isDarkMode: isDarkMode,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),

                _buildSocialLinksSection(isDarkMode),

                // Contact Form Title
                FadeInUp(
                  duration: const Duration(milliseconds: 550),
                  child: Text(
                    'أو اترك لنا رسالة مباشرة',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? Colors.white
                          : const Color(0xFF333333),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),

                // The Contact Form Card
                FadeInUp(
                  duration: const Duration(milliseconds: 600),
                  child: Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF1E1E1E)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: isDarkMode
                            ? Colors.transparent
                            : Colors.grey.shade200,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField(
                            controller: _nameController,
                            labelText: 'الاسم الكامل',
                            hintText: 'أدخل اسمك بالكامل',
                            prefixIcon: Icons.person_outline_rounded,
                            isDarkMode: isDarkMode,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'يرجى إدخال اسمك بالكامل';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16.h),
                          _buildTextField(
                            controller: _emailController,
                            labelText: 'البريد الإلكتروني',
                            hintText: 'أدخل بريدك الإلكتروني',
                            prefixIcon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            isDarkMode: isDarkMode,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'يرجى إدخال البريد الإلكتروني';
                              }
                              final emailRegex = RegExp(
                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                              );
                              if (!emailRegex.hasMatch(value)) {
                                return 'يرجى إدخال بريد إلكتروني صالح';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16.h),
                          _buildTextField(
                            controller: _subjectController,
                            labelText: 'موضوع الرسالة',
                            hintText: 'أدخل عنوان الموضوع',
                            prefixIcon: Icons.edit_note_rounded,
                            isDarkMode: isDarkMode,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'يرجى إدخال موضوع الرسالة';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16.h),
                          _buildTextField(
                            controller: _messageController,
                            labelText: 'تفاصيل الرسالة',
                            hintText: 'اكتب رسالتك أو استفسارك بالتفصيل هنا...',
                            prefixIcon: Icons.chat_bubble_outline_rounded,
                            maxLines: 4,
                            isDarkMode: isDarkMode,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'يرجى كتابة محتوى الرسالة';
                              }
                              if (value.trim().length < 10) {
                                return 'يجب ألا تقل الرسالة عن 10 أحرف';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 24.h),
                          _buildSubmitButton(),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveChatBanner(BuildContext context, bool isDarkMode) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF204CB3), Color(0xFF4A72D4)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF204CB3).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25.r,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Icon(
              Icons.support_agent_rounded,
              color: Colors.white,
              size: 28.sp,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الدعم الفني المباشر',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'دردشة فورية مع أحد ممثلي الخدمة لحل مشكلتك الآن',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, Routes.chatSupport);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF204CB3),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
            ),
            child: Text(
              'تحدث الآن',
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard({
    required Widget iconWidget,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 8.w),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: isDarkMode ? Colors.transparent : Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.01),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: iconWidget,
              ),
              SizedBox(height: 8.h),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : const Color(0xFF333333),
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.sp,
                  color: const Color(0xFF888888),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    required bool isDarkMode,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelText,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white70 : const Color(0xFF4A5568),
          ),
        ),
        SizedBox(height: 6.h),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          style: TextStyle(
            color: isDarkMode ? Colors.white : const Color(0xFF2D3748),
            fontSize: 14.sp,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: isDarkMode ? Colors.white30 : const Color(0xFFA0AEC0),
              fontSize: 13.sp,
            ),
            prefixIcon: Icon(
              prefixIcon,
              color: const Color(0xFF204CB3),
              size: 20.sp,
            ),
            filled: true,
            fillColor: isDarkMode
                ? const Color(0xFF2C2C2C)
                : const Color(0xFFF7FAFC),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: maxLines > 1 ? 16.h : 12.h,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: isDarkMode
                    ? Colors.transparent
                    : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(
                color: Color(0xFF204CB3),
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52.h,
      child: ElevatedButton(
        onPressed: _isSending ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF204CB3),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        child: _isSending
            ? SizedBox(
                width: 24.w,
                height: 24.w,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                'إرسال الرسالة',
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Widget _buildSocialLinksSection(bool isDarkMode) {
    final List<Map<String, dynamic>> activeLinks = [];
    if (_whatsapp.isNotEmpty) {
      activeLinks.add({
        'name': 'واتساب',
        'icon': FontAwesomeIcons.whatsapp,
        'color': const Color(0xFF25D366),
        'url': _whatsapp.startsWith('http')
            ? _whatsapp
            : 'https://wa.me/${_whatsapp.replaceAll('+', '')}',
      });
    }
    if (_facebook.isNotEmpty) {
      activeLinks.add({
        'name': 'فيسبوك',
        'icon': FontAwesomeIcons.facebook,
        'color': const Color(0xFF1877F2),
        'url': _facebook,
      });
    }
    if (_instagram.isNotEmpty) {
      activeLinks.add({
        'name': 'انستجرام',
        'icon': FontAwesomeIcons.instagram,
        'color': const Color(0xFFE4405F),
        'url': _instagram,
      });
    }
    if (_twitter.isNotEmpty) {
      activeLinks.add({
        'name': 'تويتر',
        'icon': FontAwesomeIcons.twitter,
        'color': const Color(0xFF1DA1F2),
        'url': _twitter,
      });
    }
    if (_linkedin.isNotEmpty) {
      activeLinks.add({
        'name': 'لينكد إن',
        'icon': FontAwesomeIcons.linkedin,
        'color': const Color(0xFF0A66C2),
        'url': _linkedin,
      });
    }
    if (_youtube.isNotEmpty) {
      activeLinks.add({
        'name': 'يوتيوب',
        'icon': FontAwesomeIcons.youtube,
        'color': const Color(0xFFFF0000),
        'url': _youtube,
      });
    }

    if (activeLinks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeInUp(
          duration: const Duration(milliseconds: 500),
          child: Text(
            'روابط التواصل الاجتماعي',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : const Color(0xFF333333),
            ),
          ),
        ),
        SizedBox(height: 12.h),
        FadeInUp(
          duration: const Duration(milliseconds: 550),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: isDarkMode ? Colors.transparent : Colors.grey.shade200,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.01),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Wrap(
              spacing: 16.w,
              runSpacing: 16.h,
              alignment: WrapAlignment.center,
              children: activeLinks.map((link) {
                return Tooltip(
                  message: link['name'],
                  child: InkWell(
                    onTap: () async {
                      final Uri url = Uri.parse(link['url']);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(12.r),
                    child: Container(
                      width: 50.w,
                      height: 50.w,
                      decoration: BoxDecoration(
                        color: link['color'].withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Center(
                        child: FaIcon(
                          link['icon'],
                          color: link['color'],
                          size: 24.sp,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        SizedBox(height: 24.h),
      ],
    );
  }
}
