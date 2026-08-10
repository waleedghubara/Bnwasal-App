// ignore_for_file: deprecated_member_use

import 'package:admin_bnwasal/core/theme/app_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/colors.dart';
import '../../../core/routes/routes.dart';
import '../../../core/routes/app_router.dart';
import 'cubit/auth_cubit.dart';
import 'cubit/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool('remember_me') ?? false;
    if (saved) {
      final email = prefs.getString('remember_email') ?? '';
      const storage = FlutterSecureStorage();
      final password = await storage.read(key: 'remember_password') ?? '';
      if (email.isNotEmpty) {
        _emailCtrl.text = email;
        _passCtrl.text = password;
        setState(() => _rememberMe = true);
      }
    }
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    const storage = FlutterSecureStorage();
    if (_rememberMe) {
      await prefs.setBool('remember_me', true);
      await prefs.setString('remember_email', _emailCtrl.text.trim());
      await storage.write(key: 'remember_password', value: _passCtrl.text);
    } else {
      await prefs.remove('remember_me');
      await prefs.remove('remember_email');
      await storage.delete(key: 'remember_password');
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthCubit>().login(_emailCtrl.text.trim(), _passCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    return Scaffold(
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state.isAuthenticated) {
            _saveCredentials();
            AppRouter.navigateAndReplace(context, Routes.home);
          }
        },
        builder: (context, state) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF0a0a1a),
                        const Color(0xFF0d0d2b),
                        const Color(0xFF1a0a2e),
                        const Color(0xFF0a0a1a),
                      ]
                    : [
                        const Color(0xFFf8f9fa),
                        const Color(0xFFe9ecef),
                        const Color(0xFFdee2e6),
                        const Color(0xFFf8f9fa),
                      ],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 80.w : 24.w,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isTablet ? 500.w : 420.w,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo
                        _buildLogo(isTablet),
                        SizedBox(height: isTablet ? 48.h : 40.h),

                        // Login card
                        Container(
                          padding: EdgeInsets.all(isTablet ? 40.w : 28.w),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade300,
                            ),
                            boxShadow: isDark
                                ? []
                                : [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'تسجيل الدخول',
                                  style: TextStyle(
                                    fontSize: isTablet ? 26.sp : 22.sp,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 6.h),
                                Text(
                                  'لوحة تحكم بنوصل الإدارية',
                                  style: TextStyle(
                                    fontSize: isTablet ? 15.sp : 13.sp,
                                    color: isDark ? Colors.white.withOpacity(0.4) : Colors.black54,
                                  ),
                                ),
                                SizedBox(height: isTablet ? 32.h : 28.h),

                                _buildLabel('البريد الإلكتروني', isTablet),
                                SizedBox(height: 8.h),
                                _buildEmailField(isTablet),
                                SizedBox(height: 20.h),

                                _buildLabel('كلمة المرور', isTablet),
                                SizedBox(height: 8.h),
                                _buildPasswordField(isTablet),
                                SizedBox(height: 16.h),

                                // Remember me + Forgot
                                Row(
                                  children: [
                                    SizedBox(
                                      height: 24,
                                      child: Checkbox(
                                        value: _rememberMe,
                                        onChanged: (v) => setState(
                                          () => _rememberMe = v ?? false,
                                        ),
                                        fillColor:
                                            WidgetStateProperty.resolveWith((
                                              states,
                                            ) {
                                              if (states.contains(
                                                WidgetState.selected,
                                              )) {
                                                return AppColors.primary;
                                              }
                                              return Colors.white.withOpacity(
                                                0.1,
                                              );
                                            }),
                                        checkColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      'تذكرني',
                                      style: TextStyle(
                                        fontSize: isTablet ? 14.sp : 12.sp,
                                        color: isDark ? Colors.white.withOpacity(0.5) : Colors.black54,
                                      ),
                                    ),
                                    const Spacer(),
                                    GestureDetector(
                                      onTap: () {},
                                      child: Text(
                                        'نسيت كلمة المرور؟',
                                        style: TextStyle(
                                          fontSize: isTablet ? 13.sp : 12.sp,
                                          color: isDark ? Colors.cyan.withOpacity(0.7) : AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: isTablet ? 32.h : 28.h),

                                // Error
                                if (state.errorMessage != null)
                                  Container(
                                    padding: EdgeInsets.all(12.w),
                                    margin: EdgeInsets.only(bottom: 16.h),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.red.withOpacity(0.2),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          color: Colors.red,
                                          size: isTablet ? 20.sp : 18.sp,
                                        ),
                                        SizedBox(width: 8.w),
                                        Flexible(
                                          child: Text(
                                            state.errorMessage!,
                                            style: TextStyle(
                                              fontSize: isTablet
                                                  ? 14.sp
                                                  : 12.sp,
                                              color: Colors.red.shade200,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                // Submit
                                SizedBox(
                                  width: double.infinity,
                                  height: isTablet ? 56.h : 50.h,
                                  child: ElevatedButton(
                                    onPressed: state.isLoading ? null : _submit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: state.isLoading
                                        ? SizedBox(
                                            width: 22.w,
                                            height: 22.w,
                                            child:
                                                const CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  color: Colors.white,
                                                ),
                                          )
                                        : Text(
                                            'تسجيل الدخول',
                                            style: TextStyle(
                                              fontSize: isTablet
                                                  ? 16.sp
                                                  : 14.sp,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: isTablet ? 32.h : 24.h),
                        Text(
                          'v1.0.0',
                          style: TextStyle(
                            fontSize: isTablet ? 13.sp : 11.sp,
                            color: isDark ? Colors.white.withOpacity(0.12) : Colors.black26,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogo(bool isTablet) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        ClipOval(
          child: Image.asset(
            AppAssets.appLogo2,
            width: isTablet ? 100.w : 80.w,
            height: isTablet ? 100.w : 80.w,
            errorBuilder: (_, _, _) => Center(
              child: Text(
                'ب',
                style: TextStyle(
                  fontSize: isTablet ? 40.sp : 32.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),

        SizedBox(height: isTablet ? 14.h : 12.h),
        Text(
          'بنواصل أدمن',
          style: TextStyle(
            fontSize: isTablet ? 23.sp : 24.sp,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text, bool isTablet) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        fontSize: isTablet ? 14.sp : 13.sp,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white.withOpacity(0.7) : Colors.black87,
      ),
    );
  }

  Widget _buildEmailField(bool isTablet) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: _emailCtrl,
      keyboardType: TextInputType.emailAddress,
      textDirection: TextDirection.rtl,
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'البريد الإلكتروني مطلوب' : null,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: isTablet ? 15.sp : 14.sp),
      decoration: _inputDecoration(
        'أدخل البريد الإلكتروني',
        isTablet,
        Icons.email_outlined,
      ),
    );
  }

  Widget _buildPasswordField(bool isTablet) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: _passCtrl,
      obscureText: _obscurePass,
      textDirection: TextDirection.rtl,
      validator: (v) => (v == null || v.length < 6)
          ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل'
          : null,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: isTablet ? 15.sp : 14.sp),
      decoration:
          _inputDecoration(
            'أدخل كلمة المرور',
            isTablet,
            Icons.lock_outlined,
          ).copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePass
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: isDark ? Colors.white.withOpacity(0.4) : Colors.black38,
                size: isTablet ? 22.sp : 20.sp,
              ),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
          ),
    );
  }

  InputDecoration _inputDecoration(String hint, bool isTablet, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: hint,
      hintTextDirection: TextDirection.rtl,
      hintStyle: TextStyle(
        color: isDark ? Colors.white.withOpacity(0.25) : Colors.black38,
        fontSize: isTablet ? 14.sp : 13.sp,
      ),
      prefixIcon: Icon(
        icon,
        color: isDark ? Colors.white.withOpacity(0.3) : Colors.black38,
        size: isTablet ? 22.sp : 20.sp,
      ),
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF004aad), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.red.withOpacity(0.5)),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16.w,
        vertical: isTablet ? 18.h : 14.h,
      ),
    );
  }
}
