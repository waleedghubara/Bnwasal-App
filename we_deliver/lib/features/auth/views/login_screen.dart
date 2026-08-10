// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:we_deliver/core/theme/app_assets.dart';
import 'package:we_deliver/core/theme/colors.dart';
import 'package:we_deliver/core/widgets/custom_button.dart';
import 'package:we_deliver/core/widgets/custom_text_field.dart';
import 'dart:convert';
import '../../../core/api/end_point.dart';
import '../domain/entities/user_entity.dart';
import '../../../core/routes/routes.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/services/appsflyer_service.dart';
import '../logic/auth_cubit.dart';
import '../logic/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool obscureText = true;
  bool _rememberMe = false;
  List<SavedAccount> _savedAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadSavedAccounts();
  }

  Future<void> _loadSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('saved_accounts_list') ?? '[]';
    try {
      final List<dynamic> decoded = json.decode(jsonStr);
      final accounts = decoded.map((e) => SavedAccount.fromJson(e)).toList();
      setState(() {
        _savedAccounts = accounts;
      });
      // Autofill the first account if remember_me is set and list is not empty
      final rememberMe = prefs.getBool('remember_me') ?? false;
      if (rememberMe && accounts.isNotEmpty) {
        setState(() {
          _phoneController.text = accounts.first.phone;
          _passwordController.text = accounts.first.password;
          _rememberMe = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading saved accounts: $e');
    }
  }

  Future<void> _saveOrClearCredentials(UserEntity user) async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      // 1. Save individual credentials for backwards compatibility
      await prefs.setString('saved_phone', _phoneController.text.trim());
      await prefs.setString('saved_password', _passwordController.text.trim());
      await prefs.setBool('remember_me', true);

      // 2. Save/Update in the accounts list
      final jsonStr = prefs.getString('saved_accounts_list') ?? '[]';
      List<SavedAccount> accounts = [];
      try {
        final List<dynamic> decoded = json.decode(jsonStr);
        accounts = decoded.map((e) => SavedAccount.fromJson(e)).toList();
      } catch (_) {}

      final existingIndex = accounts.indexWhere(
        (acc) => acc.phone == user.phone,
      );
      final newAccount = SavedAccount(
        id: user.id,
        firstName: user.firstName,
        lastName: user.lastName,
        phone: user.phone,
        password: _passwordController.text.trim(),
        role: user.role,
        profileImage: user.profileImage,
      );

      if (existingIndex != -1) {
        accounts[existingIndex] = newAccount;
      } else {
        accounts.add(newAccount);
      }

      await prefs.setString(
        'saved_accounts_list',
        json.encode(accounts.map((e) => e.toJson()).toList()),
      );
      setState(() {
        _savedAccounts = accounts;
      });
    } else {
      // Clear individual credentials
      await prefs.remove('saved_phone');
      await prefs.remove('saved_password');
      await prefs.setBool('remember_me', false);
    }
  }

  Future<void> _deleteAccount(SavedAccount account) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedAccounts.removeWhere((acc) => acc.id == account.id);
    });
    await prefs.setString(
      'saved_accounts_list',
      json.encode(_savedAccounts.map((e) => e.toJson()).toList()),
    );
    // If the currently autofilled phone matches the deleted account, clear fields
    if (_phoneController.text.trim() == account.phone) {
      setState(() {
        _phoneController.clear();
        _passwordController.clear();
        _rememberMe = false;
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: BlocConsumer<AuthCubit, AuthState>(
          listener: (context, state) {
            if (state is LoginSuccess) {
              _saveOrClearCredentials(state.authResponse.user);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'تم تسجيل الدخول بنجاح',
                    textAlign: TextAlign.right,
                  ),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              final user = state.authResponse.user;

              // Log AppsFlyer Login Event
              sl<AppsFlyerService>().setCustomerUserId(user.id.toString());
              sl<AppsFlyerService>().logEvent('af_login', {
                'user_id': user.id.toString(),
                'role': user.role,
              });

              final isCaptain = user.role == 'captain';
              final isProfileComplete = user.isProfileComplete ?? true;
              final missingDetailsList = user.missingDetails ?? [];

              if (!isProfileComplete) {
                if (missingDetailsList.contains('documents')) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    Routes.identityVerification,
                    (route) => false,
                    arguments: {'step': 'upload'},
                  );
                } else if (missingDetailsList.contains('vehicle')) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    Routes.identityVerification,
                    (route) => false,
                    arguments: {'step': 'selectVehicle'},
                  );
                } else {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    Routes.identityVerification,
                    (route) => false,
                  );
                }
              } else if (user.status == 'pending_verification') {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  Routes.pendingApproval,
                  (route) => false,
                );
              } else {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  Routes.mainLayout,
                  (route) => false,
                  arguments: {'isDelivery': isCaptain},
                );
              }
            } else if (state is LoginPendingApproval) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                Routes.pendingApproval,
                (route) => false,
                arguments: {'message': state.message},
              );
            } else if (state is LoginPendingOtp) {
              // Save login phone to SharedPreferences so the verify flow resumes if the app is closed
              SharedPreferences.getInstance().then((prefs) {
                prefs.setString('pending_otp_email', state.email);
                prefs.setString('pending_otp_code', '');
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message, textAlign: TextAlign.right),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              Navigator.pushNamed(
                context,
                Routes.otp,
                arguments: {'phone': state.email, 'otpCode': ''},
              );
            } else if (state is AuthError) {
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Image.asset(
                      AppAssets.appLogo2,
                      width: 120,
                      height: 120,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'تسجيل الدخول',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'قم بادخال بيانات الوصول الي حسابك و التمتع بجميع خدمات التطبيق بسهولة',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Saved Accounts List (if not empty)
                  if (_savedAccounts.isNotEmpty) ...[
                    const Text(
                      'الحسابات المحفوظة',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _savedAccounts.length,
                        itemBuilder: (context, index) {
                          final account = _savedAccounts[index];
                          final roleLabel = account.role == 'captain'
                              ? 'كابتن'
                              : account.role == 'merchant'
                              ? 'تاجر'
                              : 'موظف';
                          final imageUrl = account.profileImage != null
                              ? '${EndPoint.imageBaseUrl}${account.profileImage}'
                              : null;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _phoneController.text = account.phone;
                                _passwordController.text = account.password;
                                _rememberMe = true;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              width: 80,
                              child: Stack(
                                children: [
                                  Column(
                                    children: [
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: _phoneController.text.trim() ==
                                                    account.phone
                                                ? AppColors.primary
                                                : Colors.grey.shade200,
                                            width: 2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.05,
                                              ),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            28,
                                          ),
                                          child: imageUrl != null
                                              ? Image.network(
                                                  imageUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      const Icon(
                                                        Icons.person,
                                                        color: Colors.grey,
                                                      ),
                                                )
                                              : const Icon(
                                                  Icons.person,
                                                  color: Colors.grey,
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        account.firstName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        roleLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Positioned(
                                    top: 0,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => _deleteAccount(account),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          size: 10,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Phone ──
                  const Text(
                    'رقم الهاتف',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  CustomTextField(
                    controller: _phoneController,
                    hintText: 'رقم الهاتف',
                    keyboardType: TextInputType.phone,
                    rightWidget: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: FaIcon(
                        FontAwesomeIcons.phone,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Password ──
                  const Text(
                    'كلمة المرور',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  CustomTextField(
                    controller: _passwordController,
                    hintText: 'كلمة المرور',
                    obscureText: obscureText,
                    rightWidget: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: FaIcon(
                        FontAwesomeIcons.lock,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    leftWidget: GestureDetector(
                      onTap: () {
                        setState(() => obscureText = !obscureText);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: FaIcon(
                          obscureText
                              ? FontAwesomeIcons.eyeSlash
                              : FontAwesomeIcons.eye,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Remember Me + Forgot Password ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Remember Me
                      GestureDetector(
                        onTap: () => setState(() => _rememberMe = !_rememberMe),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: _rememberMe
                                    ? AppColors.primary
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _rememberMe
                                      ? AppColors.primary
                                      : Colors.grey.shade300,
                                  width: 2,
                                ),
                              ),
                              child: _rememberMe
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 14,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'تذكرني',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Forgot Password
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, Routes.forgotPassword);
                        },
                        child: const Text(
                          'نسيت كلمة المرور؟',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Login Button ──
                  CustomButton(
                    text: 'تسجيل الدخول',
                    isLoading: state is AuthLoading,
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      context.read<AuthCubit>().login(
                        email: _phoneController.text.trim(),
                        password: _passwordController.text.trim(),
                      );
                    },
                    textColor: Colors.white,
                    borderRadius: 16,
                    height: 56,
                    width: double.infinity,
                  ),
                  const SizedBox(height: 20),

                  // ── Register Link ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'ليس لديك حساب؟',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, Routes.register);
                        },
                        child: const Text(
                          'سجل حساب جديد',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class SavedAccount {
  final int id;
  final String firstName;
  final String lastName;
  final String phone;
  final String password;
  final String role;
  final String? profileImage;

  SavedAccount({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.password,
    required this.role,
    this.profileImage,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'firstName': firstName,
    'lastName': lastName,
    'phone': phone,
    'password': password,
    'role': role,
    'profileImage': profileImage,
  };

  factory SavedAccount.fromJson(Map<String, dynamic> json) => SavedAccount(
    id: json['id'] as int,
    firstName: json['firstName'] as String,
    lastName: json['lastName'] as String,
    phone: json['phone'] as String,
    password: json['password'] as String? ?? '',
    role: json['role'] as String,
    profileImage: json['profileImage'] as String?,
  );
}
