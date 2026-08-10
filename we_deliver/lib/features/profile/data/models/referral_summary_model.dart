class ReferralFriendModel {
  final String id;
  final String name;
  final String status; // 'pending', 'rewarded'
  final DateTime? date;
  final double amount;

  ReferralFriendModel({
    required this.id,
    required this.name,
    required this.status,
    this.date,
    required this.amount,
  });

  factory ReferralFriendModel.fromJson(Map<String, dynamic> json) {
    return ReferralFriendModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      status: json['status'] ?? 'pending',
      date: json['date'] != null ? DateTime.tryParse(json['date'])?.toLocal() : null,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ReferralStatsModel {
  final double totalRewards;
  final int invitedCount;
  final int successCount;
  final int pendingCount;

  ReferralStatsModel({
    required this.totalRewards,
    required this.invitedCount,
    required this.successCount,
    required this.pendingCount,
  });

  factory ReferralStatsModel.fromJson(Map<String, dynamic> json) {
    return ReferralStatsModel(
      totalRewards: (json['totalRewards'] as num?)?.toDouble() ?? 0.0,
      invitedCount: json['invitedCount'] ?? 0,
      successCount: json['successCount'] ?? 0,
      pendingCount: json['pendingCount'] ?? 0,
    );
  }
}

class ReferralSummaryModel {
  final String referralCode;
  final double walletBalance;
  final int points;
  final ReferralStatsModel statistics;
  final List<ReferralFriendModel> referrals;

  ReferralSummaryModel({
    required this.referralCode,
    required this.walletBalance,
    required this.points,
    required this.statistics,
    required this.referrals,
  });

  factory ReferralSummaryModel.fromJson(Map<String, dynamic> json) {
    return ReferralSummaryModel(
      referralCode: json['referralCode'] ?? '',
      walletBalance: (json['walletBalance'] as num?)?.toDouble() ?? 0.0,
      points: json['points'] ?? 0,
      statistics: ReferralStatsModel.fromJson(json['statistics'] ?? {}),
      referrals: (json['referrals'] as List?)
              ?.map((item) => ReferralFriendModel.fromJson(item))
              .toList() ??
          [],
    );
  }
}
