import 'package:flutter/material.dart';
import '../models/media_item.dart';

/// A single fallback for missing, malformed and failed provider artwork.
class CatalogArtwork extends StatelessWidget {
  final String? url;
  final IconData icon;
  final BoxFit fit;

  const CatalogArtwork({super.key, this.url, this.icon = Icons.movie_outlined,
    this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: const Color(0xFF24242B),
      child: Center(child: Icon(icon, color: Colors.white38, size: 36)),
    );
    final uri = Uri.tryParse(url?.trim() ?? '');
    if (uri == null || !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) return fallback;
    return Image.network(
      uri.toString(),
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => fallback,
      frameBuilder: (_, child, frame, wasSynchronouslyLoaded) =>
        wasSynchronouslyLoaded || frame != null
          ? child
          : const ColoredBox(
              color: Color(0xFF24242B),
              child: Center(child: SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white30))),
            ),
    );
  }
}

class CatalogMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const CatalogMessage({super.key, required this.icon, required this.title,
    required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 44, color: Colors.white38),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white60, height: 1.5)),
        if (onRetry != null) ...[
          const SizedBox(height: 20),
          FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente')),
        ],
      ]),
    ),
  );
}

class MediaPosterCard extends StatelessWidget {
  final MediaItem media;
  final VoidCallback onTap;

  const MediaPosterCard({super.key, required this.media, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: media.title,
    child: Material(
      color: const Color(0xFF1C1C20),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: Stack(fit: StackFit.expand, children: [
            CatalogArtwork(url: media.posterUrl,
              icon: media.isSeries ? Icons.video_library_outlined : Icons.movie_outlined),
            Positioned(top: 8, left: 8, child: DecoratedBox(
              decoration: BoxDecoration(color: const Color(0xE6121212),
                borderRadius: BorderRadius.circular(5)),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                child: Text(media.isSeries ? 'SÉRIE' : 'FILME',
                  style: const TextStyle(color: Colors.white, fontSize: 9,
                    letterSpacing: 0.7, fontWeight: FontWeight.w800))))),
          ])),
          Padding(padding: const EdgeInsets.fromLTRB(9, 9, 9, 10),
            child: Text(media.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, height: 1.35, fontWeight: FontWeight.w600))),
        ],
      )),
    ),
  );
}

class MediaCatalogGrid extends StatelessWidget {
  final List<MediaItem> items;
  final ValueChanged<MediaItem> onTap;
  final String storageKey;
  final bool compact;

  const MediaCatalogGrid({super.key, required this.items, required this.onTap,
    required this.storageKey, this.compact = false});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final width = constraints.maxWidth - 32;
    final columns = (width / (compact ? 125 : 164)).floor().clamp(2, 6);
    final cardWidth = (width - (columns - 1) * 12) / columns;
    final titleHeight = MediaQuery.textScalerOf(context).scale(13) * 2.7 + 14;
    return GridView.builder(
      key: PageStorageKey(storageKey),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisExtent: cardWidth * 1.5 + titleHeight,
        crossAxisSpacing: 12, mainAxisSpacing: 20,
      ),
      itemCount: items.length,
      itemBuilder: (_, index) => MediaPosterCard(media: items[index],
        onTap: () => onTap(items[index])),
    );
  });
}
