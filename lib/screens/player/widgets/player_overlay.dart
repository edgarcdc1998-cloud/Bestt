import 'package:flutter/material.dart';
import '../../../models/media_item.dart';
import 'player_bottom_bar.dart';
import 'player_center_controls.dart';
import 'player_gradients.dart';
import 'player_top_bar.dart';

class PlayerOverlay extends StatelessWidget {
  final bool visible;
  final MediaItem media;
  final bool isPlaying;
  final bool isBuffering;
  final Duration position;
  final Duration duration;
  final String currentAspect;
  final VoidCallback onBack;
  final VoidCallback onPlayPause;
  final VoidCallback? onRewind;
  final VoidCallback? onForward;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onToggleAspect;
  final VoidCallback onAudioTrack;
  final VoidCallback onSubtitles;
  final VoidCallback onUserInteraction;

  const PlayerOverlay({
    super.key,
    required this.visible,
    required this.media,
    required this.isPlaying,
    required this.isBuffering,
    required this.position,
    required this.duration,
    required this.currentAspect,
    required this.onBack,
    required this.onPlayPause,
    this.onRewind,
    this.onForward,
    required this.onSeek,
    required this.onToggleAspect,
    required this.onAudioTrack,
    required this.onSubtitles,
    required this.onUserInteraction,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onUserInteraction,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        child: IgnorePointer(
          ignoring: !visible,
          child: Stack(
            children: [
              // Top Bar & Gradient
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: const BoxDecoration(gradient: PlayerGradients.topGradient),
                  child: SafeArea(
                    bottom: false,
                    child: PlayerTopBar(
                      media: media,
                      onBack: onBack,
                      onToggleAspect: onToggleAspect,
                      onAudioTrack: onAudioTrack,
                      onSubtitles: onSubtitles,
                      currentAspect: currentAspect,
                    ),
                  ),
                ),
              ),

              // Center Controls
              Center(
                child: PlayerCenterControls(
                  isPlaying: isPlaying,
                  isBuffering: isBuffering,
                  isLive: media.isLive,
                  onPlayPause: onPlayPause,
                  onRewind: onRewind,
                  onForward: onForward,
                ),
              ),

              // Bottom Bar & Gradient
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: const BoxDecoration(gradient: PlayerGradients.bottomGradient),
                  child: SafeArea(
                    top: false,
                    child: PlayerBottomBar(
                      media: media,
                      position: position,
                      duration: duration,
                      onSeek: onSeek,
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
}
