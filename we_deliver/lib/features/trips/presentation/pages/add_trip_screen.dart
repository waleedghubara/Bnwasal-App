// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../features/shipment/data/datasources/egypt_locations.dart';

import '../../domain/entities/trip.dart';
import '../manager/trip_cubit.dart';
import '../manager/trip_state.dart';

class AddTripScreen extends StatefulWidget {
  const AddTripScreen({super.key});

  @override
  State<AddTripScreen> createState() => _AddTripScreenState();
}

class _AddTripScreenState extends State<AddTripScreen> {
  String? fromGov;
  String? fromCityVal;
  String? toGov;
  String? toCityVal;

  DateTime selectedDate = DateTime.now();
  late TimeOfDay departureTime;
  late TimeOfDay arrivalTime;

  Timer? _countdownTimer;
  Duration _timeUntilDeparture = Duration.zero;

  final TextEditingController _passingCitiesController =
      TextEditingController();

  String _formatTimeToArabic(TimeOfDay time) {
    final hour = time.hour;
    final minute = time.minute;
    final isPm = hour >= 12;
    int hour12 = hour % 12;
    if (hour12 == 0) hour12 = 12;

    final minuteStr = minute.toString().padLeft(2, '0');
    final hourStr = hour12.toString();
    final periodStr = isPm ? 'م' : 'ص';
    return '$hourStr:$minuteStr $periodStr';
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    int depHour = now.hour + 1;
    if (depHour >= 24) depHour = depHour % 24;
    departureTime = TimeOfDay(hour: depHour, minute: 0);

    int arrHour = depHour + 4;
    if (arrHour >= 24) arrHour = arrHour % 24;
    arrivalTime = TimeOfDay(hour: arrHour, minute: 0);

    _startCountdownTimer();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _updateCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateCountdown();
    });
  }

  void _updateCountdown() {
    final dep = _departureDateTimeWithDate;
    final diff = dep.difference(DateTime.now());
    setState(() {
      _timeUntilDeparture = diff.isNegative ? Duration.zero : diff;
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _passingCitiesController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(bool isDeparture) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isDeparture ? departureTime : arrivalTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: const Color(0xFF204CB3),
            colorScheme: const ColorScheme.light(primary: Color(0xFF204CB3)),
            buttonTheme: const ButtonThemeData(
              textTheme: ButtonTextTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isDeparture) {
          departureTime = picked;
        } else {
          arrivalTime = picked;
        }
      });
      // Restart countdown whenever a time changes
      _startCountdownTimer();
    }
  }

  /// Builds a full DateTime for departure on [selectedDate].
  DateTime get _departureDateTimeWithDate => DateTime(
    selectedDate.year,
    selectedDate.month,
    selectedDate.day,
    departureTime.hour,
    departureTime.minute,
  );

  /// Builds a full DateTime for arrival, automatically advancing to the next
  /// day if arrival time-of-day is earlier than or equal to departure time-of-day
  /// (i.e., the trip crosses midnight).
  DateTime get _arrivalDateTimeWithDate {
    final depMinutes = departureTime.hour * 60 + departureTime.minute;
    final arrMinutes = arrivalTime.hour * 60 + arrivalTime.minute;
    // Cross midnight only when arrival is STRICTLY before departure (same time = invalid, stays same day)
    final dayOffset = arrMinutes < depMinutes ? 1 : 0;
    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day + dayOffset,
      arrivalTime.hour,
      arrivalTime.minute,
    );
  }

  /// Returns true if the trip crosses midnight (arrival is on the next day).
  bool get _isMidnightCrossing {
    final depMin = departureTime.hour * 60 + departureTime.minute;
    final arrMin = arrivalTime.hour * 60 + arrivalTime.minute;
    return arrMin < depMin;
  }

  void _adjustTimesIfNeeded() {
    final now = DateTime.now();
    final depDT = _departureDateTimeWithDate;
    // Only auto-advance if departure is more than 2 minutes in the past
    // (to avoid bumping a departure set to "right now")
    if (depDT.isBefore(now.subtract(const Duration(minutes: 2)))) {
      final nextHour = now.hour + 1;
      if (nextHour >= 24) {
        selectedDate = DateTime(now.year, now.month, now.day + 1);
        departureTime = const TimeOfDay(hour: 0, minute: 0);
      } else {
        departureTime = TimeOfDay(hour: nextHour, minute: 0);
      }
      final arrHour = (departureTime.hour + 4) % 24;
      arrivalTime = TimeOfDay(hour: arrHour, minute: 0);
    }
  }

  bool _validateTimes() {
    final now = DateTime.now();

    // 1. Departure must be in the future (with a 2-minute grace period)
    //    This prevents rejecting trips set to depart "right now" or very soon.
    final isToday =
        selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
    if (isToday &&
        _departureDateTimeWithDate.isBefore(
          now.subtract(const Duration(minutes: 2)),
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب أن يكون وقت المغادرة في المستقبل'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    // 2. Arrival must be strictly after departure (midnight-crossing is allowed)
    //    _arrivalDateTimeWithDate already handles next-day arithmetic.
    if (!_arrivalDateTimeWithDate.isAfter(_departureDateTimeWithDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب أن يكون وقت الوصول بعد وقت المغادرة'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'اضافة مسار رحلة',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: BlocConsumer<TripCubit, TripState>(
          listener: (context, state) {
            if (state is TripActionSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.pop(context);
            } else if (state is TripError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          builder: (context, state) {
            final isBtnLoading = state is TripActionLoading;
            return SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('تاريخ الرحلة'),
                  _buildHorizontalDatePicker(),
                  SizedBox(height: 24.h),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle('وقت البداية:'),
                            GestureDetector(
                              onTap: () => _selectTime(true),
                              child: Container(
                                height: 50.h,
                                padding: EdgeInsets.symmetric(horizontal: 12.w),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8.r),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatTimeToArabic(departureTime),
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        color: Colors.black87,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.access_time,
                                      color: Color(0xFF204CB3),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle('وقت النهايه:'),
                            GestureDetector(
                              onTap: () => _selectTime(false),
                              child: Container(
                                height: 50.h,
                                padding: EdgeInsets.symmetric(horizontal: 12.w),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8.r),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Row(
                                        children: [
                                          Text(
                                            _formatTimeToArabic(arrivalTime),
                                            style: TextStyle(
                                              fontSize: 13.sp,
                                              color: Colors.black87,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (_isMidnightCrossing) ...[
                                            SizedBox(width: 4.w),
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 5.w,
                                                vertical: 1.h,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFF204CB3,
                                                ).withOpacity(0.12),
                                                borderRadius:
                                                    BorderRadius.circular(4.r),
                                              ),
                                              child: Text(
                                                '+1 يوم',
                                                style: TextStyle(
                                                  fontSize: 9.sp,
                                                  color: const Color(
                                                    0xFF204CB3,
                                                  ),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.access_time,
                                      color: Color(0xFF204CB3),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  _buildTimeSummaryCard(),
                  SizedBox(height: 16.h),

                  _buildSectionTitle('من (نقطة الانطلاق)'),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          'المحافظة',
                          fromGov,
                          EgyptLocations.governorates,
                          (val) => setState(() {
                            fromGov = val;
                            fromCityVal = null;
                          }),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildDropdown(
                          'المدينة',
                          fromCityVal,
                          fromGov != null
                              ? EgyptLocations.citiesFor(fromGov!)
                              : [],
                          (val) => setState(() => fromCityVal = val),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  _buildSectionTitle('الي (نقطة الوصول)'),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          'المحافظة',
                          toGov,
                          EgyptLocations.governorates,
                          (val) => setState(() {
                            toGov = val;
                            toCityVal = null;
                          }),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildDropdown(
                          'المدينة',
                          toCityVal,
                          toGov != null ? EgyptLocations.citiesFor(toGov!) : [],
                          (val) => setState(() => toCityVal = val),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24.h),

                  _buildSectionTitle('خط السير / نقاط المرور (اجبارى)'),
                  TextField(
                    controller: _passingCitiesController,
                    style: TextStyle(fontSize: 13.sp, color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'مثال: ابو قير، المعورة (مفصولة بفواصل)',
                      hintStyle: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey.shade400,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                  ),

                  SizedBox(height: 40.h),
                  CustomButton(
                    text: 'تأكيد',
                    isLoading: isBtnLoading,
                    onPressed: () {
                      if (fromGov == null ||
                          fromCityVal == null ||
                          toGov == null ||
                          toCityVal == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'يرجى تحديد المحافظة والمدينة لـ "من" و "إلى"',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      if (_passingCitiesController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'يرجى إدخال خط السير / نقاط المرور',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      if (!_validateTimes()) {
                        return;
                      }

                      final trip = Trip(
                        id: '',
                        from: '$fromGov - $fromCityVal',
                        to: '$toGov - $toCityVal',
                        fromCity: fromCityVal,
                        toCity: toCityVal,
                        passingCities: _passingCitiesController.text.trim(),
                        date: selectedDate,
                        time: _formatTimeToArabic(departureTime),
                        departureTime: _formatTimeToArabic(departureTime),
                        arrivalTime: _formatTimeToArabic(arrivalTime),
                        status: TripStatus.pending,
                      );
                      context.read<TripCubit>().addTrip(trip);
                    },
                    textColor: Colors.white,
                    width: double.infinity,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTimeSummaryCard() {
    // ── Trip duration ──────────────────────────────────────────────────────
    final dep = _departureDateTimeWithDate;
    final arr = _arrivalDateTimeWithDate;
    final tripDuration = arr.difference(dep);
    final dHours = tripDuration.inHours;
    final dMinutes = tripDuration.inMinutes.remainder(60);

    String durationLabel;
    if (dHours > 0 && dMinutes > 0) {
      durationLabel = '$dHours س $dMinutes د';
    } else if (dHours > 0) {
      durationLabel = '$dHours ساعة';
    } else {
      durationLabel = '$dMinutes دقيقة';
    }

    // ── Countdown to departure ─────────────────────────────────────────────
    final cHours = _timeUntilDeparture.inHours;
    final cMinutes = _timeUntilDeparture.inMinutes.remainder(60);
    final cSeconds = _timeUntilDeparture.inSeconds.remainder(60);

    final bool departed = _timeUntilDeparture == Duration.zero;
    final countdownLabel = departed
        ? 'جاري الآن'
        : '${cHours.toString().padLeft(2, '0')}:'
              '${cMinutes.toString().padLeft(2, '0')}:'
              '${cSeconds.toString().padLeft(2, '0')}';

    const primary = Color(0xFF204CB3);

    return Row(
      children: [
        // ── Duration card ─────────────────────────────────────────────────
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: primary.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.directions_bus_rounded,
                      size: 13.sp,
                      color: primary,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      'مدة الرحلة',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  durationLabel,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 10.w),
        // ── Countdown card ────────────────────────────────────────────────
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
            decoration: BoxDecoration(
              color: departed ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: departed
                    ? Colors.green.shade200
                    : Colors.orange.shade200,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      departed
                          ? Icons.check_circle_outline
                          : Icons.timer_outlined,
                      size: 13.sp,
                      color: departed
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      departed ? 'انطلقت' : 'يبدأ بعد',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: departed
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  countdownLabel,
                  style: TextStyle(
                    fontSize: departed ? 14.sp : 15.sp,
                    fontWeight: FontWeight.bold,
                    color: departed
                        ? Colors.green.shade700
                        : Colors.orange.shade800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildHorizontalDatePicker() {
    return SizedBox(
      height: 85.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 14, // Next 2 weeks
        itemBuilder: (context, index) {
          DateTime date = DateTime.now().add(Duration(days: index));
          bool isSelected =
              date.day == selectedDate.day &&
              date.month == selectedDate.month &&
              date.year == selectedDate.year;

          String dayName = index == 0
              ? 'اليوم'
              : DateFormat('EEEE', 'ar').format(date);
          String dayNum = date.day.toString();
          String monthName = DateFormat('MMM', 'ar').format(date);

          return GestureDetector(
            onTap: () => setState(() {
              selectedDate = date;
              _adjustTimesIfNeeded();
            }),
            child: Container(
              width: 65.w,
              margin: EdgeInsets.only(left: 12.w),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF204CB3)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF204CB3)
                      : Colors.grey.shade200,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayName,
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: isSelected ? Colors.white70 : Colors.grey,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    dayNum,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  ),
                  Text(
                    monthName,
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: isSelected ? Colors.white70 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDropdown(
    String hint,
    String? value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            hint,
            style: AppTypography.h6.copyWith(
              fontSize: 12.sp,
              color: Colors.black,
            ),
          ),
          isExpanded: true,
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                item,
                style: AppTypography.h6.copyWith(
                  fontSize: 12.sp,
                  color: Colors.black,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
