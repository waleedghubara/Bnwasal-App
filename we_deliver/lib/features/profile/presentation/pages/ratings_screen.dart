import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:we_deliver/core/api/end_point.dart';
import '../../data/models/review_model.dart';
import '../bloc/review_cubit.dart';
import '../bloc/review_state.dart';

class RatingsScreen extends StatefulWidget {
  const RatingsScreen({super.key});

  @override
  State<RatingsScreen> createState() => _RatingsScreenState();
}

class _RatingsScreenState extends State<RatingsScreen> {
  int _selectedFilter = 0; // 0 means 'All'
  int _selectedTab = 0; // 0: received, 1: given
  bool _isDelivery = false;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isDelivery = prefs.getBool('isDelivery') ?? false;
      });
    }
  }

  String _formatDate(String dateStr) {
    try {
      final parsed = DateTime.parse(dateStr);
      return '${parsed.day.toString().padLeft(2, '0')}.${parsed.month.toString().padLeft(2, '0')}.${parsed.year}';
    } catch (_) {
      return dateStr;
    }
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
          'التقييمات',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.black, size: 20.sp),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocBuilder<ReviewCubit, ReviewState>(
        builder: (context, state) {
          if (state is ReviewLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is ReviewError) {
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.message,
                      style: TextStyle(fontSize: 14.sp, color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16.h),
                    ElevatedButton(
                      onPressed: () => context.read<ReviewCubit>().loadReviews(),
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            );
          } else if (state is ReviewLoaded) {
            final reviewsList = _selectedTab == 0
                ? state.receivedReviewsData.reviews
                : state.givenReviews;

            final filteredReviews = _selectedFilter == 0
                ? reviewsList
                : reviewsList
                      .where((r) => r.rating == _selectedFilter)
                      .toList();

            final receivedCount = state.receivedReviewsData.reviews.length;
            final givenCount = state.givenReviews.length;

            return RefreshIndicator(
              onRefresh: () => context.read<ReviewCubit>().loadReviews(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 16.h),
                      _buildTabs(receivedCount, givenCount),
                      SizedBox(height: 24.h),
                      if (_selectedTab == 0) ...[
                        _buildRatingSummaryCard(state.receivedReviewsData),
                        SizedBox(height: 24.h),
                      ],
                      _buildFilterChips(),
                      SizedBox(height: 24.h),
                      if (filteredReviews.isEmpty)
                        Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 40.h),
                            child: Text(
                              'لا توجد تقييمات',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredReviews.length,
                          separatorBuilder: (context, index) => Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            child: Divider(
                              color: Colors.grey.shade300,
                              thickness: 1,
                            ),
                          ),
                          itemBuilder: (context, index) {
                            return _buildReviewCard(filteredReviews[index]);
                          },
                        ),
                      SizedBox(height: 40.h),
                    ],
                  ),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildTabs(int receivedCount, int givenCount) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() {
              _selectedTab = 0;
              _selectedFilter = 0;
            }),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              decoration: BoxDecoration(
                color: _selectedTab == 0
                    ? const Color(0xFFF0F5FF)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: _selectedTab == 0
                      ? const Color(0xFFCBE0FF)
                      : const Color(0xFFEEEEEE),
                ),
              ),
              child: Center(
                child: Text(
                  _isDelivery
                      ? 'تقييمات العملاء لي ($receivedCount)'
                      : 'تقييمات المندوبين لي ($receivedCount)',
                  style: TextStyle(
                    color: _selectedTab == 0
                        ? const Color(0xFF4A90E2)
                        : const Color(0xFF9E9E9E),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() {
              _selectedTab = 1;
              _selectedFilter = 0;
            }),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              decoration: BoxDecoration(
                color: _selectedTab == 1
                    ? const Color(0xFFF0F5FF)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: _selectedTab == 1
                      ? const Color(0xFFCBE0FF)
                      : const Color(0xFFEEEEEE),
                ),
              ),
              child: Center(
                child: Text(
                  'تقييماتي للآخرين ($givenCount)',
                  style: TextStyle(
                    color: _selectedTab == 1
                        ? const Color(0xFF4A90E2)
                        : const Color(0xFF9E9E9E),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingSummaryCard(ReceivedReviewsData data) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: const Color(0xFF204CB3),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          // Right Side: Average Rating
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  data.avgRating.toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 40.sp,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
                SizedBox(height: 8.h),
                FittedBox(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return Icon(
                        Icons.star,
                        color: index < data.avgRating.round()
                            ? const Color(0xFFFFC107)
                            : Colors.grey.shade400,
                        size: 14.sp,
                      );
                    }),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  '${data.totalCount} تقييم',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            child: Container(
              width: 1,
              height: 100.h,
              color: Colors.white.withOpacity(0.1),
            ),
          ),

          Expanded(
            flex: 3,
            child: Column(
              children: [
                _buildRatingBarRow(
                  5,
                  data.starCounts[5] ?? 0,
                  data.totalCount,
                  Colors.green,
                ),
                SizedBox(height: 8.h),
                _buildRatingBarRow(
                  4,
                  data.starCounts[4] ?? 0,
                  data.totalCount,
                  Colors.green,
                ),
                SizedBox(height: 8.h),
                _buildRatingBarRow(
                  3,
                  data.starCounts[3] ?? 0,
                  data.totalCount,
                  Colors.amber,
                ),
                SizedBox(height: 8.h),
                _buildRatingBarRow(
                  2,
                  data.starCounts[2] ?? 0,
                  data.totalCount,
                  Colors.grey,
                ),
                SizedBox(height: 8.h),
                _buildRatingBarRow(
                  1,
                  data.starCounts[1] ?? 0,
                  data.totalCount,
                  Colors.grey,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBarRow(
    int starNum,
    int count,
    int totalCount,
    Color color,
  ) {
    final percentage = totalCount > 0 ? (count / totalCount) : 0.0;
    return Row(
      children: [
        Text(
          starNum.toString(),
          style: TextStyle(color: Colors.white, fontSize: 12.sp),
        ),
        SizedBox(width: 4.w),
        Icon(Icons.star, color: const Color(0xFFFFC107), size: 12.sp),
        SizedBox(width: 8.w),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              FractionallySizedBox(
                widthFactor: percentage,
                child: Container(
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 8.w),
        SizedBox(
          width: 18.w,
          child: Text(
            count.toString(),
            style: TextStyle(color: Colors.white, fontSize: 12.sp),
            textAlign: TextAlign.left,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip(0, 'الكل'),
          SizedBox(width: 8.w),
          _buildChip(5, '5', showStar: true),
          SizedBox(width: 8.w),
          _buildChip(4, '4', showStar: true),
          SizedBox(width: 8.w),
          _buildChip(3, '3', showStar: true),
          SizedBox(width: 8.w),
          _buildChip(2, '2', showStar: true),
          SizedBox(width: 8.w),
          _buildChip(1, '1', showStar: true),
        ],
      ),
    );
  }

  Widget _buildChip(int filterValue, String label, {bool showStar = false}) {
    final isSelected = _selectedFilter == filterValue;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = filterValue),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0F5FF) : Colors.white,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showStar) ...[
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFF204CB3)
                      : const Color(0xFF9E9E9E),
                  fontSize: 14.sp,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              SizedBox(width: 4.w),
              Icon(Icons.star, color: const Color(0xFF9E9E9E), size: 14.sp),
            ] else ...[
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFF204CB3)
                      : const Color(0xFF9E9E9E),
                  fontSize: 14.sp,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(ReviewModel review) {
    final avatarUrl = review.reviewerAvatar.isNotEmpty
        ? (review.reviewerAvatar.startsWith('http')
              ? review.reviewerAvatar
              : '${EndPoint.imageBaseUrl}${review.reviewerAvatar}')
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 20.r,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl.isEmpty
                  ? Text(
                      review.reviewerName.isNotEmpty
                          ? review.reviewerName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF204CB3),
                      ),
                    )
                  : null,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    review.reviewerName,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '#${review.shipmentNumber} • ${_formatDate(review.createdAt)}',
                    style: TextStyle(
                      color: const Color(0xFF9E9E9E),
                      fontSize: 12.sp,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: List.generate(5, (index) {
                      return Icon(
                        Icons.star,
                        color: index < review.rating
                            ? const Color(0xFFFFC107)
                            : Colors.grey.shade300,
                        size: 14.sp,
                      );
                    }),
                  ),
                ],
              ),
            ),

            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9E5),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    review.rating.toString(),
                    style: TextStyle(
                      color: const Color(0xFFFFC107),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Icon(Icons.star, color: const Color(0xFFFFC107), size: 14.sp),
                ],
              ),
            ),
          ],
        ),

        if (review.tags.isNotEmpty) ...[
          SizedBox(height: 12.h),
          // Tags
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            alignment: WrapAlignment.end,
            children: review.tags.map((tag) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F5FF),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    color: const Color(0xFF204CB3),
                    fontSize: 12.sp,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        if (review.comment.isNotEmpty) ...[
          SizedBox(height: 12.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: Text(
              review.comment,
              style: TextStyle(color: const Color(0xFF757575), fontSize: 13.sp),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ],
    );
  }
}
