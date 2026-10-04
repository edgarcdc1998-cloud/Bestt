import 'package:flutter/material.dart';
import '../../../models/media_item.dart';
import 'player_icon_button.dart';

class PlayerTopBar extends StatelessWidget {
  final MediaItem media;
  final VoidCallback onBack;
  final VoidCallback onToggleAspect;
  final VoidCallback onAudioTrack;
  final VoidCallback onSubtitles;
  final VoidCallback onSleepTimer;
  final VoidCallback onLock;
  final VoidCallback? onQuickChannels;
  final String currentAspect;
  final int? sleepTimerRemainingSeconds;
  final VoidCallback onToggleBackend;
  final String backendLabel;

  const PlayerTopBar({
    super.key,
    required this.media,
    required this.onBack,
    required this.onToggleAspect,
    required this.onAudioTrack,
    required this.onSubtitles,
    required this.onSleepTimer,
    required this.onLock,
    this.onQuickChannels,
    required this.currentAspect,
    this.sleepTimerRemainingSeconds,
    required this.onToggleBackend,
    required this.backendLabel,
  });

  String _formatSleepTimer(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

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
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (onQuickChannels != null)
            PlayerIconButton(
              icon: Icons.list,
              onPressed: onQuickChannels!,
              tooltip: 'Lista de Canais',
            ),
          TextButton(
            onPressed: onToggleBackend,
            style: TextButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.redAccent.withValues(alpha: 0.7), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
            child: Text(backendLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
          Stack(
            alignment: Alignment.center,
            children: [
              PlayerIconButton(
                icon: Icons.bedtime_outlined,
                onPressed: onSleepTimer,
                tooltip: 'Temporizador de Sono',
              ),
              if (sleepTimerRemainingSeconds != null && sleepTimerRemainingSeconds! > 0)
                Positioned(
                  bottom: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatSleepTimer(sleepTimerRemainingSeconds!),
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
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
          PlayerIconButton(
            icon: Icons.lock_outline,
            onPressed: onLock,
            tooltip: 'Bloquear Tela',
          ),
        ],
      ),
    );
  }
}
