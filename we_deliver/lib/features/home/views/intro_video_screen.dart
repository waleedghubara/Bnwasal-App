import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:we_deliver/core/theme/colors.dart';

class IntroVideoScreen extends StatefulWidget {
  final String videoUrl;
  final VoidCallback onDismiss;

  const IntroVideoScreen({
    super.key,
    required this.videoUrl,
    required this.onDismiss,
  });

  @override
  State<IntroVideoScreen> createState() => _IntroVideoScreenState();
}

class _IntroVideoScreenState extends State<IntroVideoScreen> {
  // YouTube Player components
  YoutubePlayerController? _youtubeController;
  bool _isYoutube = false;

  // Native Video Player components
  VideoPlayerController? _videoController;
  bool _isNativeInitialized = false;
  bool _isPlaying = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  void _initializePlayer() {
    final String url = widget.videoUrl;
    final String? ytId = YoutubePlayer.convertUrlToId(url);

    if (ytId != null && ytId.isNotEmpty) {
      _isYoutube = true;
      _youtubeController = YoutubePlayerController(
        initialVideoId: ytId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          enableCaption: true,
          loop: false,
          forceHD: false,
        ),
      );
    } else {
      _isYoutube = false;
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _isNativeInitialized = true;
            });
            _videoController!.play();
            setState(() {
              _isPlaying = true;
            });
          }
        }).catchError((e) {
          debugPrint('Error loading native video: $e');
        });

      _videoController?.addListener(() {
        if (mounted && _videoController != null) {
          final isPlaying = _videoController!.value.isPlaying;
          if (isPlaying != _isPlaying) {
            setState(() {
              _isPlaying = isPlaying;
            });
          }
        }
      });
    }
  }

  Future<void> _markAsWatchedAndDismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('watched_intro_video', true);
    widget.onDismiss();
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    // 1. Portrait & Landscape Mode - Youtube Player Layout (using YoutubePlayerBuilder)
    if (_isYoutube && _youtubeController != null) {
      return YoutubePlayerBuilder(
        player: YoutubePlayer(
          controller: _youtubeController!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: AppColors.primary,
          progressColors: const ProgressBarColors(
            playedColor: AppColors.primary,
            handleColor: AppColors.primary2,
          ),
          onEnded: (meta) {
            _markAsWatchedAndDismiss();
          },
        ),
        builder: (context, player) {
          return Material(
            color: isLandscape ? Colors.black : Colors.white, // White background in portrait
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isLandscape ? 0 : 20,
                  vertical: isLandscape ? 0 : 16,
                ),
                child: isLandscape
                    ? Center(
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: player,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Header section (No close button X)
                                  Text(
                                    'شرح طريقة عمل التطبيق',
                                    style: GoogleFonts.tajawal(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'يرجى مشاهدة هذا الشرح القصير لبدء العمل بنجاح ودون أخطاء.',
                                    style: GoogleFonts.tajawal(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Centered Video Player Container directly under text
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.08),
                                          blurRadius: 15,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: player,
                                  ),

                                  const SizedBox(height: 28),

                                  // App Features Section Header
                                  Text(
                                    'ماذا يقدم لك تطبيق بنوصل؟',
                                    style: GoogleFonts.tajawal(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Feature Item 1
                                  _buildFeatureItem(
                                    icon: Icons.flash_on_rounded,
                                    title: 'شحن وتوصيل فائق السرعة',
                                    description: 'نوفر لك تجربة توصيل سريعة وآمنة لجميع شحناتك وبكبسة زر واحدة.',
                                  ),
                                  const SizedBox(height: 12),

                                  // Feature Item 2
                                  _buildFeatureItem(
                                    icon: Icons.map_rounded,
                                    title: 'تتبع مباشر ولحظي',
                                    description: 'تتبع مكان المندوب وحركة الشحنة مباشرة على الخريطة في كل ثانية.',
                                  ),
                                  const SizedBox(height: 12),

                                  // Feature Item 3
                                  _buildFeatureItem(
                                    icon: Icons.account_balance_wallet_rounded,
                                    title: 'محفظة مالية رقمية متكاملة',
                                    description: 'إدارة أرباحك، التحصيل، وطلب سحب الأموال بكل سهولة وأمان تام.',
                                  ),
                                  const SizedBox(height: 12),

                                  // Feature Item 4
                                  _buildFeatureItem(
                                    icon: Icons.support_agent_rounded,
                                    title: 'دعم فني فوري 24/7',
                                    description: 'فريق دعم كامل وجاهز لحل أي مشكلة أو استفسار تواجهه فوراً.',
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),
                            ),
                          ),

                          // Bottom Button Action
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: ElevatedButton(
                              onPressed: _markAsWatchedAndDismiss,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                minimumSize: const Size(double.infinity, 56),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'فهمت، ابدأ استخدام التطبيق الآن',
                                style: GoogleFonts.tajawal(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      );
    }

    // 2. Portrait & Landscape Mode - Native Player Layout
    return Material(
      color: isLandscape ? Colors.black : Colors.white, // White background in portrait
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isLandscape ? 0 : 20,
            vertical: isLandscape ? 0 : 16,
          ),
          child: isLandscape
              ? Center(
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _buildNativePlayer(),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header section (No close button X)
                            Text(
                              'شرح طريقة عمل التطبيق',
                              style: GoogleFonts.tajawal(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'يرجى مشاهدة هذا الشرح القصير لبدء العمل بنجاح ودون أخطاء.',
                              style: GoogleFonts.tajawal(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Centered Video Player Container directly under text
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: _isYoutube ? _buildYoutubePlayer() : _buildNativePlayer(),
                              ),
                            ),

                            const SizedBox(height: 28),

                            // App Features Section Header
                            Text(
                              'ماذا يقدم لك تطبيق بنوصل؟',
                              style: GoogleFonts.tajawal(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Feature Item 1
                            _buildFeatureItem(
                              icon: Icons.flash_on_rounded,
                              title: 'شحن وتوصيل فائق السرعة',
                              description: 'نوفر لك تجربة توصيل سريعة وآمنة لجميع شحناتك وبكبسة زر واحدة.',
                            ),
                            const SizedBox(height: 12),

                            // Feature Item 2
                            _buildFeatureItem(
                              icon: Icons.map_rounded,
                              title: 'تتبع مباشر ولحظي',
                              description: 'تتبع مكان المندوب وحركة الشحنة مباشرة على الخريطة في كل ثانية.',
                            ),
                            const SizedBox(height: 12),

                            // Feature Item 3
                            _buildFeatureItem(
                              icon: Icons.account_balance_wallet_rounded,
                              title: 'محفظة مالية رقمية متكاملة',
                              description: 'إدارة أرباحك، التحصيل، وطلب سحب الأموال بكل سهولة وأمان تام.',
                            ),
                            const SizedBox(height: 12),

                            // Feature Item 4
                            _buildFeatureItem(
                              icon: Icons.support_agent_rounded,
                              title: 'دعم فني فوري 24/7',
                              description: 'فريق دعم كامل وجاهز لحل أي مشكلة أو استفسار تواجهه فوراً.',
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),

                    // Bottom Button Action
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: ElevatedButton(
                        onPressed: _markAsWatchedAndDismiss,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'فهمت، ابدأ استخدام التطبيق الآن',
                          style: GoogleFonts.tajawal(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
          ),
      ),
    );
  }

  // Helper widget builder for features list items
  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.tajawal(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.tajawal(
                    fontSize: 12.5,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 1. YouTube Player Widget Builder
  Widget _buildYoutubePlayer() {
    if (_youtubeController == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    return YoutubePlayer(
      controller: _youtubeController!,
      showVideoProgressIndicator: true,
      progressIndicatorColor: AppColors.primary,
      progressColors: const ProgressBarColors(
        playedColor: AppColors.primary,
        handleColor: AppColors.primary2,
      ),
      onEnded: (meta) {
        _markAsWatchedAndDismiss();
      },
    );
  }

  // 2. Native MP4 Video Player Widget Builder with Custom Controllers
  Widget _buildNativePlayer() {
    if (_videoController == null) {
      return const Center(
        child: Text(
          'خطأ في تحميل الفيديو',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    if (!_isNativeInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _showControls = !_showControls;
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(_videoController!),
          
          // Custom Video Playback Controllers Overlay
          if (_showControls) ...[
            Positioned.fill(
              child: Container(
                color: Colors.black45,
              ),
            ),
            
            // Central Play/Pause Trigger
            Center(
              child: IconButton(
                onPressed: () {
                  setState(() {
                    if (_isPlaying) {
                      _videoController!.pause();
                      _isPlaying = false;
                    } else {
                      _videoController!.play();
                      _isPlaying = true;
                    }
                  });
                },
                icon: Icon(
                  _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  color: Colors.white,
                  size: 64,
                ),
              ),
            ),

            // Video Control Bottom Bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: Colors.black54,
                child: Row(
                  children: [
                    ValueListenableBuilder(
                      valueListenable: _videoController!,
                      builder: (context, VideoPlayerValue value, child) {
                        final position = value.position;
                        final duration = value.duration;
                        
                        return Text(
                          '${_formatDuration(position)} / ${_formatDuration(duration)}',
                          style: GoogleFonts.tajawal(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: VideoProgressIndicator(
                        _videoController!,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: AppColors.primary,
                          bufferedColor: Colors.white24,
                          backgroundColor: Colors.white10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Mute/Unmute Toggle
                    IconButton(
                      icon: Icon(
                        _videoController!.value.volume == 0
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          if (_videoController!.value.volume == 0) {
                            _videoController!.setVolume(1.0);
                          } else {
                            _videoController!.setVolume(0.0);
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    String seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
