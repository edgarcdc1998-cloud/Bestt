import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/channel.dart';
import '../models/epg_program.dart';
import '../models/media_item.dart';
import '../models/playback_type.dart';
import '../repositories/authentication_repository.dart';
import '../repositories/library_repository.dart';
import '../services/epg_service.dart';
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
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Guia de Programação (EPG)'),
        backgroundColor: const Color(0xFF1E1E1E),
      ),
      body: Row(
        children: [
          // Channels List
          SizedBox(
            width: 280,
            child: ListView.builder(
              itemCount: widget.channels.length,
              itemBuilder: (context, index) {
                final ch = widget.channels[index];
                final isSelected = _selectedChannel?.id == ch.id;

                return ListTile(
                  selected: isSelected,
                  selectedTileColor: Colors.white10,
                  leading: ch.logoUrl != null
                      ? Image.network(
                          ch.logoUrl!,
                          width: 36,
                          height: 36,
                          errorBuilder: (_, __, ___) => const Icon(Icons.tv, color: Colors.white54),
                        )
                      : const Icon(Icons.tv, color: Colors.white54),
                  title: Text(
                    ch.name,
                    style: TextStyle(
                      color: isSelected ? Colors.redAccent : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _selectChannel(ch),
                );
              },
            ),
          ),
          const VerticalDivider(width: 1, color: Colors.white24),

          // EPG Program List
          Expanded(
            child: _selectedChannel == null
                ? const Center(child: Text('Selecione um canal', style: TextStyle(color: Colors.white54)))
                : Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: const Color(0xFF1E1E1E),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedChannel!.name,
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _playChannel(_selectedChannel!),
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Assistir'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
                            : _programs.isEmpty
                                ? const Center(child: Text('Nenhuma programação disponível', style: TextStyle(color: Colors.white54)))
                                : ListView.builder(
                                    itemCount: _programs.length,
                                    itemBuilder: (context, index) {
                                      final prog = _programs[index];
                                      final isNow = prog.isCurrentlyAiring;
                                      final timeFmt = DateFormat('HH:mm');

                                      return Card(
                                        color: isNow ? Colors.redAccent.withValues(alpha: 0.15) : const Color(0xFF1E1E1E),
                                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    '${timeFmt.format(prog.startTime)} - ${timeFmt.format(prog.endTime)}',
                                                    style: TextStyle(
                                                      color: isNow ? Colors.redAccent : Colors.white70,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  if (isNow) ...[
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.redAccent,
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: const Text('NO AR', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                prog.title,
                                                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                                              ),
                                              if (prog.description != null && prog.description!.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  prog.description!,
                                                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
