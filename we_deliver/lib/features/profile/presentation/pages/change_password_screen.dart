import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:we_deliver/core/theme/colors.dart';
import 'package:we_deliver/core/widgets/custom_text_field.dart';
import '../bloc/profile_cubit.dart';
import '../bloc/profile_state.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'تعديل كلمة المرور',
          style: TextStyle(
            color: const Color(0xFF333333),
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: const Color(0xFF333333),
            size: 20.sp,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        automaticallyImplyLeading: false,
      ),
      body: BlocConsumer<ProfileCubit, ProfileState>(
        listener: (context, state) {
          if (state is ChangePasswordSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.message,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.pop(context);
          } else if (state is ChangePasswordError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.message,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is ChangePasswordLoading;
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 40.h),
                _buildFieldLabel('كلمة المرور الحالية'),
                SizedBox(height: 8.h),
                _buildPasswordField(
                  hint: 'كلمة المرور الحالية',
                  obscure: _obscureCurrent,
                  controller: _currentPasswordController,
                  onToggle: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                ),
                SizedBox(height: 20.h),
                _buildFieldLabel('كلمة المرور الجديدة'),
                SizedBox(height: 8.h),
                _buildPasswordField(
                  hint: 'كلمة المرور الجديدة',
                  obscure: _obscureNew,
                  controller: _newPasswordController,
                  onToggle: () => setState(() => _obscureNew = !_obscureNew),
                ),
                SizedBox(height: 20.h),
                _buildFieldLabel('تأكيد كلمة المرور الجديدة'),
                SizedBox(height: 8.h),
                _buildPasswordField(
                  hint: 'تأكيد كلمة المرور الجديدة',
                  obscure: _obscureConfirm,
                  controller: _confirmPasswordController,
                  onToggle: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
                SizedBox(height: 60.h),
                _buildSaveButton(isLoading),
                SizedBox(height: 40.h),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14.sp,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF333333),
      ),
    );
  }

  Widget _buildPasswordField({
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    TextEditingController? controller,
  }) {
    return CustomTextField(
      controller: controller ?? TextEditingController(),
      hintText: hint,
      obscureText: obscure,
      keyboardType: TextInputType.text,
      rightWidget: Padding(
        padding: EdgeInsets.only(right: 5.w),
        child: FaIcon(
          FontAwesomeIcons.lock,
          size: 20.sp,
          color: AppColors.primary,
        ),
      ),
      leftWidget: Padding(
        padding: EdgeInsets.only(left: 1.w),
        child: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: const Color(0xFFBDBDBD),
            size: 20.sp,
          ),
          onPressed: onToggle,
        ),
      ),
      onChanged: (value) {},
    );
  }

  Widget _buildSaveButton(bool isLoading) {
    return SizedBox(
      width: double.infinity,
      height: 54.h,
      child: ElevatedButton(
        onPressed: isLoading
            ? null
            : () {
                final current = _currentPasswordController.text;
                final newPass = _newPasswordController.text;
                final confirm = _confirmPasswordController.text;

                if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('يرجى ملء جميع الحقول', textAlign: TextAlign.right),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                if (newPass.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('كلمة المرور الجديدة يجب أن تكون 6 أحرف على الأقل', textAlign: TextAlign.right),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                if (newPass != confirm) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('كلمتا المرور غير متطابقتين', textAlign: TextAlign.right),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                if (current == newPass) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('كلمة المرور الجديدة يجب أن تكون مختلفة عن الحالية', textAlign: TextAlign.right),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                context.read<ProfileCubit>().changePassword(
                      currentPassword: current,
                      newPassword: newPass,
                    );
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF204CB3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                'حفظ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
