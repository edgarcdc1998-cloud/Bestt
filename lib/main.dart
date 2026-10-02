import 'package:flutter/material.dart';
import 'app.dart';
import 'repositories/authentication_repository.dart';
import 'repositories/catalog_repository.dart';
import 'services/app_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = await AppStorage.getInstance();
  final authRepo = AuthenticationRepository(storage);
  await authRepo.init();

  final catalogRepo = CatalogRepository(authRepo);
  if (authRepo.isAuthenticated) {
    await catalogRepo.loadCatalog();
  }

  runApp(
    BestPlayerApp(
      authRepo: authRepo,
      catalogRepo: catalogRepo,
    ),
  );
}
