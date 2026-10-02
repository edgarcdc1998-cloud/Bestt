import 'package:flutter/material.dart';
import '../repositories/authentication_repository.dart';
import '../repositories/catalog_repository.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  final AuthenticationRepository authRepo;
  final CatalogRepository catalogRepo;

  const LoginScreen({
    super.key,
    required this.authRepo,
    required this.catalogRepo,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _xtreamFormKey = GlobalKey<FormState>();
  final _m3uFormKey = GlobalKey<FormState>();

  final _serverUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _m3uUrlController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _m3uUrlController.dispose();
    super.dispose();
  }

  Future<void> _handleXtreamLogin() async {
    if (!_xtreamFormKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.authRepo.loginXtream(
        _serverUrlController.text.trim(),
        _usernameController.text.trim(),
        _passwordController.text.trim(),
      );
      await widget.catalogRepo.loadCatalog();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              authRepo: widget.authRepo,
              catalogRepo: widget.catalogRepo,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleM3uLogin() async {
    if (!_m3uFormKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.authRepo.loginM3u(_m3uUrlController.text.trim());
      await widget.catalogRepo.loadCatalog();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              authRepo: widget.authRepo,
              catalogRepo: widget.catalogRepo,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              color: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_circle_fill, color: Colors.redAccent, size: 64),
                    const SizedBox(height: 12),
                    const Text(
                      'BEST PLAYER',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TabBar(
                      controller: _tabController,
                      indicatorColor: Colors.redAccent,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white54,
                      tabs: const [
                        Tab(text: 'Xtream Codes'),
                        Tab(text: 'Lista M3U'),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    SizedBox(
                      height: 240,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // Xtream Tab
                          Form(
                            key: _xtreamFormKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _serverUrlController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    labelText: 'URL do Servidor (ex: http://exemplo.com:8080)',
                                    prefixIcon: Icon(Icons.dns, color: Colors.white54),
                                  ),
                                  validator: (v) => v == null || v.isEmpty ? 'Informe a URL' : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _usernameController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    labelText: 'Usuário',
                                    prefixIcon: Icon(Icons.person, color: Colors.white54),
                                  ),
                                  validator: (v) => v == null || v.isEmpty ? 'Informe o usuário' : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: true,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    labelText: 'Senha',
                                    prefixIcon: Icon(Icons.lock, color: Colors.white54),
                                  ),
                                  validator: (v) => v == null || v.isEmpty ? 'Informe a senha' : null,
                                ),
                              ],
                            ),
                          ),
                          // M3U Tab
                          Form(
                            key: _m3uFormKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _m3uUrlController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    labelText: 'URL da Playlist M3U / M3U8',
                                    prefixIcon: Icon(Icons.link, color: Colors.white54),
                                  ),
                                  validator: (v) => v == null || v.isEmpty ? 'Informe a URL da lista' : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                if (_tabController.index == 0) {
                                  _handleXtreamLogin();
                                } else {
                                  _handleM3uLogin();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('ENTRAR', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
