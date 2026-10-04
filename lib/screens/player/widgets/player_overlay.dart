import 'package:flutter/material.dart';
import '../../../models/media_item.dart';
import 'player_bottom_bar.dart';
import 'player_center_controls.dart';
import 'player_gradients.dart';
import 'player_top_bar.dart';

class PlayerOverlay extends StatelessWidget {
  final bool visible;
  final bool isLocked;
  final MediaItem media;
  final bool isPlaying;
  final bool isBuffering;
  final Duration position;
  final Duration duration;
  final String currentAspect;
  final int? sleepTimerRemainingSeconds;
  final double currentSpeed;
  final VoidCallback onBack;
  final VoidCallback onPlayPause;
  final VoidCallback? onRewind;
  final VoidCallback? onForward;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onToggleAspect;
  final VoidCallback? onAudioTrack;
  final VoidCallback? onSubtitles;
  final VoidCallback onSleepTimer;
  final VoidCallback onLock;
  final VoidCallback onUnlock;
  final VoidCallback? onQuickChannels;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onToggleSpeed;
  final VoidCallback onUserInteraction;
  final VoidCallback onToggleBackend;
  final String backendLabel;

  const PlayerOverlay({
    super.key,
    required this.visible,
    this.isLocked = false,
    required this.media,
    required this.isPlaying,
    required this.isBuffering,
    required this.position,
    required this.duration,
    required this.currentAspect,
    this.sleepTimerRemainingSeconds,
    this.currentSpeed = 1.0,
    required this.onBack,
    required this.onPlayPause,
    this.onRewind,
    this.onForward,
    required this.onSeek,
    required this.onToggleAspect,
    this.onAudioTrack,
    this.onSubtitles,
    required this.onSleepTimer,
    required this.onLock,
    required this.onUnlock,
    this.onQuickChannels,
    this.onPrevious,
    this.onNext,
    this.onToggleSpeed,
    required this.onUserInteraction,
    required this.onToggleBackend,
    required this.backendLabel,
  });

  @override
  Widget build(BuildContext context) {
    // When screen is locked, display only the floating unlock button
    if (isLocked) {
      return AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        child: IgnorePointer(
          ignoring: !visible,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 32.0),
              child: FloatingActionButton(
                mini: true,
                backgroundColor: Colors.black54,
                foregroundColor: Colors.redAccent,
                onPressed: onUnlock,
                tooltip: 'Desbloquear Tela',
                child: const Icon(Icons.lock, size: 20),
              ),
            ),
          ),
        ),
      );
    }

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
                      onSleepTimer: onSleepTimer,
                      onLock: onLock,
                      onQuickChannels: onQuickChannels,
                      currentAspect: currentAspect,
                      sleepTimerRemainingSeconds: sleepTimerRemainingSeconds,
                      onToggleBackend: onToggleBackend,
                      backendLabel: backendLabel,
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
                      onPrevious: onPrevious,
                      onNext: onNext,
                      onToggleSpeed: onToggleSpeed,
                      currentSpeed: currentSpeed,
                      onQuickChannels: onQuickChannels,
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
