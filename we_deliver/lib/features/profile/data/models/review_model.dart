class ReviewModel {
  final String id;
  final String shipmentId;
  final String shipmentNumber;
  final String reviewerId;
  final String reviewerName;
  final String reviewerAvatar;
  final int rating;
  final String comment;
  final List<String> tags;
  final String createdAt;

  ReviewModel({
    required this.id,
    required this.shipmentId,
    required this.shipmentNumber,
    required this.reviewerId,
    required this.reviewerName,
    required this.reviewerAvatar,
    required this.rating,
    required this.comment,
    required this.tags,
    required this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] as String? ?? '',
      shipmentId: json['shipmentId'] as String? ?? '',
      shipmentNumber: json['shipmentNumber'] as String? ?? '',
      reviewerId: json['reviewerId'] as String? ?? '',
      reviewerName: json['reviewerName'] as String? ?? '',
      reviewerAvatar: json['reviewerAvatar'] as String? ?? '',
      rating: json['rating'] is int ? json['rating'] as int : (json['rating'] as num?)?.toInt() ?? 0,
      comment: json['comment'] as String? ?? '',
      tags: (json['tags'] as List?)?.map((item) => item.toString()).toList() ?? [],
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class ReceivedReviewsData {
  final int totalCount;
  final double avgRating;
  final Map<int, int> starCounts;
  final List<ReviewModel> reviews;

  ReceivedReviewsData({
    required this.totalCount,
    required this.avgRating,
    required this.starCounts,
    required this.reviews,
  });

  factory ReceivedReviewsData.fromJson(Map<String, dynamic> json) {
    final rawStars = json['starCounts'] as Map<String, dynamic>? ?? {};
    final starCounts = <int, int>{};
    rawStars.forEach((key, value) {
      final k = int.tryParse(key) ?? 0;
      final v = value is int ? value : (value as num?)?.toInt() ?? 0;
      if (k > 0) {
        starCounts[k] = v;
      }
    });

    return ReceivedReviewsData(
      totalCount: json['totalCount'] is int ? json['totalCount'] as int : (json['totalCount'] as num?)?.toInt() ?? 0,
      avgRating: json['avgRating'] is double ? json['avgRating'] as double : (json['avgRating'] as num?)?.toDouble() ?? 0.0,
      starCounts: starCounts,
      reviews: (json['reviews'] as List?)
              ?.map((item) => ReviewModel.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class UserRatingSummary {
  final String userId;
  final int totalCount;
  final double avgRating;
  final Map<int, int> starCounts;

  UserRatingSummary({
    required this.userId,
    required this.totalCount,
    required this.avgRating,
    required this.starCounts,
  });

  factory UserRatingSummary.fromJson(Map<String, dynamic> json) {
    final rawStars = json['starCounts'] as Map<String, dynamic>? ?? {};
    final starCounts = <int, int>{};
    rawStars.forEach((key, value) {
      final k = int.tryParse(key) ?? 0;
      final v = value is int ? value : (value as num?)?.toInt() ?? 0;
      if (k > 0) starCounts[k] = v;
    });
    return UserRatingSummary(
      userId: json['userId'] as String? ?? '',
      totalCount: json['totalCount'] is int
          ? json['totalCount'] as int
          : (json['totalCount'] as num?)?.toInt() ?? 0,
      avgRating: json['avgRating'] is double
          ? json['avgRating'] as double
          : (json['avgRating'] as num?)?.toDouble() ?? 0.0,
      starCounts: starCounts,
    );
  }

  /// Returns "0.0" if no reviews yet, otherwise formatted to one decimal place.
  String get formattedRating =>
      totalCount == 0 ? '—' : avgRating.toStringAsFixed(1);
}

class ReviewStatusResult {
  final bool hasReviewed;
  final int? existingRating;

  const ReviewStatusResult({
    required this.hasReviewed,
    this.existingRating,
  });
}

