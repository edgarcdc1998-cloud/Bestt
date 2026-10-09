import 'package:flutter/material.dart';
import '../models/episode.dart';
import '../models/media_item.dart';
import '../models/playback_type.dart';
import '../repositories/authentication_repository.dart';
import '../repositories/library_repository.dart';
import '../services/xtream_service.dart';
import '../widgets/catalog_widgets.dart';
import 'player_screen.dart';

class SeriesDetailScreen extends StatefulWidget {
  final MediaItem series;
  final AuthenticationRepository authRepo;
  final LibraryRepository libraryRepo;

  const SeriesDetailScreen({super.key, required this.series,
    required this.authRepo, required this.libraryRepo});

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  final XtreamService _xtreamService = XtreamService();
  Map<String, List<Episode>> _seasonsMap = {};
  String? _selectedSeason;
  String? _error;
  bool _isLoading = true;
  int _requestGeneration = 0;

  bool get _hasDirectStream => widget.series.streamUrl.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadSeriesInfo();
  }

  Future<void> _loadSeriesInfo() async {
    final generation = ++_requestGeneration;
    setState(() { _isLoading = true; _error = null; });
    // M3U entries already contain the playable URL and have no Xtream ID.
    if (_hasDirectStream) {
      setState(() => _isLoading = false);
      return;
    }
    final config = widget.authRepo.xtreamConfig;
    final seriesId = int.tryParse(widget.series.seriesId ?? '');
    if (config == null || seriesId == null || seriesId <= 0) {
      setState(() {
        _isLoading = false;
        _error = 'Os dados desta série estão incompletos. Entre novamente para atualizar o catálogo.';
      });
      return;
    }
    try {
      final seasons = await _xtreamService.getSeriesInfo(config, seriesId);
      if (!mounted || generation != _requestGeneration) return;
      final keys = seasons.keys.toList()..sort((a, b) {
        final first = int.tryParse(a);
        final second = int.tryParse(b);
        return first != null && second != null ? first.compareTo(second) : a.compareTo(b);
      });
      setState(() {
        _seasonsMap = {for (final key in keys) key: seasons[key]!};
        _selectedSeason = _seasonsMap.containsKey(_selectedSeason)
          ? _selectedSeason : (keys.isEmpty ? null : keys.first);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _isLoading = false;
        _error = 'Não foi possível carregar os episódios. Verifique sua conexão e tente novamente.';
      });
    }
  }

  MediaItem _episodeMedia(Episode episode) => MediaItem(
    id: 'ep_${episode.id}',
    title: '${widget.series.title} - T${episode.seasonNumber}E${episode.episodeNumber} - ${episode.title}',
    streamUrl: episode.streamUrl, type: PlaybackType.series,
    posterUrl: episode.coverUrl ?? widget.series.posterUrl,
    backdropUrl: widget.series.backdropUrl, description: episode.plot,
    seriesId: episode.seriesId, seasonNumber: episode.seasonNumber,
    episodeNumber: episode.episodeNumber, containerExtension: episode.containerExtension,
  );

  Future<void> _play(MediaItem media, {List<MediaItem>? playlist}) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => PlayerScreen(
      media: media, playlist: playlist, libraryRepository: widget.libraryRepo)));
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await widget.libraryRepo.flushResumePositions();
    if (mounted) setState(() {});
  }

  Widget _header() => Padding(padding: const EdgeInsets.all(16), child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 88, height: 132,
          child: CatalogArtwork(url: widget.series.posterUrl, icon: Icons.video_library_outlined))),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('SÉRIE', style: TextStyle(fontSize: 11, color: Colors.redAccent,
            fontWeight: FontWeight.w700, letterSpacing: 1.3)),
          const SizedBox(height: 8),
          Text(widget.series.title, style: const TextStyle(fontSize: 22,
            height: 1.15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ListenableBuilder(listenable: widget.libraryRepo, builder: (_, __) {
            final favorite = widget.libraryRepo.isMediaFavorite(widget.series.id);
            return OutlinedButton.icon(
              onPressed: () => widget.libraryRepo.toggleMediaFavorite(widget.series),
              icon: Icon(favorite ? Icons.star_rounded : Icons.star_outline_rounded, size: 18),
              label: Text(favorite ? 'Salvo' : 'Salvar'),
            );
          }),
        ])),
      ]),
      if (widget.series.description?.trim().isNotEmpty ?? false) ...[
        const SizedBox(height: 20),
        Text(widget.series.description!, style: const TextStyle(color: Colors.white70, height: 1.5)),
      ],
      const SizedBox(height: 20),
    ],
  ));

  @override
  Widget build(BuildContext context) {
    final episodes = _seasonsMap[_selectedSeason] ?? const <Episode>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes da série')),
      body: SafeArea(top: false, child: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: _header()),
        if (_isLoading)
          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator())))
        else if (_error != null)
          SliverToBoxAdapter(child: CatalogMessage(icon: Icons.wifi_off_rounded,
            title: 'Episódios indisponíveis', message: _error!, onRetry: _loadSeriesInfo))
        else if (_hasDirectStream)
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(onPressed: () => _play(widget.series),
              icon: const Icon(Icons.play_arrow_rounded), label: const Text('Reproduzir episódio'))))
        else ...[
          if (_seasonsMap.isNotEmpty)
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: DropdownButtonFormField<String>(
                value: _selectedSeason,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Temporada', border: OutlineInputBorder()),
                items: _seasonsMap.keys.map((season) => DropdownMenuItem(
                  value: season, child: Text('Temporada $season'))).toList(),
                onChanged: (value) { if (value != null) setState(() => _selectedSeason = value); },
              ))),
          if (episodes.isEmpty)
            const SliverToBoxAdapter(child: CatalogMessage(icon: Icons.video_library_outlined,
              title: 'Nenhum episódio encontrado', message: 'O provedor ainda não disponibilizou episódios para esta temporada.'))
          else
            SliverList(delegate: SliverChildBuilderDelegate((_, index) {
              final episode = episodes[index];
              final resume = widget.libraryRepo.getResumePosition('ep_${episode.id}');
              return Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Material(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(
                      width: 64, height: 52, child: CatalogArtwork(url: episode.coverUrl,
                        icon: Icons.play_arrow_rounded))),
                    title: Text('${episode.episodeNumber}. ${episode.title}', maxLines: 2,
                      overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(resume != null && resume.inSeconds >= 5
                      ? 'Continuar • ${resume.inMinutes} min assistidos'
                      : (episode.duration ?? 'Episódio ${episode.episodeNumber}'),
                      style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    trailing: const Icon(Icons.play_circle_outline, color: Colors.redAccent),
                    onTap: () => _play(_episodeMedia(episode), playlist: episodes.map(_episodeMedia).toList()),
                  ),
                ),
              );
            }, childCount: episodes.length)),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ])),
    );
  }
}
