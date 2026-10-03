import 'package:flutter/material.dart';
import '../../../models/media_item.dart';

class PlayerBottomBar extends StatelessWidget {
  final MediaItem media;
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onToggleSpeed;
  final double currentSpeed;
  final VoidCallback? onQuickChannels;

  const PlayerBottomBar({
    super.key,
    required this.media,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.onPrevious,
    this.onNext,
    this.onToggleSpeed,
    this.currentSpeed = 1.0,
    this.onQuickChannels,
  });

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (media.isLive) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                children: [
                  Icon(Icons.circle, color: Colors.white, size: 10),
                  SizedBox(width: 6),
                  Text(
                    'AO VIVO',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            if (onPrevious != null)
              IconButton(
                icon: const Icon(Icons.skip_previous, color: Colors.white, size: 26),
                tooltip: 'Canal Anterior',
                onPressed: onPrevious,
              ),
            if (onQuickChannels != null)
              TextButton.icon(
                onPressed: onQuickChannels,
                icon: const Icon(Icons.tv, color: Colors.white, size: 18),
                label: const Text('CANAIS', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(backgroundColor: Colors.white12),
              ),
            if (onNext != null)
              IconButton(
                icon: const Icon(Icons.skip_next, color: Colors.white, size: 26),
                tooltip: 'Próximo Canal',
                onPressed: onNext,
              ),
          ],
        ),
      );
    }

    final double maxSeconds = duration.inSeconds > 0 ? duration.inSeconds.toDouble() : 1.0;
    final double currentSeconds = position.inSeconds.toDouble().clamp(0.0, maxSeconds);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
              trackHeight: 3.0,
              activeTrackColor: Colors.redAccent,
              inactiveTrackColor: Colors.white30,
              thumbColor: Colors.redAccent,
            ),
            child: Slider(
              value: currentSeconds,
              min: 0.0,
              max: maxSeconds,
              onChanged: (val) {
                onSeek(Duration(seconds: val.toInt()));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatDuration(position),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    const Text(' / ', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    Text(
                      _formatDuration(duration),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onPrevious != null)
                      IconButton(
                        icon: const Icon(Icons.skip_previous, color: Colors.white, size: 22),
                        tooltip: 'Anterior',
                        onPressed: onPrevious,
                      ),
                    if (onToggleSpeed != null)
                      TextButton(
                        onPressed: onToggleSpeed,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white12,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          minimumSize: const Size(40, 26),
                        ),
                        child: Text(
                          '${currentSpeed.toStringAsFixed(currentSpeed.truncateToDouble() == currentSpeed ? 0 : 2)}x',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (onNext != null)
                      IconButton(
                        icon: const Icon(Icons.skip_next, color: Colors.white, size: 22),
                        tooltip: 'Próximo',
                        onPressed: onNext,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
