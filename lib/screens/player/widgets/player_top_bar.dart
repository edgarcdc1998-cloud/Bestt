import 'package:flutter/material.dart';
import '../../../models/media_item.dart';
import 'player_icon_button.dart';

class PlayerTopBar extends StatelessWidget {
  final MediaItem media;
  final VoidCallback onBack;
  final VoidCallback onToggleAspect;
  final VoidCallback onAudioTrack;
  final VoidCallback onSubtitles;
  final String currentAspect;

  const PlayerTopBar({
    super.key,
    required this.media,
    required this.onBack,
    required this.onToggleAspect,
    required this.onAudioTrack,
    required this.onSubtitles,
    required this.currentAspect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          PlayerIconButton(
            icon: Icons.arrow_back,
            onPressed: onBack,
            tooltip: 'Voltar',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  media.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (media.categoryName != null)
                  Text(
                    media.categoryName!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: onToggleAspect,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.white24,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            child: Text(
              currentAspect.toUpperCase(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          PlayerIconButton(
            icon: Icons.audiotrack,
            onPressed: onAudioTrack,
            tooltip: 'Trilha de Áudio',
          ),
          PlayerIconButton(
            icon: Icons.subtitles,
            onPressed: onSubtitles,
            tooltip: 'Legendas',
          ),
        ],
      ),
    );
  }
}
