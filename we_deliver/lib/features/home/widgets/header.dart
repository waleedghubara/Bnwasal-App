// ignore_for_file: strict_top_level_inference, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/routes/routes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/api/end_point.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/theme/app_assets.dart';
import '../../profile/presentation/bloc/profile_cubit.dart';
import '../../profile/presentation/bloc/profile_state.dart';
import '../../profile/presentation/bloc/address_cubit.dart';
import '../../shipment/presentation/widgets/shipment_pickers.dart';

class HomeHeader extends StatefulWidget {
  const HomeHeader({super.key});

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader> {
  String? _selectedAddressText;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        String name = '';
        String? profileImage;
        String? defaultCity;

        if (state is ProfileLoaded) {
          name = state.user.firstName;
          profileImage = state.user.profileImage;
          defaultCity = state.user.city;
        } else if (state is ProfileUpdateSuccess) {
          name = state.user.firstName;
          profileImage = state.user.profileImage;
          defaultCity = state.user.city;
        } else if (state is ProfileUpdating) {
          name = state.user.firstName;
          profileImage = state.user.profileImage;
          defaultCity = state.user.city;
        }

        final imageUrl = profileImage != null && profileImage.isNotEmpty
            ? (profileImage.startsWith('http')
                  ? profileImage
                  : profileImage.startsWith('/')
                  ? '${EndPoint.imageBaseUrl}$profileImage'
                  : '${EndPoint.imageBaseUrl}/$profileImage')
            : null;

        // Display selected address text or default profile city or prompt
        final displayText =
            _selectedAddressText ??
            (defaultCity != null && defaultCity.isNotEmpty
                ? defaultCity
                : 'حدد عنوانك المفضل..');

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFFF0F0F0),
                      border: Border.all(color: Colors.grey.shade200, width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: imageUrl != null
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _defaultAvatar(),
                            )
                          : _defaultAvatar(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name.isNotEmpty ? 'مرحبا $name' : 'مرحبا بك',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text('👋', style: TextStyle(fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        GestureDetector(
                          onTap: _showAddressPickerSheet,
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            children: [
                              const FaIcon(
                                FontAwesomeIcons.locationDot,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  displayText,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black54,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const FaIcon(
                                FontAwesomeIcons.chevronDown,
                                size: 10,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Row(
              children: [
                _buildIconButton(
                  FontAwesomeIcons.commentDots,
                  onTap: () {
                    Navigator.pushNamed(context, Routes.chatSupport);
                  },
                ),
                const SizedBox(width: 8),
                _buildIconButton(
                  FontAwesomeIcons.bell,
                  hasBadge: true,
                  onTap: () {
                    Navigator.pushNamed(context, Routes.notifications);
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _defaultAvatar() {
    return Center(
      child: Image.asset(
        AppAssets.group,
        height: 32,
        width: 32,
        errorBuilder: (_, _, _) =>
            const Icon(Icons.person, size: 28, color: Color(0xFFBDBDBD)),
      ),
    );
  }

  void _showAddressPickerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider(
        create: (context) => sl<AddressCubit>()..loadAddresses(),
        child: SavedAddressesSheet(
          onSelect: (addr) {
            if (addr.id == 'custom_map') {
              Navigator.pushNamed(context, Routes.addresses);
              return;
            }
            setState(() {
              _selectedAddressText = addr.address;
            });
          },
        ),
      ),
    );
  }

  Widget _buildIconButton(icon, {bool hasBadge = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: FaIcon(icon, size: 18, color: AppColors.primary),
          ),
          if (hasBadge)
            Positioned(
              top: 6,
              right: 8,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
