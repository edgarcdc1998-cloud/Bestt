import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:best_player/models/media_item.dart';
import 'package:best_player/models/playback_type.dart';
import 'package:best_player/screens/player/widgets/player_sleep_timer_dialog.dart';
import 'package:best_player/screens/player/widgets/player_quick_channel_drawer.dart';
import 'package:best_player/screens/player/widgets/player_gesture_detector.dart';

void main() {
  group('PlayerExperienceWidgets Tests', () {
    testWidgets('PlayerSleepTimerDialog displays options and triggers callback', (tester) async {
      int? selectedMinutes = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerSleepTimerDialog(
              currentMinutes: 30,
              onSelected: (mins) {
                selectedMinutes = mins;
              },
            ),
          ),
        ),
      );

      expect(find.text('Temporizador de Sono (Sleep Timer)'), findsOneWidget);
      expect(find.text('Desativado'), findsOneWidget);
      expect(find.text('30 minutos'), findsOneWidget);
      expect(find.text('60 minutos'), findsOneWidget);

      await tester.tap(find.text('60 minutos'));
      await tester.pumpAndSettle();

      expect(selectedMinutes, equals(60));
    });

    testWidgets('PlayerQuickChannelDrawer filters channels and selects channel', (tester) async {
      final channels = [
        const MediaItem(
          id: '1',
          title: 'Globo SP HD',
          streamUrl: 'http://stream/1.m3u8',
          type: PlaybackType.live,
        ),
        const MediaItem(
          id: '2',
          title: 'ESPN Brasil',
          streamUrl: 'http://stream/2.m3u8',
          type: PlaybackType.live,
        ),
      ];

      MediaItem? selectedItem;
      bool closed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerQuickChannelDrawer(
              playlist: channels,
              currentMedia: channels.first,
              onSelectMedia: (m) => selectedItem = m,
              onClose: () => closed = true,
            ),
          ),
        ),
      );

      expect(find.text('Lista de Canais'), findsOneWidget);
      expect(find.text('Globo SP HD'), findsOneWidget);
      expect(find.text('ESPN Brasil'), findsOneWidget);

      // Search filter
      await tester.enterText(find.byType(TextField), 'ESPN');
      await tester.pumpAndSettle();

      expect(find.text('Globo SP HD'), findsNothing);
      expect(find.text('ESPN Brasil'), findsOneWidget);

      // Tap channel
      await tester.tap(find.text('ESPN Brasil'));
      await tester.pumpAndSettle();

      expect(selectedItem?.id, equals('2'));
      expect(closed, isTrue);
    });

    testWidgets('PlayerGestureDetector reacts to taps and passes child', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerGestureDetector(
              isLocked: false,
              isLive: false,
              currentVolume: 0.8,
              currentBrightness: 0.5,
              onTap: () => tapped = true,
              onDoubleTapLeft: () {},
              onDoubleTapRight: () {},
              onVolumeChange: (_) {},
              onBrightnessChange: (_) {},
              child: const Text('Video Surface Content'),
            ),
          ),
        ),
      );

      expect(find.text('Video Surface Content'), findsOneWidget);

      await tester.tap(find.text('Video Surface Content'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });
}
