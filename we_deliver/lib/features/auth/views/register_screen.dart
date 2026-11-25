// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:we_deliver/core/theme/colors.dart';
import 'package:we_deliver/core/widgets/custom_button.dart';
import 'package:we_deliver/core/widgets/custom_text_field.dart';
import 'package:we_deliver/core/theme/app_assets.dart';
import '../../../core/routes/routes.dart';
import '../logic/auth_cubit.dart';
import '../logic/auth_state.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _agreeToTerms = false;
  bool _obscurePassword = true;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _referralCodeController = TextEditingController();

  File? _profileImage;
  final _picker = ImagePicker();
  bool _isRegistering = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'اختر مصدر الصورة الشخصية',
                style: TextStyle(
                  fontSize: 18,
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primary),
                title: const Text('الكاميرا'),
                onTap: () {
                  Navigator.pop(context);
                  _processImagePick(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: AppColors.primary,
                ),
                title: const Text('المعرض'),
                onTap: () {
                  Navigator.pop(context);
                  _processImagePick(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processImagePick(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 75,
      );
      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر اختيار الصورة', textAlign: TextAlign.right),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.grey),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'إنشاء حساب جديد',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: BlocConsumer<AuthCubit, AuthState>(
          listener: (context, state) {
            if (state is RegisterSuccess) {
              setState(() {
                _isRegistering = false;
              });
              final registeredPhone = _phoneController.text.trim();
              SharedPreferences.getInstance().then((prefs) {
                prefs.setString('pending_otp_email', registeredPhone);
                prefs.setString('pending_otp_code', state.otpCode);
                prefs.setString('user_role', 'client');
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message, textAlign: TextAlign.right),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
              final returnOnSuccess = args?['returnOnSuccess'] == true;

              Navigator.pushNamed(
                context,
                Routes.otp,
                arguments: {
                  'phone': registeredPhone,
                  'otpCode': state.otpCode,
                  'returnOnSuccess': returnOnSuccess,
                },
              ).then((result) {
                if (result == true && returnOnSuccess && context.mounted) {
                  Navigator.pop(context, true);
                }
              });
            } else if (state is AuthError) {
              setState(() {
                _isRegistering = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message, textAlign: TextAlign.right),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          builder: (context, state) {
            final isLoading = state is AuthLoading;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Image.asset(AppAssets.appLogo2, width: 85, height: 85),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'إنشاء حساب عميل',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'قم بإنشاء حسابك للطلب من أفضل المطاعم والمتاجر وتوصيل احتياجاتك بكل سهولة',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Photo Picker
                  GestureDetector(
                    onTap: _pickImage,
                    child: Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.3),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.08),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: _profileImage != null
                                  ? Image.file(_profileImage!, fit: BoxFit.cover)
                                  : Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: const [
                                          Icon(
                                            Icons.person_outline,
                                            size: 36,
                                            color: AppColors.primary,
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'الصورة',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const FaIcon(
                                FontAwesomeIcons.camera,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildLabel('الاسم الأول'),
                  CustomTextField(
                    controller: _firstNameController,
                    hintText: 'الاسم الأول',
                    rightWidget: const Padding(
                      padding: EdgeInsets.all(10.0),
                      child: FaIcon(FontAwesomeIcons.user, color: AppColors.primary, size: 16),
                    ),
                  ),
                  const SizedBox(height: 14),

                  _buildLabel('الاسم الأخير'),
                  CustomTextField(
                    controller: _lastNameController,
                    hintText: 'الاسم الأخير',
                    rightWidget: const Padding(
                      padding: EdgeInsets.all(10.0),
                      child: FaIcon(FontAwesomeIcons.userAlt, color: AppColors.primary, size: 16),
                    ),
                  ),
                  const SizedBox(height: 14),

                  _buildLabel('رقم الهاتف'),
                  CustomTextField(
                    controller: _phoneController,
                    hintText: '01xxxxxxxxx',
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                    ],
                    rightWidget: const Padding(
                      padding: EdgeInsets.all(10.0),
                      child: FaIcon(FontAwesomeIcons.phone, color: AppColors.primary, size: 16),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),

                  _buildLabel('البريد الإلكتروني (اختياري)'),
                  CustomTextField(
                    controller: _emailController,
                    hintText: 'example@domain.com',
                    rightWidget: const Padding(
                      padding: EdgeInsets.all(10.0),
                      child: FaIcon(FontAwesomeIcons.envelope, color: AppColors.primary, size: 16),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),

                  _buildLabel('كلمة المرور'),
                  CustomTextField(
                    controller: _passwordController,
                    hintText: '••••••••',
                    obscureText: _obscurePassword,
                    rightWidget: const Padding(
                      padding: EdgeInsets.all(10.0),
                      child: FaIcon(FontAwesomeIcons.lock, color: AppColors.primary, size: 16),
                    ),
                    leftWidget: IconButton(
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      icon: FaIcon(
                        _obscurePassword ? FontAwesomeIcons.eyeSlash : FontAwesomeIcons.eye,
                        color: AppColors.primary,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  _buildLabel('كود الدعوة / الإحالة (اختياري)'),
                  CustomTextField(
                    controller: _referralCodeController,
                    hintText: 'أدخل كود الدعوة أو رقم هاتف الصديق إن وُجد',
                    rightWidget: const Padding(
                      padding: EdgeInsets.all(10.0),
                      child: FaIcon(FontAwesomeIcons.gift, color: AppColors.primary, size: 16),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Checkbox(
                        value: _agreeToTerms,
                        onChanged: (val) => setState(() => _agreeToTerms = val ?? false),
                        activeColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const Text('أوافق على ', style: TextStyle(fontSize: 13.5)),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, Routes.termsConditions),
                        child: const Text(
                          'شروط الخدمة وسياسة الخصوصية',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),

                  CustomButton(
                    text: 'إنشاء الحساب وتأكيد الهاتف',
                    isLoading: isLoading || _isRegistering,
                    onPressed: _agreeToTerms
                        ? () {
                            if (_isRegistering) return;

                            final firstName = _firstNameController.text.trim();
                            final lastName = _lastNameController.text.trim();

                            if (firstName.isEmpty || lastName.isEmpty) {
                              _showError('الرجاء إدخال الاسم الأول والأخير');
                              return;
                            }

                            final phone = _phoneController.text.trim();
                            final email = _emailController.text.trim();
                            final password = _passwordController.text.trim();
                            final referralCode = _referralCodeController.text.trim();

                            if (phone.isEmpty || phone.length < 11) {
                              _showError('الرجاء إدخال رقم هاتف صحيح مكون من 11 رقماً');
                              return;
                            }

                            if (password.isEmpty || password.length < 6) {
                              _showError('الرجاء إدخال كلمة مرور لا تقل عن 6 أحرف');
                              return;
                            }

                            FocusScope.of(context).unfocus();
                            setState(() => _isRegistering = true);

                            context.read<AuthCubit>().register(
                              firstName: firstName,
                              lastName: lastName,
                              email: email.isNotEmpty ? email : null,
                              phone: phone,
                              password: password,
                              role: 'client',
                              profileImage: _profileImage,
                              referralCode: referralCode.isNotEmpty ? referralCode : null,
                            );
                          }
                        : () {},
                    color: _agreeToTerms ? AppColors.primary : Colors.grey.shade400,
                    textColor: Colors.white,
                    borderRadius: 16,
                    height: 56,
                  ),
                  const SizedBox(height: 20),
                  _buildLoginLink(),
                  const SizedBox(height: 35),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.right),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, right: 4.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'لديك حساب بالفعل؟',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pushReplacementNamed(context, Routes.login),
          child: const Text(
            'تسجيل الدخول',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
