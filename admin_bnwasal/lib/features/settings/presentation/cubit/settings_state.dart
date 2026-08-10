import 'package:equatable/equatable.dart';

class SettingsState extends Equatable {
  final bool isLoading;
  final bool isSaving;
  final String? error;
  final String? successMessage;

  // Social links
  final String facebook;
  final String instagram;
  final String twitter;
  final String whatsapp;
  final String linkedin;
  final String youtube;

  // Update
  final String updateVersion;
  final bool updateRequired;
  final bool hasUpdateFile;
  final bool isUploading;

  // Maintenance
  final bool maintenanceEnabled;
  final String maintenanceMessage;

  // Fee collection mode setting
  final String feeCollectionMode;

  // Mobile App Stores
  final String playStoreUrl;
  final String appStoreUrl;

  // Support Contacts
  final String supportPhone;
  final String supportEmail;

  // Explanation Videos
  final String merchantVideoUrl;
  final String captainVideoUrl;

  // Mobile Updates
  final String mobileUpdateVersion;
  final bool mobileUpdateRequired;

  // Auto Assignment Settings
  final bool enableAutoAssignment;
  final int autoAssignmentTimeout;
  final int maxReassignmentAttempts;
  final int maxAttemptsPerCaptain;
  final bool allowAutoAssignmentAfterReject;
  final bool allowAutoAssignmentAfterTimeout;
  final String routeMatchingRule;
  final int captainAcceptanceTimeout;

  const SettingsState({
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.successMessage,
    this.facebook = '',
    this.instagram = '',
    this.twitter = '',
    this.whatsapp = '',
    this.linkedin = '',
    this.youtube = '',
    this.updateVersion = '',
    this.updateRequired = false,
    this.hasUpdateFile = false,
    this.isUploading = false,
    this.maintenanceEnabled = false,
    this.maintenanceMessage = '',
    this.feeCollectionMode = 'after_agreement',
    this.playStoreUrl = '',
    this.appStoreUrl = '',
    this.supportPhone = '',
    this.supportEmail = '',
    this.merchantVideoUrl = '',
    this.captainVideoUrl = '',
    this.mobileUpdateVersion = '',
    this.mobileUpdateRequired = false,
    this.enableAutoAssignment = true,
    this.autoAssignmentTimeout = 300,
    this.maxReassignmentAttempts = 5,
    this.maxAttemptsPerCaptain = 3,
    this.allowAutoAssignmentAfterReject = true,
    this.allowAutoAssignmentAfterTimeout = true,
    this.routeMatchingRule = 'flexible',
    this.captainAcceptanceTimeout = 60,
  });

  SettingsState copyWith({
    bool? isLoading,
    bool? isSaving,
    String? error,
    String? successMessage,
    String? facebook,
    String? instagram,
    String? twitter,
    String? whatsapp,
    String? linkedin,
    String? youtube,
    String? updateVersion,
    bool? updateRequired,
    bool? hasUpdateFile,
    bool? isUploading,
    bool? maintenanceEnabled,
    String? maintenanceMessage,
    String? feeCollectionMode,
    String? playStoreUrl,
    String? appStoreUrl,
    String? supportPhone,
    String? supportEmail,
    String? merchantVideoUrl,
    String? captainVideoUrl,
    String? mobileUpdateVersion,
    bool? mobileUpdateRequired,
    bool? enableAutoAssignment,
    int? autoAssignmentTimeout,
    int? maxReassignmentAttempts,
    int? maxAttemptsPerCaptain,
    bool? allowAutoAssignmentAfterReject,
    bool? allowAutoAssignmentAfterTimeout,
    String? routeMatchingRule,
    int? captainAcceptanceTimeout,
  }) {
    return SettingsState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: error,
      successMessage: successMessage,
      facebook: facebook ?? this.facebook,
      instagram: instagram ?? this.instagram,
      twitter: twitter ?? this.twitter,
      whatsapp: whatsapp ?? this.whatsapp,
      linkedin: linkedin ?? this.linkedin,
      youtube: youtube ?? this.youtube,
      updateVersion: updateVersion ?? this.updateVersion,
      updateRequired: updateRequired ?? this.updateRequired,
      hasUpdateFile: hasUpdateFile ?? this.hasUpdateFile,
      isUploading: isUploading ?? this.isUploading,
      maintenanceEnabled: maintenanceEnabled ?? this.maintenanceEnabled,
      maintenanceMessage: maintenanceMessage ?? this.maintenanceMessage,
      feeCollectionMode: feeCollectionMode ?? this.feeCollectionMode,
      playStoreUrl: playStoreUrl ?? this.playStoreUrl,
      appStoreUrl: appStoreUrl ?? this.appStoreUrl,
      supportPhone: supportPhone ?? this.supportPhone,
      supportEmail: supportEmail ?? this.supportEmail,
      merchantVideoUrl: merchantVideoUrl ?? this.merchantVideoUrl,
      captainVideoUrl: captainVideoUrl ?? this.captainVideoUrl,
      mobileUpdateVersion: mobileUpdateVersion ?? this.mobileUpdateVersion,
      mobileUpdateRequired: mobileUpdateRequired ?? this.mobileUpdateRequired,
      enableAutoAssignment: enableAutoAssignment ?? this.enableAutoAssignment,
      autoAssignmentTimeout: autoAssignmentTimeout ?? this.autoAssignmentTimeout,
      maxReassignmentAttempts: maxReassignmentAttempts ?? this.maxReassignmentAttempts,
      maxAttemptsPerCaptain: maxAttemptsPerCaptain ?? this.maxAttemptsPerCaptain,
      allowAutoAssignmentAfterReject: allowAutoAssignmentAfterReject ?? this.allowAutoAssignmentAfterReject,
      allowAutoAssignmentAfterTimeout: allowAutoAssignmentAfterTimeout ?? this.allowAutoAssignmentAfterTimeout,
      routeMatchingRule: routeMatchingRule ?? this.routeMatchingRule,
      captainAcceptanceTimeout: captainAcceptanceTimeout ?? this.captainAcceptanceTimeout,
    );
  }

  @override
  List<Object?> get props => [
    isLoading, isSaving, error, successMessage,
    facebook, instagram, twitter, whatsapp, linkedin, youtube,
    updateVersion, updateRequired, hasUpdateFile, isUploading,
    maintenanceEnabled, maintenanceMessage, feeCollectionMode,
    playStoreUrl, appStoreUrl, supportPhone, supportEmail,
    merchantVideoUrl, captainVideoUrl,
    mobileUpdateVersion, mobileUpdateRequired,
    enableAutoAssignment, autoAssignmentTimeout, maxReassignmentAttempts,
    maxAttemptsPerCaptain,
    allowAutoAssignmentAfterReject, allowAutoAssignmentAfterTimeout,
    routeMatchingRule, captainAcceptanceTimeout,
  ];
}
