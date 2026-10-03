import 'package:flutter/material.dart';
import '../models/episode.dart';
import '../models/media_item.dart';
import '../models/playback_type.dart';
import '../repositories/authentication_repository.dart';
import '../repositories/library_repository.dart';
import '../services/xtream_service.dart';
import 'player_screen.dart';

class SeriesDetailScreen extends StatefulWidget {
  final MediaItem series;
  final AuthenticationRepository authRepo;
  final LibraryRepository libraryRepo;

  const SeriesDetailScreen({
    super.key,
    required this.series,
    required this.authRepo,
    required this.libraryRepo,
  });

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  final XtreamService _xtreamService = XtreamService();
  Map<String, List<Episode>> _seasonsMap = {};
  String? _selectedSeason;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSeriesInfo();
  }

  Future<void> _loadSeriesInfo() async {
    if (widget.authRepo.xtreamConfig == null || widget.series.seriesId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final seriesId = int.tryParse(widget.series.seriesId!) ?? 0;
      final seasons = await _xtreamService.getSeriesInfo(widget.authRepo.xtreamConfig!, seriesId);
      if (mounted) {
        setState(() {
          _seasonsMap = seasons;
          if (seasons.isNotEmpty) {
            _selectedSeason = seasons.keys.first;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _playEpisode(Episode ep) {
    final media = MediaItem(
      id: 'ep_${ep.id}',
      title: '${widget.series.title} - T${ep.seasonNumber}E${ep.episodeNumber} - ${ep.title}',
      streamUrl: ep.streamUrl,
      type: PlaybackType.series,
      posterUrl: ep.coverUrl ?? widget.series.posterUrl,
      backdropUrl: widget.series.backdropUrl,
      description: ep.plot,
      seriesId: ep.seriesId,
      seasonNumber: ep.seasonNumber,
      episodeNumber: ep.episodeNumber,
      containerExtension: ep.containerExtension,
    );

    List<MediaItem>? playlist;
    if (_selectedSeason != null && _seasonsMap[_selectedSeason] != null) {
      playlist = _seasonsMap[_selectedSeason]!.map((e) => MediaItem(
        id: 'ep_${e.id}',
        title: '${widget.series.title} - T${e.seasonNumber}E${e.episodeNumber} - ${e.title}',
        streamUrl: e.streamUrl,
        type: PlaybackType.series,
        posterUrl: e.coverUrl ?? widget.series.posterUrl,
        backdropUrl: widget.series.backdropUrl,
        description: e.plot,
        seriesId: e.seriesId,
        seasonNumber: e.seasonNumber,
        episodeNumber: e.episodeNumber,
        containerExtension: e.containerExtension,
      )).toList();
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          media: media,
          playlist: playlist,
          libraryRepository: widget.libraryRepo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(widget.series.title),
        backgroundColor: const Color(0xFF1E1E1E),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.series.description != null && widget.series.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      widget.series.description!,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                // Season Selector
                if (_seasonsMap.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: DropdownButton<String>(
                      value: _selectedSeason,
                      dropdownColor: const Color(0xFF1E1E1E),
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      isExpanded: true,
                      items: _seasonsMap.keys.map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text('Temporada $s'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedSeason = val);
                        }
                      },
                    ),
                  ),

                const Divider(color: Colors.white24),

                // Episodes List
                Expanded(
                  child: _selectedSeason == null || _seasonsMap[_selectedSeason] == null
                      ? const Center(child: Text('Nenhum episódio encontrado', style: TextStyle(color: Colors.white54)))
                      : ListView.builder(
                          itemCount: _seasonsMap[_selectedSeason]!.length,
                          itemBuilder: (context, index) {
                            final ep = _seasonsMap[_selectedSeason]![index];
                            return ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'E${ep.episodeNumber}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                ep.title,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                              subtitle: ep.duration != null
                                  ? Text(ep.duration!, style: const TextStyle(color: Colors.white54))
                                  : null,
                              trailing: const Icon(Icons.play_circle_outline, color: Colors.redAccent),
                              onTap: () => _playEpisode(ep),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
