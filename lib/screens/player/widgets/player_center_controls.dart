import 'package:flutter/material.dart';
import 'player_icon_button.dart';

class PlayerCenterControls extends StatelessWidget {
  final bool isPlaying;
  final bool isBuffering;
  final bool isLive;
  final VoidCallback onPlayPause;
  final VoidCallback? onRewind;
  final VoidCallback? onForward;

  const PlayerCenterControls({
    super.key,
    required this.isPlaying,
    required this.isBuffering,
    required this.isLive,
    required this.onPlayPause,
    this.onRewind,
    this.onForward,
  });

  @override
  Widget build(BuildContext context) {
    if (isBuffering) {
      return const SizedBox(
        width: 64,
        height: 64,
        child: CircularProgressIndicator(
          color: Colors.redAccent,
          strokeWidth: 4,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!isLive && onRewind != null) ...[
          PlayerIconButton(
            icon: Icons.replay_10,
            onPressed: onRewind!,
            size: 36,
            tooltip: 'Voltar 10s',
          ),
          const SizedBox(width: 32),
        ],
        Container(
          decoration: BoxDecoration(
            color: Colors.black45,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white30, width: 1.5),
          ),
          child: IconButton(
            icon: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 44,
            ),
            onPressed: onPlayPause,
            tooltip: isPlaying ? 'Pausar' : 'Reproduzir',
          ),
        ),
        if (!isLive && onForward != null) ...[
          const SizedBox(width: 32),
          PlayerIconButton(
            icon: Icons.forward_10,
            onPressed: onForward!,
            size: 36,
            tooltip: 'Avançar 10s',
          ),
        ],
      ],
    );
  }
}
