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

enum AccountType { merchant, captain, rider }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _currentStep = 0;
  AccountType? _selectedType;
  bool _agreeToTerms = false;
  bool _obscurePassword = true;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _referralCodeController = TextEditingController();
  File? _profileImage;
  final _picker = ImagePicker();
  bool _isRegistering = false;

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
        imageQuality: 70,
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
          onPressed: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          'إنشاء حساب',
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
              // Save registration details to SharedPreferences to resume verify flow if app is closed
              SharedPreferences.getInstance().then((prefs) {
                prefs.setString('pending_otp_email', registeredPhone);
                prefs.setString('pending_otp_code', state.otpCode);
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message, textAlign: TextAlign.right),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              Navigator.pushNamed(
                context,
                Routes.otp,
                arguments: {'phone': registeredPhone, 'otpCode': state.otpCode},
              );
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
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _currentStep == 0
                    ? _buildSelectionStep()
                    : _buildFormStep(state is AuthLoading),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSelectionStep() {
    return Column(
      key: const ValueKey(0),
      children: [
        Image.asset(AppAssets.appLogo2, width: 120, height: 120),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const Text(
              'إنشاء حساب',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _selectedType == AccountType.captain
                  ? 'أنشئ حسابك الآن واستفد من خدمات شراء الطلبات، الشحن، والتوصيل بكل سهولة وسرعة وأمان'
                  : _selectedType == AccountType.merchant
                  ? 'أنشئ حسابك الآن واستفد من خدمات شراء الطلبات،الشحن، والتوصيل بكل سهولة وسرعة وأمان.'
                  : 'أنشئ حسابك الآن واستفد من خدمات شراء الطلبات،الشحن، والتوصيل بكل سهولة وسرعة وأمان.',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        _buildTypeCard(
          type: AccountType.merchant,
          title: 'تاجر او عميل',
          description:
              'اذا كنت تاجر تريد شحن منتجاتك واوردراتك او عميل تريد مندوب لشراء وتوصيل احتياجاتك  ',
          icon: AppAssets.shop,
        ),
        const SizedBox(height: 16),
        _buildTypeCard(
          type: AccountType.captain,
          title: 'كابتن توصيل',
          description:
              'انضم إلى شبكة مندوبي بنوصل واستقبل طلبات التوصيل في منطقتك وزيادة دخلك بمرونة',
          icon: AppAssets.rider,
        ),
        const SizedBox(height: 40),
        CustomButton(
          text: 'التالي',
          onPressed: _selectedType != null
              ? () => setState(() => _currentStep = 1)
              : () {},
          color: _selectedType != null
              ? AppColors.primary
              : Colors.grey.shade400,
          textColor: Colors.white,
          borderRadius: 16,
          height: 56,
        ),
        const SizedBox(height: 24),
        _buildLoginLink(),
      ],
    );
  }

  Widget _buildFormStep(bool isLoading) {
    String title = _selectedType == AccountType.merchant
        ? 'إنشاء حساب التاجر / مستخدم'
        : 'إنشاء حساب كابتن توصيل';
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: Image.asset(AppAssets.appLogo2, width: 100, height: 100)),
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _selectedType == AccountType.captain
              ? 'قم بإنشاء حسابك لتبدأ استقبال طلبات التوصيل وإدارة رحلاتك وزيادة دخلك بكل سهولة'
              : 'قم بانشاء حسابك لتمكن من اضافة منتجاتك و ادارتها بسهولة و كيفية تنظيم عملية التوصيل لعملائك',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 30),
        GestureDetector(
          onTap: _pickImage,
          child: Center(
            child: Stack(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _profileImage != null
                        ? Image.file(_profileImage!, fit: BoxFit.cover)
                        : Center(
                            child: Image.asset(
                              AppAssets.group,
                              width: 80,
                              height: 80,
                            ),
                          ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.camera,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 30),
        _buildLabel('الاسم الاول'),
        CustomTextField(
          controller: _firstNameController,
          hintText: 'الاسم الاول',
          rightWidget: Padding(
            padding: const EdgeInsets.all(8.0),
            child: FaIcon(
              FontAwesomeIcons.user,
              color: AppColors.primary,
              size: 18,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildLabel('الاسم الاخير'),
        CustomTextField(
          controller: _lastNameController,
          hintText: 'الاسم الاخير',
          rightWidget: Padding(
            padding: const EdgeInsets.all(8.0),
            child: FaIcon(
              FontAwesomeIcons.userAlt,
              color: AppColors.primary,
              size: 18,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildLabel('رقم الهاتف'),
        CustomTextField(
          controller: _phoneController,
          hintText: 'رقم الهاتف',
          // maxLength: 11,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          rightWidget: Padding(
            padding: const EdgeInsets.all(8.0),
            child: FaIcon(
              FontAwesomeIcons.phone,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        _buildLabel('كلمة المرور'),
        CustomTextField(
          controller: _passwordController,
          hintText: 'كلمة المرور',
          obscureText: _obscurePassword,
          rightWidget: Padding(
            padding: const EdgeInsets.all(8.0),
            child: FaIcon(
              FontAwesomeIcons.lock,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          leftWidget: IconButton(
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            icon: FaIcon(
              _obscurePassword
                  ? FontAwesomeIcons.eyeSlash
                  : FontAwesomeIcons.eye,
              color: AppColors.primary,
              size: 18,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildLabel('كود الدعوة (اختياري)'),
        CustomTextField(
          controller: _referralCodeController,
          hintText: 'أدخل كود الدعوة إن وُجد',
          rightWidget: Padding(
            padding: const EdgeInsets.all(8.0),
            child: FaIcon(
              FontAwesomeIcons.gift,
              color: AppColors.primary,
              size: 18,
            ),
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
            const Text('اوافق علي ', style: TextStyle(fontSize: 14)),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, Routes.termsConditions),
              child: const Text(
                'الشروط و الاحكام',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        CustomButton(
          text: 'التالي',
          isLoading: isLoading || _isRegistering,
          onPressed: _agreeToTerms
              ? () {
                  if (_isRegistering) return;

                  final firstName = _firstNameController.text.trim();
                  final lastName = _lastNameController.text.trim();
                  final phone = _phoneController.text.trim();
                  final password = _passwordController.text.trim();
                  final referralCode = _referralCodeController.text.trim();

                  if (_profileImage == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'الرجاء اختيار صورة شخصية أولاً',
                          textAlign: TextAlign.right,
                        ),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }

                  if (firstName.isEmpty || lastName.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'الرجاء إدخال الاسم الأول والأخير',
                          textAlign: TextAlign.right,
                        ),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }

                  if (phone.isEmpty || phone.length < 11) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'الرجاء إدخال رقم هاتف صحيح مكون من 11 رقماً',
                          textAlign: TextAlign.right,
                        ),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }

                  if (password.isEmpty || password.length < 6) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'الرجاء إدخال كلمة مرور لا تقل عن 6 أحرف',
                          textAlign: TextAlign.right,
                        ),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }

                  FocusScope.of(context).unfocus();
                  setState(() => _isRegistering = true);
                  context.read<AuthCubit>().register(
                    firstName: firstName,
                    lastName: lastName,
                    phone: phone,
                    password: password,
                    role: _selectedType == AccountType.merchant
                        ? 'merchant'
                        : 'captain',
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
        const SizedBox(height: 24),
        _buildLoginLink(),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildTypeCard({
    required AccountType type,
    required String title,
    required String description,
    required String icon,
  }) {
    bool isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Image.asset(icon, width: 60, height: 60),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
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
          'لديك حساب بالفعل ؟ ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'تسجيل دخول',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
