import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:best_player/repositories/library_repository.dart';
import 'package:best_player/screens/player/playback_navigation.dart';
import 'package:best_player/services/app_storage.dart';

// Replaces only the native playback backend. Like PlayerScreen, it records
// the final position in dispose after the route exit animation.
class SavingPlayer extends StatefulWidget {
  final LibraryRepository library;
  const SavingPlayer({super.key, required this.library});
  @override
  State<SavingPlayer> createState() => _SavingPlayerState();
}

class _SavingPlayerState extends State<SavingPlayer> {
  @override
  void dispose() {
    widget.library.saveResumePosition('movie', const Duration(seconds: 42));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(body: TextButton(
    onPressed: () => Navigator.of(context).pop(), child: const Text('Voltar')));
}

void main() {
  testWidgets('return refresh includes the final position saved during player disposal', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final library = LibraryRepository(await AppStorage.getInstance());
    await library.init();
    addTearDown(library.dispose);
    var label = '0 s';
    await tester.pumpWidget(MaterialApp(home: StatefulBuilder(builder: (context, setState) =>
      Scaffold(body: Column(children: [
        Text(label),
        TextButton(onPressed: () => openPlaybackRoute(context,
          builder: (_) => SavingPlayer(library: library), library: library,
          onReturn: () => setState(() => label = '${library.getResumePosition('movie')?.inSeconds ?? 0} s')),
          child: const Text('Assistir')),
      ])))));
    await tester.tap(find.text('Assistir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('42 s'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
