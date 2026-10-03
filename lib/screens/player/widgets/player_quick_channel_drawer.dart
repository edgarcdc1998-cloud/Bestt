import 'package:flutter/material.dart';
import '../../../models/media_item.dart';

class PlayerQuickChannelDrawer extends StatefulWidget {
  final List<MediaItem> playlist;
  final MediaItem currentMedia;
  final ValueChanged<MediaItem> onSelectMedia;
  final VoidCallback onClose;

  const PlayerQuickChannelDrawer({
    super.key,
    required this.playlist,
    required this.currentMedia,
    required this.onSelectMedia,
    required this.onClose,
  });

  @override
  State<PlayerQuickChannelDrawer> createState() => _PlayerQuickChannelDrawerState();
}

class _PlayerQuickChannelDrawerState extends State<PlayerQuickChannelDrawer> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.playlist.where((item) {
      if (_searchQuery.isEmpty) return true;
      return item.title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Container(
      width: 340,
      color: const Color(0xE6141414),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  const Icon(Icons.list_alt, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Lista de Canais',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Buscar canal...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white10,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),

            const Divider(color: Colors.white12, height: 16),

            // Channel List
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhum canal encontrado',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final isSelected = item.id == widget.currentMedia.id;

                        return Container(
                          color: isSelected ? Colors.redAccent.withValues(alpha: 0.2) : Colors.transparent,
                          child: ListTile(
                            dense: true,
                            leading: item.posterUrl != null
                                ? Image.network(
                                    item.posterUrl!,
                                    width: 32,
                                    height: 32,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.tv, color: Colors.white38, size: 24),
                                  )
                                : const Icon(Icons.tv, color: Colors.white38, size: 24),
                            title: Text(
                              item.title,
                              style: TextStyle(
                                color: isSelected ? Colors.redAccent : Colors.white,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: item.categoryName != null
                                ? Text(
                                    item.categoryName!,
                                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            trailing: isSelected
                                ? const Icon(Icons.play_arrow, color: Colors.redAccent, size: 20)
                                : null,
                            onTap: () {
                              widget.onSelectMedia(item);
                              widget.onClose();
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
