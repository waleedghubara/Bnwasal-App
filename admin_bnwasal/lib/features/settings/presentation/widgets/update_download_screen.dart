import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dio/dio.dart';
import 'package:admin_bnwasal/core/di/injection_container.dart' as di;
import 'package:admin_bnwasal/core/theme/colors.dart';
import '../../data/settings_api.dart';

class UpdateDownloadScreen extends StatefulWidget {
  final String version;
  const UpdateDownloadScreen({super.key, this.version = ''});

  @override
  State<UpdateDownloadScreen> createState() => _UpdateDownloadScreenState();
}

class _UpdateDownloadScreenState extends State<UpdateDownloadScreen>
    with SingleTickerProviderStateMixin {
  double _progress = 0;
  String _status = 'اضغط بدء التحميل للبدء';
  bool _idle = true;
  bool _downloading = false;
  bool _error = false;
  bool _cancelled = false;
  String _filePath = '';

  int _lastReceived = 0;
  DateTime _lastTime = DateTime.now();
  double _speed = 0;
  int _totalBytes = 0;
  CancelToken? _cancelToken;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _startDownload() async {
    setState(() {
      _idle = false;
      _downloading = true;
      _error = false;
      _cancelled = false;
      _progress = 0;
      _speed = 0;
      _totalBytes = 0;
      _lastReceived = 0;
      _lastTime = DateTime.now();
      _status = 'جاري تحميل التحديث...';
    });
    _cancelToken = CancelToken();
    try {
      final api = di.sl<SettingsApi>();
      _filePath = await api.downloadUpdate(
        onProgress: (received, total) {
          if (!mounted || _cancelToken?.isCancelled == true) return;
          final now = DateTime.now();
          final elapsed = now.difference(_lastTime).inMilliseconds / 1000;
          final chunk = received - _lastReceived;
          setState(() {
            _totalBytes = total;
            if (elapsed > 0) _speed = chunk / elapsed;
            _lastReceived = received;
            _lastTime = now;
            _progress = total > 0 ? received / total : 0;
          });
        },
        cancelToken: _cancelToken,
      );
      if (!mounted || _cancelToken?.isCancelled == true) return;
      setState(() {
        _status = 'تم التحميل بنجاح';
        _downloading = false;
      });
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      _showRestartPrompt();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'فشل تحميل التحديث';
        _error = true;
        _downloading = false;
      });
    }
  }

  void _stopDownload() {
    _cancelToken?.cancel();
    setState(() {
      _idle = true;
      _downloading = false;
      _cancelled = true;
      _status = 'تم إلغاء التحميل';
    });
  }

  void _showRestartPrompt() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.all(24.w),
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: EdgeInsets.all(28.w),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 60,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72.w,
                    height: 72.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.success.withValues(alpha: 0.15),
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 40,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    'تم تحميل التحديث',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'الإصدار ${widget.version.isNotEmpty ? widget.version : 'الجديد'} جاهز للتثبيت',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  SizedBox(height: 24.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                        _installAndRestart();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                      ),
                      child: Text(
                        'غلق التطبيق الآن',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15.sp,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 10.h),
                      ),
                      child: Text(
                        'لاحقاً',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _installAndRestart() {
    if (Platform.isWindows && _filePath.isNotEmpty) {
      Process.start(_filePath, [], mode: ProcessStartMode.detachedWithStdio);
      Future.delayed(const Duration(milliseconds: 500), () {
        exit(0);
      });
    }
  }

  String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec < 1024) return '${bytesPerSec.toStringAsFixed(0)} B/s';
    if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  String _formatEta(double progress, double speed) {
    if (speed <= 0 || progress <= 0) return '';
    final remaining = (1 - progress) * _totalBytes;
    final seconds = (remaining / speed).round();
    if (seconds < 60) return '$secondsث';
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '$minد $secث';
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a1a),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(isWide ? 40.w : 24.w),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            padding: EdgeInsets.all(isWide ? 36.w : 24.w),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 60,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (context, child) {
                    final scale = 1.0 + (_pulseAnim.value * 0.04);
                    return Transform.scale(
                      scale: _downloading ? scale : 1.0,
                      child: child,
                    );
                  },
                  child: Container(
                    width: isWide ? 88.w : 80.w,
                    height: isWide ? 88.w : 80.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _idle || _cancelled
                          ? LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.2),
                                Colors.white.withValues(alpha: 0.05),
                              ],
                            )
                          : _downloading
                          ? AppColors.primaryGradient
                          : _error
                          ? LinearGradient(
                              colors: [
                                AppColors.error,
                                AppColors.error.withValues(alpha: 0.7),
                              ],
                            )
                          : const LinearGradient(
                              colors: [AppColors.success, Color(0xFF0d9a00)],
                            ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (_idle || _cancelled
                                      ? Colors.white
                                      : _downloading
                                      ? AppColors.primary
                                      : _error
                                      ? AppColors.error
                                      : AppColors.success)
                                  .withValues(alpha: 0.3),
                          blurRadius: 30,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: _idle || _cancelled
                        ? const Icon(
                            Icons.download_rounded,
                            color: Colors.white,
                            size: 36,
                          )
                        : _downloading
                        ? const Icon(
                            Icons.system_update_rounded,
                            color: Colors.white,
                            size: 36,
                          )
                        : Icon(
                            _error
                                ? Icons.error_outline_rounded
                                : Icons.check_circle_outline_rounded,
                            color: Colors.white,
                            size: isWide ? 40.sp : 36.sp,
                          ),
                  ),
                ),
                SizedBox(height: 24.h),
                Text(
                  _idle
                      ? 'تحديث البرنامج'
                      : _cancelled
                      ? 'تم إلغاء التحميل'
                      : _downloading
                      ? 'جاري تحميل التحديث'
                      : _error
                      ? 'فشل التحميل'
                      : 'اكتمل التحميل',
                  style: TextStyle(
                    fontSize: isWide ? 22.sp : 20.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8.h),
                if (widget.version.isNotEmpty)
                  Text(
                    'الإصدار ${widget.version}',
                    style: TextStyle(
                      fontSize: isWide ? 14.sp : 13.sp,
                      color: Colors.white.withValues(alpha: 0.4),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (widget.version.isNotEmpty) SizedBox(height: 20.h),

                if (_downloading) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 10.h,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: _progress),
                        duration: const Duration(milliseconds: 300),
                        builder: (context, value, _) => LinearProgressIndicator(
                          value: value,
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    '${(_progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: isWide ? 36.sp : 32.sp,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 10.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStat(
                          Icons.insert_drive_file_outlined,
                          _totalBytes > 0 ? _formatBytes(_totalBytes) : '--',
                          'الحجم',
                        ),
                        Container(
                          width: 1,
                          height: 24.h,
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                        _buildStat(
                          Icons.speed_rounded,
                          _speed > 0 ? _formatSpeed(_speed) : '--',
                          'السرعة',
                        ),
                        Container(
                          width: 1,
                          height: 24.h,
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                        _buildStat(
                          Icons.timer_outlined,
                          _speed > 0 && _progress > 0
                              ? _formatEta(_progress, _speed)
                              : '--',
                          'المتبقي',
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: 20.h),
                Text(
                  _status,
                  style: TextStyle(
                    fontSize: isWide ? 14.sp : 13.sp,
                    color: Colors.white.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 24.h),

                if (_idle || _cancelled)
                  _buildActionButton(
                    label: 'بدء التحميل',
                    icon: Icons.play_arrow_rounded,
                    color: AppColors.primary,
                    onTap: _startDownload,
                  ),

                if (_downloading) ...[
                  _buildActionButton(
                    label: 'إيقاف',
                    icon: Icons.stop_rounded,
                    color: AppColors.error,
                    onTap: _stopDownload,
                  ),
                  SizedBox(height: 10.h),
                  _buildTextButton('العودة', () => Navigator.pop(context)),
                ],

                if (_error) ...[
                  _buildActionButton(
                    label: 'إعادة المحاولة',
                    icon: Icons.refresh_rounded,
                    color: AppColors.primary,
                    onTap: _startDownload,
                  ),
                  SizedBox(height: 10.h),
                  _buildTextButton('العودة', () => Navigator.pop(context)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          padding: EdgeInsets.symmetric(vertical: isWide ? 16.h : 14.h),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18.sp),
            SizedBox(width: 8.w),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: isWide ? 16.sp : 15.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 10.h),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.primary, size: 16.sp),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9.sp,
            color: Colors.white.withValues(alpha: 0.35),
          ),
        ),
      ],
    );
  }
}
