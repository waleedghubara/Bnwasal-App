import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:admin_bnwasal/core/theme/colors.dart';
import '../cubit/captains_cubit.dart';
import '../cubit/captains_state.dart';

class CaptainCreateScreen extends StatefulWidget {
  const CaptainCreateScreen({super.key});

  @override
  State<CaptainCreateScreen> createState() => _CaptainCreateScreenState();
}

class _CaptainCreateScreenState extends State<CaptainCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nationalIdCtrl = TextEditingController();
  XFile? _profileImage;
  XFile? _nationalIdFront;
  XFile? _nationalIdBack;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    _passwordCtrl.dispose();
    _nationalIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ValueChanged<XFile?> onPicked) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file != null) onPicked(file);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0a0a1a) : AppColors.background,
      appBar: AppBar(
        backgroundColor: isDark
            ? const Color(0xFF0a0a1a)
            : AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'إضافة كابتن جديد',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: BlocListener<CaptainsCubit, CaptainsState>(
        listenWhen: (prev, next) =>
            prev.isCreating != next.isCreating ||
            prev.createError != next.createError,
        listener: (context, state) {
          if (!state.isCreating && state.createError == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ تم إضافة الكابتن بنجاح')),
            );
            Navigator.pop(context, true);
          } else if (state.createError != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('❌ ${state.createError}')));
          }
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 48.w : 20.w,
            vertical: 24.h,
          ),
          child: Form(
            key: _formKey,
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            _buildSectionCard(
                              title: 'المعلومات الأساسية',
                              icon: Icons.person_outline_rounded,
                              children: [
                                _buildTextFieldRow(
                                  isWide,
                                  _buildTextField(
                                    _firstNameCtrl,
                                    'الاسم الأول',
                                    required: true,
                                    icon: Icons.badge_outlined,
                                  ),
                                  _buildTextField(
                                    _lastNameCtrl,
                                    'الاسم الأخير',
                                    required: true,
                                    icon: Icons.badge_outlined,
                                  ),
                                ),
                                SizedBox(height: 14.h),
                                _buildTextFieldRow(
                                  isWide,
                                  _buildTextField(
                                    _emailCtrl,
                                    'البريد الإلكتروني',
                                    required: true,
                                    keyboardType: TextInputType.emailAddress,
                                    icon: Icons.email_outlined,
                                  ),
                                  _buildTextField(
                                    _phoneCtrl,
                                    'رقم الهاتف',
                                    required: true,
                                    keyboardType: TextInputType.phone,
                                    icon: Icons.phone_outlined,
                                  ),
                                ),
                                SizedBox(height: 14.h),
                                _buildTextFieldRow(
                                  isWide,
                                  _buildTextField(
                                    _cityCtrl,
                                    'المدينة',
                                    required: true,
                                    icon: Icons.location_on_outlined,
                                  ),
                                  _buildPasswordField(),
                                ),
                              ],
                            ),
                            SizedBox(height: 24.h),
                            _buildSubmitButton(),
                          ],
                        ),
                      ),
                      SizedBox(width: 24.w),
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            _buildAvatarCard(),
                            SizedBox(height: 20.h),
                            _buildSectionCard(
                              title: 'الوثائق والبطاقة الشخصية',
                              icon: Icons.credit_card_outlined,
                              children: [
                                _buildTextField(
                                  _nationalIdCtrl,
                                  'رقم البطاقة الشخصية',
                                  required: true,
                                  icon: Icons.badge_outlined,
                                ),
                                SizedBox(height: 16.h),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDocRow(
                                        isWide,
                                        'البطاقة (الوجه الأمامي)',
                                        _nationalIdFront,
                                        (f) => setState(
                                          () => _nationalIdFront = f,
                                        ),
                                        required: true,
                                      ),
                                    ),
                                    SizedBox(width: 14.w),
                                    Expanded(
                                      child: _buildDocRow(
                                        isWide,
                                        'البطاقة (الوجه الخلفي)',
                                        _nationalIdBack,
                                        (f) =>
                                            setState(() => _nationalIdBack = f),
                                        required: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildAvatarSection(),
                      SizedBox(height: 24.h),
                      _buildSectionCard(
                        title: 'المعلومات الأساسية',
                        icon: Icons.person_outline_rounded,
                        children: [
                          _buildTextFieldRow(
                            isWide,
                            _buildTextField(
                              _firstNameCtrl,
                              _firstNameCtrl.text.isEmpty
                                  ? 'الاسم الأول'
                                  : _firstNameCtrl.text,
                              required: true,
                              icon: Icons.badge_outlined,
                            ),
                            _buildTextField(
                              _lastNameCtrl,
                              _lastNameCtrl.text.isEmpty
                                  ? 'الاسم الأخير'
                                  : _lastNameCtrl.text,
                              required: true,
                              icon: Icons.badge_outlined,
                            ),
                          ),
                          SizedBox(height: 14.h),
                          _buildTextFieldRow(
                            isWide,
                            _buildTextField(
                              _emailCtrl,
                              'البريد الإلكتروني',
                              required: true,
                              keyboardType: TextInputType.emailAddress,
                              icon: Icons.email_outlined,
                            ),
                            _buildTextField(
                              _phoneCtrl,
                              'رقم الهاتف',
                              required: true,
                              keyboardType: TextInputType.phone,
                              icon: Icons.phone_outlined,
                            ),
                          ),
                          SizedBox(height: 14.h),
                          _buildTextFieldRow(
                            isWide,
                            _buildTextField(
                              _cityCtrl,
                              'المدينة',
                              required: true,
                              icon: Icons.location_on_outlined,
                            ),
                            _buildPasswordField(),
                          ),
                        ],
                      ),
                      SizedBox(height: 20.h),
                      _buildSectionCard(
                        title: 'الوثائق',
                        icon: Icons.credit_card_outlined,
                        children: [
                          _buildTextField(
                            _nationalIdCtrl,
                            'رقم البطاقة الشخصية',
                            required: true,
                            icon: Icons.badge_outlined,
                          ),
                          SizedBox(height: 14.h),
                          _buildDocRow(
                            isWide,
                            'البطاقة (الوجه الأمامي)',
                            _nationalIdFront,
                            (f) => setState(() => _nationalIdFront = f),
                            required: true,
                          ),
                          SizedBox(height: 14.h),
                          _buildDocRow(
                            isWide,
                            'البطاقة (الوجه الخلفي)',
                            _nationalIdBack,
                            (f) => setState(() => _nationalIdBack = f),
                            required: true,
                          ),
                        ],
                      ),
                      SizedBox(height: 32.h),
                      _buildSubmitButton(),
                      SizedBox(height: 40.h),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.015),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.03),
        ),
      ),
      child: Column(
        children: [
          Text(
            'الصورة الشخصية للكابتن',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.8)
                  : Colors.black.withValues(alpha: 0.4),
            ),
          ),
          SizedBox(height: 16.h),
          _buildAvatarSection(),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _pickImage((f) => setState(() => _profileImage = f)),
      child: Stack(
        children: [
          Container(
            width: 110.w,
            height: 110.w,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF004aad), Color(0xFFF78710)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF004aad).withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: _profileImage != null
                ? Image.file(File(_profileImage!.path), fit: BoxFit.cover)
                : Icon(
                    Icons.person_rounded,
                    size: 48,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 30.w,
              height: 30.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF0a0a1a) : AppColors.background,
                border: Border.all(color: const Color(0xFF004aad), width: 2),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                size: 14,
                color: Color(0xFF004aad),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.015),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.03),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18.sp, color: const Color(0xFF004aad)),
              SizedBox(width: 8.w),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Divider(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.03),
            height: 1,
          ),
          SizedBox(height: 16.h),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextFieldRow(bool isWide, Widget first, Widget second) {
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: first),
          SizedBox(width: 16.w),
          Expanded(child: second),
        ],
      );
    }
    return Column(
      children: [
        first,
        SizedBox(height: 14.h),
        second,
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label, {
    TextInputType? keyboardType,
    bool required = false,
    IconData? icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          required ? '$label *' : label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: isDark
                ? Colors.white.withValues(alpha: 0.6)
                : Colors.black.withValues(alpha: 0.3),
          ),
        ),
        SizedBox(height: 6.h),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: TextStyle(
            fontSize: 14.sp,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
          validator: required
              ? (v) => (v == null || v.trim().isEmpty) ? '$label مطلوب' : null
              : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.02),
            prefixIcon: icon != null
                ? Icon(
                    icon,
                    size: 18.sp,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.15),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 14.h,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'كلمة المرور *',
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: isDark
                ? Colors.white.withValues(alpha: 0.6)
                : Colors.black.withValues(alpha: 0.3),
          ),
        ),
        SizedBox(height: 6.h),
        TextFormField(
          controller: _passwordCtrl,
          obscureText: _obscurePassword,
          style: TextStyle(
            fontSize: 14.sp,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'كلمة المرور مطلوبة';
            if (v.length < 6) return 'كلمة المرور قصيرة (6 أحرف على الأقل)';
            return null;
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.02),
            prefixIcon: Icon(
              Icons.lock_outlined,
              size: 18.sp,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.15),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.15),
                size: 18.sp,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 14.h,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocRow(
    bool isWide,
    String label,
    XFile? file,
    ValueChanged<XFile?> onPicked, {
    bool required = false,
  }) {
    final child = _buildDocPicker(label, file, onPicked, required: required);
    if (isWide) return child;
    return child;
  }

  Widget _buildDocPicker(
    String label,
    XFile? file,
    ValueChanged<XFile?> onPicked, {
    bool required = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          required ? '$label *' : label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: isDark
                ? Colors.white.withValues(alpha: 0.6)
                : Colors.black.withValues(alpha: 0.3),
          ),
        ),
        SizedBox(height: 6.h),
        GestureDetector(
          onTap: () => _pickImage(onPicked),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 300),
            height: 200.h,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: file != null
                    ? const Color(0xFF10b981).withValues(alpha: 0.5)
                    : isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.03),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: file != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(
                        child: Image.file(File(file.path), fit: BoxFit.contain),
                      ),
                      Positioned(
                        top: 6.h,
                        right: 6.w,
                        child: GestureDetector(
                          onTap: () => onPicked(null),
                          child: Container(
                            padding: EdgeInsets.all(4.w),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.6),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.3)
                                    : Colors.black.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Icon(
                              Icons.close,
                              size: 12.sp,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 6.h,
                        left: 6.w,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 9.sp,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : Colors.black.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48.w,
                          height: 48.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(
                              0xFF004aad,
                            ).withValues(alpha: 0.15),
                          ),
                          child: Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 22.sp,
                            color: const Color(0xFF004aad),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'اضغط لاختيار صورة',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.4)
                                : Colors.black.withValues(alpha: 0.2),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return BlocBuilder<CaptainsCubit, CaptainsState>(
      builder: (context, state) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return SizedBox(
          width: double.infinity,
          height: 54.h,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFF004aad), Color(0xFF007aff)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF004aad).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: state.isCreating ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: state.isCreating
                  ? SizedBox(
                      width: 24.w,
                      height: 24.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          size: 20.sp,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'إضافة الكابتن',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_nationalIdFront == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ يرجى اختيار صورة البطاقة (الوجه الأمامي)'),
        ),
      );
      return;
    }
    if (_nationalIdBack == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ يرجى اختيار صورة البطاقة (الوجه الخلفي)'),
        ),
      );
      return;
    }
    final data = <String, dynamic>{
      'firstName': _firstNameCtrl.text.trim(),
      'lastName': _lastNameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'password': _passwordCtrl.text,
      'nationalId': _nationalIdCtrl.text.trim(),
      'role': 'captain',
    };
    context.read<CaptainsCubit>().createCaptain(
      data,
      profileImagePath: _profileImage?.path,
      nationalIdFrontPath: _nationalIdFront?.path,
      nationalIdBackPath: _nationalIdBack?.path,
    );
  }
}
