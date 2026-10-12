import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/channel.dart';
import '../models/epg_program.dart';
import '../models/media_item.dart';
import '../models/playback_type.dart';
import '../repositories/authentication_repository.dart';
import '../repositories/library_repository.dart';
import '../services/epg_service.dart';
import '../widgets/catalog_widgets.dart';
import 'player_screen.dart';

class EpgScreen extends StatefulWidget {
  final List<Channel> channels;
  final AuthenticationRepository authRepo;
  final LibraryRepository libraryRepo;

  const EpgScreen({
    super.key,
    required this.channels,
    required this.authRepo,
    required this.libraryRepo,
  });

  @override
  State<EpgScreen> createState() => _EpgScreenState();
}

class _EpgScreenState extends State<EpgScreen> {
  final EpgService _epgService = EpgService();
  Channel? _selectedChannel;
  List<EpgProgram> _programs = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.channels.isNotEmpty) {
      _selectChannel(widget.channels.first);
    }
  }

  Future<void> _selectChannel(Channel channel) async {
    setState(() {
      _selectedChannel = channel;
      _isLoading = true;
    });

    if (widget.authRepo.xtreamConfig != null && channel.streamId != null) {
      final list = await _epgService.getShortEpg(widget.authRepo.xtreamConfig!, channel.streamId!);
      if (mounted) {
        setState(() {
          _programs = list;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _programs = [];
          _isLoading = false;
        });
      }
    }
  }

  void _playChannel(Channel channel) {
    final media = MediaItem(
      id: channel.id,
      title: channel.name,
      streamUrl: channel.streamUrl,
      type: PlaybackType.live,
      posterUrl: channel.logoUrl,
      categoryId: channel.categoryId,
      categoryName: channel.categoryName,
      streamId: channel.streamId,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          media: media,
          libraryRepository: widget.libraryRepo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedChannel;
    final timeFmt = DateFormat('HH:mm');
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Guia de programação', maxLines: 1,
          overflow: TextOverflow.ellipsis),
        backgroundColor: const Color(0xFF1E1E1E),
      ),
      body: SafeArea(child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Canais', style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800)),
          ),
          if (widget.channels.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Nenhum canal disponível',
                style: TextStyle(color: Colors.white60)),
            )
          else
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: widget.channels.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final channel = widget.channels[index];
                  final active = selected?.id == channel.id;
                  return SizedBox(
                    width: 180,
                    child: Material(
                      color: active ? const Color(0xFF382022) : const Color(0xFF222226),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: active ? Colors.redAccent : Colors.white12,
                          width: active ? 1.5 : 1)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _selectChannel(channel),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 38, width: 44,
                                child: CatalogArtwork(url: channel.logoUrl,
                                  icon: Icons.live_tv, fit: BoxFit.contain)),
                              const SizedBox(height: 6),
                              Text(channel.name, maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13, fontWeight: active
                                    ? FontWeight.w700 : FontWeight.w500,
                                  color: active ? Colors.redAccent : Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          if (selected != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Programação', style: TextStyle(
                      color: Colors.white60, fontSize: 12)),
                    Text(selected.name, maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18,
                        fontWeight: FontWeight.w700)),
                  ],
                )),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.redAccent),
                  onPressed: () => _playChannel(selected),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Assistir'),
                ),
              ]),
            ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: selected == null
              ? const Center(child: Text('Selecione um canal',
                  style: TextStyle(color: Colors.white54)))
              : _isLoading
                ? const Center(child: CircularProgressIndicator(
                    color: Colors.redAccent))
                : _programs.isEmpty
                  ? const Center(child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Nenhuma programação disponível',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54))))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _programs.length,
                      itemBuilder: (context, index) {
                        final prog = _programs[index];
                        final isNow = prog.isCurrentlyAiring;
                        return Card(
                          color: isNow
                            ? Colors.redAccent.withValues(alpha: 0.15)
                            : const Color(0xFF1E1E1E),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(spacing: 8, runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text('${timeFmt.format(prog.startTime)} - ${timeFmt.format(prog.endTime)}',
                                      style: TextStyle(
                                        color: isNow ? Colors.redAccent : Colors.white70,
                                        fontWeight: FontWeight.bold)),
                                    if (isNow)
                                      const Text('NO AR', style: TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 11, fontWeight: FontWeight.w800)),
                                  ]),
                                const SizedBox(height: 6),
                                Text(prog.title, style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                                if (prog.description != null &&
                                    prog.description!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(prog.description!,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white60, fontSize: 13)),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
          ),
        ],
      )),
    );
  }
}
