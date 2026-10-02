import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:best_player/models/channel.dart';
import 'package:best_player/services/app_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppStorage P0-3 Defensive JSON Handling Tests', () {
    late AppStorage storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = AppStorage(prefs);
    });

    test('Loads and serializes valid JSON Map successfully', () async {
      const key = 'user_data';
      final sample = {'name': 'Player User', 'active': true, 'credits': 100};

      final saved = await storage.setJson(key, sample);
      expect(saved, isTrue);

      final loaded = storage.getJsonMap(key);
      expect(loaded, isNotNull);
      expect(loaded!['name'], equals('Player User'));
      expect(loaded['active'], isTrue);
      expect(loaded['credits'], equals(100));
    });

    test('Returns default value when JSON is empty or key not found', () {
      final loadedMap = storage.getJsonMap('non_existing_key', defaultValue: {'status': 'default'});
      expect(loadedMap, isNotNull);
      expect(loadedMap!['status'], equals('default'));

      final loadedList = storage.getJsonList('non_existing_list', defaultValue: ['item1']);
      expect(loadedList, equals(['item1']));
    });

    test('Handles malformed and corrupted JSON strings safely without throwing', () async {
      const key = 'corrupted_payload';
      // Injected corrupted JSON string (e.g. truncated write)
      await storage.setString(key, '{"incomplete_json": true, "broken": [');

      final loadedMap = storage.getJsonMap(key, defaultValue: {'fallback': true});
      expect(loadedMap, isNotNull);
      expect(loadedMap!['fallback'], isTrue);

      final loadedList = storage.getJsonList(key, defaultValue: []);
      expect(loadedList, isEmpty);
    });

    test('Handles unexpected JSON structure type mismatch safely', () async {
      const key = 'type_mismatch';
      // Store a primitive string where a Map or List is expected
      await storage.setString(key, '"This is just a string"');

      final loadedMap = storage.getJsonMap(key, defaultValue: null);
      expect(loadedMap, isNull);

      final loadedList = storage.getJsonList(key, defaultValue: []);
      expect(loadedList, isEmpty);
    });

    test('getModelList skips corrupted items while preserving valid items', () async {
      const key = 'fav_channels_mixed';
      final mixedJson = '''
      [
        {"id": "ch1", "name": "Canal 1", "streamUrl": "http://live/1.ts"},
        "invalid_corrupted_string_item",
        {"id": "ch2", "name": "Canal 2", "streamUrl": "http://live/2.ts"}
      ]
      ''';
      await storage.setString(key, mixedJson);

      final channels = storage.getModelList<Channel>(
        key,
        (json) => Channel.fromJson(json),
      );

      expect(channels.length, equals(2));
      expect(channels[0].name, equals('Canal 1'));
      expect(channels[1].name, equals('Canal 2'));
    });
  });
}
