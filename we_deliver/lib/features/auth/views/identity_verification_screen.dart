// ignore_for_file: unused_field, use_build_context_synchronously, deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:we_deliver/core/theme/colors.dart';
import 'package:we_deliver/core/widgets/custom_button.dart';
import 'package:we_deliver/core/widgets/custom_text_field.dart';
import 'package:we_deliver/core/theme/app_assets.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:we_deliver/core/cache/cache_helper.dart';
import '../../../core/routes/routes.dart';
import '../logic/auth_cubit.dart';
import '../logic/auth_state.dart';
import '../../profile/domain/usecases/update_profile_usecase.dart';
import '../../../core/utils/prefs_helper.dart';
import '../../../core/di/injection_container.dart';

enum VerificationStep { upload, review, selectVehicle, success }

class IdentityVerificationScreen extends StatefulWidget {
  final VerificationStep? initialStep;
  const IdentityVerificationScreen({super.key, this.initialStep});

  @override
  State<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends State<IdentityVerificationScreen> {
  VerificationStep _currentStep = VerificationStep.upload;
  final _nationalIdController = TextEditingController();
  File? _frontImage;
  File? _backImage;
  final _picker = ImagePicker();
  bool _isDelivery = false;
  String? _selectedVehicle;
  bool _isSavingVehicle = false;
  bool _isSavingDocs = false;

  final List<Map<String, dynamic>> _vehicles = [
    {'id': 'scooter', 'title': 'سكوتر', 'icon': AppAssets.scooter},
    {'id': 'motorcycle', 'title': 'موتوسيكل', 'icon': AppAssets.motorcycle},
    {'id': 'car', 'title': 'سيارة', 'icon': AppAssets.car},
    {'id': 'public', 'title': 'مواصلات', 'icon': AppAssets.transport},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialStep != null) {
      _currentStep = widget.initialStep!;
    }
    _checkRole();
  }

  Future<void> _checkRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isDelivery = prefs.getBool('isDelivery') ?? false;
      });
    }
  }

  Future<void> _pickImage(bool isFront) async {
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
                'اختر مصدر الصورة',
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
                  _processImagePick(isFront, ImageSource.camera);
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
                  _processImagePick(isFront, ImageSource.gallery);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processImagePick(bool isFront, ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        setState(() {
          if (isFront) {
            _frontImage = File(pickedFile.path);
          } else {
            _backImage = File(pickedFile.path);
          }
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      String message = 'تعذر الوصول للملفات';
      if (e is PlatformException && e.code == 'no_available_camera') {
        message =
            'لا توجد كاميرا متاحة على هذا الجهاز. يمكنك اختيار صورة من المعرض.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message, textAlign: TextAlign.right),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is UploadDocsSuccess) {
            setState(() {
              _isSavingDocs = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message, textAlign: TextAlign.right),
                backgroundColor: AppColors.primary,
                behavior: SnackBarBehavior.floating,
              ),
            );
            if (_isDelivery) {
              setState(() => _currentStep = VerificationStep.selectVehicle);
            } else {
              setState(() => _currentStep = VerificationStep.success);
            }
          } else if (state is AuthError) {
            setState(() {
              _isSavingDocs = false;
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
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: _buildBody(state is AuthLoading),
          );
        },
      ),
    );
  }

  Widget _buildBody(bool isLoading) {
    switch (_currentStep) {
      case VerificationStep.upload:
        return _buildUploadStep();
      case VerificationStep.review:
        return _buildReviewStep(isLoading);
      case VerificationStep.selectVehicle:
        return _buildSelectVehicleStep();
      case VerificationStep.success:
        return _buildSuccessStep();
    }
  }

  Widget _buildUploadStep() {
    return SingleChildScrollView(
      key: const ValueKey('upload'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Image.asset(AppAssets.appLogo2, width: 100, height: 100),
          ),
          const SizedBox(height: 20),
          const Text(
            'إنشاء حساب التاجر',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'يرجي رفع صورة بطاقتك الشخصية لتحقق من هويتك و ضمان الامان و منع الاحتيال داخل التطبيق',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            'الرقم لقومي',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          CustomTextField(
            controller: _nationalIdController,
            rightWidget: Padding(
              padding: const EdgeInsets.all(8.0),
              child: FaIcon(FontAwesomeIcons.idBadge, color: AppColors.primary),
            ),
            hintText: 'الرقم القومي (14 رقم)',
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(14),
            ],
          ),
          const SizedBox(height: 24),
          _buildImagePickerBox(
            title: 'وجه البطاقة الشخصية',
            image: _frontImage,
            onTap: () => _pickImage(true),
          ),
          const SizedBox(height: 16),
          _buildImagePickerBox(
            title: 'ظهر البطاقة الشخصية',
            image: _backImage,
            onTap: () => _pickImage(false),
          ),
          const SizedBox(height: 40),
          CustomButton(
            text: 'التالي',
            onPressed: () {
              final id = _nationalIdController.text.trim();
              if (_frontImage == null || _backImage == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'يرجى رفع صورة البطاقة الشخصية (الوجه والظهر)',
                      textAlign: TextAlign.right,
                    ),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              if (id.length != 14) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'الرقم القومي يجب أن يكون 14 رقماً بالضبط',
                      textAlign: TextAlign.right,
                    ),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              setState(() => _currentStep = VerificationStep.review);
            },
            color:
                (_frontImage != null &&
                    _backImage != null &&
                    _nationalIdController.text.trim().length == 14)
                ? AppColors.primary
                : Colors.grey.shade400,
            textColor: Colors.white,
            borderRadius: 50,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep(bool isLoading) {
    return SingleChildScrollView(
      key: const ValueKey('review'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Image.asset(AppAssets.appLogo2, width: 100, height: 100),
          ),
          const SizedBox(height: 20),
          const Text(
            'إنشاء حساب التاجر',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'يرجي مراجعة الصور الملتقطة قبل التأكيد',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 30),
          _buildReviewCard(
            title: 'وجه البطاقة الشخصية',
            image: _frontImage!,
            onRefresh: () => _pickImage(true),
          ),
          const SizedBox(height: 16),
          _buildReviewCard(
            title: 'ظهر البطاقة الشخصية',
            image: _backImage!,
            onRefresh: () => _pickImage(false),
          ),
          const SizedBox(height: 40),
          CustomButton(
            text: 'تأكيد',
            isLoading: isLoading || _isSavingDocs,
            onPressed: () {
              if (_isSavingDocs) return;
              FocusScope.of(context).unfocus();
              setState(() => _isSavingDocs = true);
              context.read<AuthCubit>().uploadDriverDocuments(
                nationalId: _nationalIdController.text.trim(),
                nationalIdFront: _frontImage!,
                nationalIdBack: _backImage!,
              );
            },
            textColor: Colors.white,
            borderRadius: 50,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessStep() {
    return Container(
      key: const ValueKey('success'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeInDown(
            child: Image.asset(AppAssets.check, width: 150, height: 150),
          ),
          const SizedBox(height: 40),
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            child: const Text(
              'تم إرسال الأوراق بنجاح',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeInUp(
            delay: const Duration(milliseconds: 400),
            child: const Text(
              'تم إرسال الأوراق وسوف نوافيك بالرد قريباً',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 60),
          FadeInUp(
            delay: const Duration(milliseconds: 600),
            child: CustomButton(
              text: 'العودة للرئيسية',
              onPressed: () async {
                await PrefsHelper.clearSessionKeepCredentials();
                await SecureCacheHelper().clearData();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    Routes.login,
                    (route) => false,
                  );
                }
              },
              textColor: Colors.white,
              borderRadius: 50,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectVehicleStep() {
    return SingleChildScrollView(
      key: const ValueKey('selectVehicle'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Image.asset(AppAssets.appLogo2, width: 100, height: 100),
          ),
          const SizedBox(height: 20),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'اختر وسيلة النقل',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'يرجى تحديد وسيلة النقل الخاصة بك لتسهيل عملية استلام وتوصيل الطلبات وتحديد مساراتك بدقة',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(height: 30),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
            ),
            itemCount: _vehicles.length,
            itemBuilder: (context, index) {
              final vehicle = _vehicles[index];
              final isSelected = _selectedVehicle == vehicle['id'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedVehicle = vehicle['id'] as String;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.05)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.grey.shade200,
                      width: isSelected ? 2.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.1)
                            : Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedScale(
                              scale: isSelected ? 1.1 : 1.0,
                              duration: const Duration(milliseconds: 250),
                              child: SvgPicture.asset(
                                vehicle['icon'] as String,
                                width: 70,
                                height: 70,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              vehicle['title'] as String,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: FadeIn(
                            child: const CircleAvatar(
                              radius: 10,
                              backgroundColor: AppColors.primary,
                              child: Icon(
                                Icons.check,
                                size: 12,
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
          const SizedBox(height: 40),
          CustomButton(
            text: 'حفظ ومتابعة',
            isLoading: _isSavingVehicle,
            onPressed: () async {
              if (_selectedVehicle == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'يرجى اختيار وسيلة النقل أولاً',
                      textAlign: TextAlign.right,
                    ),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              setState(() => _isSavingVehicle = true);
              final result = await sl<UpdateProfileUseCase>().call(
                vehicleType: _selectedVehicle,
              );
              if (mounted) {
                setState(() => _isSavingVehicle = false);
                result.fold(
                  (failure) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          failure.message,
                          textAlign: TextAlign.right,
                        ),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  (user) {
                    setState(() => _currentStep = VerificationStep.success);
                  },
                );
              }
            },
            textColor: Colors.white,
            borderRadius: 50,
          ),
        ],
      ),
    );
  }

  Widget _buildImagePickerBox({
    required String title,
    File? image,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 210,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: image != null ? AppColors.primary : Colors.grey.shade200,
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            if (image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(image, width: double.infinity, height: 210),
              )
            else
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FaIcon(
                      FontAwesomeIcons.idCard,
                      color: AppColors.primary,
                      size: 30,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'اضغط لالتقاط الصورة',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            if (image != null)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard({
    required String title,
    required File image,
    required VoidCallback onRefresh,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(image, width: 90, height: 70, fit: BoxFit.cover),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,

                  fontSize: 14,
                ),
              ),
              const Text(
                'تم التقاط الصورة بنجاح',
                style: TextStyle(color: AppColors.primary, fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
