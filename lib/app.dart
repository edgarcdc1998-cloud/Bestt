import 'package:flutter/material.dart';
import 'repositories/authentication_repository.dart';
import 'repositories/catalog_repository.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

class BestPlayerApp extends StatelessWidget {
  final AuthenticationRepository authRepo;
  final CatalogRepository catalogRepo;

  const BestPlayerApp({
    super.key,
    required this.authRepo,
    required this.catalogRepo,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Best Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Colors.redAccent,
          secondary: Colors.redAccent,
          surface: Color(0xFF1E1E1E),
        ),
        useMaterial3: true,
      ),
      home: authRepo.isAuthenticated
          ? HomeScreen(authRepo: authRepo, catalogRepo: catalogRepo)
          : LoginScreen(authRepo: authRepo, catalogRepo: catalogRepo),
    );
  }
}
