import 'package:flutter/material.dart';
import '../../repositories/library_repository.dart';

/// Shared return handling for the catalog and episode detail screen.
Future<void> openPlaybackRoute(BuildContext context, {
  required WidgetBuilder builder,
  required LibraryRepository library,
  required VoidCallback onReturn,
}) async {
  final route = MaterialPageRoute<void>(builder: builder);
  await Navigator.of(context).push<void>(route);
  await WidgetsBinding.instance.endOfFrame;
  if (!context.mounted) return;
  await library.flushResumePositions();
  if (context.mounted) onReturn();
}
