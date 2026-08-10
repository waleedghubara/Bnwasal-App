// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:we_deliver/core/api/end_point.dart';
import 'package:we_deliver/core/cache/cache_helper.dart';
import 'package:we_deliver/core/routes/routes.dart';
import 'package:we_deliver/core/theme/app_assets.dart';
import 'package:we_deliver/core/theme/colors.dart';
import '../bloc/profile_cubit.dart';
import '../bloc/profile_state.dart';
import '../../../../core/utils/prefs_helper.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/appsflyer_service.dart';
import '../../domain/entities/user_entity.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ProfileCubit>().loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: BlocConsumer<ProfileCubit, ProfileState>(
          listener: (context, state) {
            if (state is ProfileUpdateSuccess) {
              context.read<ProfileCubit>().resetToLoaded();
            }
          },
          builder: (context, state) {
            if (state is ProfileLoading) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            if (state is ProfileError && state is! ProfileLoaded) {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 56,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        state.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () =>
                            context.read<ProfileCubit>().loadProfile(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final user = state is ProfileLoaded
                ? state.user
                : state is ProfileUpdating
                ? state.user
                : state is ProfileUpdateSuccess
                ? state.user
                : null;

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 24.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(user),
                    const SizedBox(height: 32),
                    _buildSectionTitle('الاعدادات'),
                    const SizedBox(height: 12),
                    _buildSettingsSection(context),
                    const SizedBox(height: 24),
                    _buildSectionTitle('الملف الشخصي'),
                    const SizedBox(height: 12),
                    _buildProfileSection(context, user),
                    const SizedBox(height: 24),
                    _buildSectionTitle('المساعدة'),
                    const SizedBox(height: 12),
                    _buildHelpSection(context),
                    const SizedBox(height: 24),
                    _buildLogoutButton(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(UserEntity? user) {
    final imageUrl = user?.profileImage != null
        ? '${EndPoint.imageBaseUrl}${user!.profileImage}'
        : null;

    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: const Color(0xFFF0F0F0),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _defaultAvatar(),
                        )
                      : _defaultAvatar(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            user?.fullName ?? '---',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF333333),
            ),
          ),

          if (user?.role != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                user!.role == 'captain'
                    ? '🚗 كابتن'
                    : user.role == 'merchant'
                    ? '🏪 تاجر'
                    : '👑 مدير',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _defaultAvatar() {
    return Center(
      child: Image.asset(
        AppAssets.group,
        height: 50,
        width: 50,
        errorBuilder: (_, _, _) =>
            const Icon(Icons.person, size: 40, color: Color(0xFFBDBDBD)),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF555555),
        ),
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          _buildListItem(
            title: 'تعديل بيانات الحساب',
            icon: Icons.person_outline,
            onTap: () => Navigator.pushNamed(
              context,
              Routes.editProfile,
            ).then((_) => context.read<ProfileCubit>().loadProfile()),
          ),
          _buildListItem(
            title: 'كلمة المرور',
            icon: Icons.lock_outline,
            onTap: () => Navigator.pushNamed(context, Routes.changePassword),
          ),
          _buildListItem(title: 'اللغة', icon: Icons.language),
          _buildListItem(
            title: 'الوضع الليلي',
            icon: Icons.dark_mode_outlined,
            isSwitch: true,
            switchValue: false,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context, UserEntity? user) {
    final isCaptain = user?.role == 'captain';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          _buildListItem(
            title: 'تقييمات',
            icon: Icons.star_border,
            onTap: () => Navigator.pushNamed(context, Routes.ratings),
          ),
          _buildListItem(
            title: 'دعوة الاصدقاء',
            icon: Icons.shortcut,
            onTap: () => Navigator.pushNamed(context, Routes.referEarn),
          ),
          _buildListItem(
            title: 'أسعار التوصيل الخاصة بنا',
            icon: Icons.local_shipping_outlined,
            onTap: () => Navigator.pushNamed(context, Routes.deliveryPrices),
          ),
          if (!isCaptain) ...[
            _buildListItem(
              title: 'عناوين الاستلام',
              icon: Icons.location_on_outlined,
              onTap: () => Navigator.pushNamed(context, Routes.addresses),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHelpSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          _buildListItem(
            title: 'تواصل معنا',
            icon: Icons.chat_bubble_outline,
            onTap: () => Navigator.pushNamed(context, Routes.contactUs),
          ),
          _buildListItem(
            title: 'الشروط و الاحكام',
            icon: Icons.description_outlined,
            onTap: () => Navigator.pushNamed(context, Routes.termsConditions),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Builder(
        builder: (context) => _buildListItem(
          title: 'تسجيل الخروج',
          icon: Icons.logout,
          isLogout: true,
          onTap: () async {
            sl<AppsFlyerService>().logEvent('logout', null);
            await PrefsHelper.clearSessionKeepCredentials();
            await SecureCacheHelper().clearData();
            if (!context.mounted) return;
            Navigator.pushNamedAndRemoveUntil(
              context,
              Routes.login,
              (route) => false,
            );
          },
        ),
      ),
    );
  }

  Widget _buildListItem({
    required String title,
    required IconData icon,
    bool isSwitch = false,
    bool switchValue = false,
    bool isLogout = false,
    VoidCallback? onTap,
  }) {
    final Color itemColor = isLogout
        ? const Color(0xFFE53935)
        : const Color.fromARGB(255, 73, 73, 73);

    return Builder(
      builder: (context) {
        return InkWell(
          onTap:
              onTap ??
              (isSwitch
                  ? null
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: const [
                              Icon(Icons.auto_awesome, color: Colors.white),
                              SizedBox(width: 12),
                              Text(
                                'قريباً سيتم توفير هذا القسم ✨',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: const Color(0xFF204CB3),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 20,
                          ),
                          elevation: 0,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: itemColor, size: 22),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: itemColor,
                    ),
                  ),
                ),
                if (isSwitch)
                  SizedBox(
                    height: 24,
                    child: CupertinoSwitch(
                      value: switchValue,
                      onChanged: (val) {},
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: const Color(0xFFD6D6D6),
                    ),
                  )
                else if (!isLogout)
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Color.fromARGB(255, 112, 112, 112),
                    size: 14,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
