import 'package:flutter/material.dart';
import '../repositories/authentication_repository.dart';
import '../services/app_storage.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/library_repository.dart';
import 'epg_screen.dart';
import 'login_screen.dart';

/// Settings groups only expose actions already supported by the application.
class SettingsScreen extends StatefulWidget {
  final AuthenticationRepository authRepo;
  final CatalogRepository catalogRepo;
  final LibraryRepository libraryRepo;

  const SettingsScreen({super.key, required this.authRepo,
    required this.catalogRepo, required this.libraryRepo});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _refreshing = false;
  bool _autoNext = true;

  @override
  void initState() {
    super.initState();
    _loadPlayerPreference();
  }

  Future<void> _loadPlayerPreference() async {
    final storage = await AppStorage.getInstance();
    if (mounted) setState(() =>
      _autoNext = storage.getString('player_auto_next_episode') != 'false');
  }

  Future<void> _setAutoNext(bool enabled) async {
    final storage = await AppStorage.getInstance();
    await storage.setString('player_auto_next_episode', enabled.toString());
    if (mounted) setState(() => _autoNext = enabled);
  }

  void _message(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)));
  }

  Future<void> _refreshCatalog() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await widget.catalogRepo.loadCatalog();
      if (!mounted) return;
      _message(widget.catalogRepo.loadError == null
          ? 'Catálogo atualizado' : 'Não foi possível atualizar o catálogo');
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Limpar histórico?'),
        content: const Text('Os favoritos serão preservados.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Limpar')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.libraryRepo.clearHistory();
    _message('Histórico limpo');
  }

  Future<void> _logout() async {
    await widget.authRepo.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen(
        authRepo: widget.authRepo, catalogRepo: widget.catalogRepo)),
      (_) => false);
  }

  Widget _info(String label, String detail, IconData icon) => ListTile(
    leading: Icon(icon, color: Colors.white60),
    title: Text(label),
    subtitle: Text(detail),
  );

  Widget _section(Widget child) => Card(
    color: const Color(0xFF1D1D21),
    margin: const EdgeInsets.fromLTRB(14, 6, 14, 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Colors.white12)),
    child: child,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Configurações')),
    body: ListView(children: [
      const Padding(padding: EdgeInsets.fromLTRB(20, 16, 20, 14),
        child: Text('Personalize sua experiência no Best Player.',
          style: TextStyle(color: Colors.white60))),
      _section(ExpansionTile(
        leading: const Icon(Icons.play_circle_outline, color: Colors.redAccent),
        title: const Text('Reprodução e player'),
        subtitle: const Text('Player, orientação e continuidade',
          style: TextStyle(color: Colors.white60, fontSize: 12)),
        children: [
          _info('Mecanismo de vídeo', 'Troca entre Media3 e VLC disponível no player', Icons.movie_filter_outlined),
          _info('Rotação', 'O player abre em paisagem e restaura a orientação ao sair', Icons.screen_rotation),
          SwitchListTile(
            secondary: const Icon(Icons.skip_next),
            title: const Text('Próximo episódio automático'),
            subtitle: const Text('Reproduzir o próximo episódio ao terminar o atual'),
            value: _autoNext,
            onChanged: _setAutoNext,
            activeColor: Colors.redAccent,
          ),
          _info('Retomar reprodução', 'O player usa o progresso salvo de filmes e episódios', Icons.history),
        ],
      )),
      _section(ExpansionTile(
        leading: const Icon(Icons.playlist_play, color: Colors.redAccent),
        title: const Text('Catálogo IPTV'),
        subtitle: const Text('Atualização e dados do catálogo',
          style: TextStyle(color: Colors.white60, fontSize: 12)),
        children: [
          ListTile(
            leading: _refreshing
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh),
            title: const Text('Atualizar lista agora'),
            subtitle: Text('${widget.catalogRepo.channels.length} canais • '
              '${widget.catalogRepo.movies.length} filmes • '
              '${widget.catalogRepo.series.length} séries'),
            onTap: _refreshing ? null : _refreshCatalog,
          ),
        ],
      )),
      _section(ExpansionTile(
        leading: const Icon(Icons.palette_outlined, color: Colors.redAccent),
        title: const Text('Aparência'),
        subtitle: const Text('Tema e organização do aplicativo',
          style: TextStyle(color: Colors.white60, fontSize: 12)),
        children: [
          _info('Tema atual', 'Escuro, com detalhes vermelhos', Icons.dark_mode_outlined),
          _info('Organização', 'Capas em grade e filtros por categoria', Icons.grid_view),
        ],
      )),
      _section(ExpansionTile(
        leading: const Icon(Icons.live_tv_outlined, color: Colors.redAccent),
        title: const Text('TV ao vivo e EPG'),
        subtitle: const Text('Guia e programação dos canais',
          style: TextStyle(color: Colors.white60, fontSize: 12)),
        children: [
          ListTile(
            leading: const Icon(Icons.view_timeline_outlined),
            title: const Text('Guia de programação (EPG)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => EpgScreen(
                channels: widget.catalogRepo.channels,
                authRepo: widget.authRepo,
                libraryRepo: widget.libraryRepo))),
          ),
        ],
      )),
      _section(ExpansionTile(
        leading: const Icon(Icons.cast, color: Colors.redAccent),
        title: const Text('Transmissão e Best Roku'),
        subtitle: const Text('Dispositivos e transmissão',
          style: TextStyle(color: Colors.white60, fontSize: 12)),
        children: [
          _info('Transmitir', 'A busca por dispositivos Chromecast está disponível dentro do player', Icons.cast_connected),
          _info('Best Roku', 'Use o receptor configurado; a conexão é gerenciada pelo app', Icons.tv),
        ],
      )),
      _section(ExpansionTile(
        leading: const Icon(Icons.shield_outlined, color: Colors.redAccent),
        title: const Text('Dados e privacidade'),
        subtitle: const Text('Histórico e conta',
          style: TextStyle(color: Colors.white60, fontSize: 12)),
        children: [
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Limpar histórico de reprodução'),
            subtitle: const Text('Não remove seus favoritos'),
            onTap: _clearHistory,
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sair da conta'),
            onTap: _logout,
          ),
        ],
      )),
    ]),
  );
}
