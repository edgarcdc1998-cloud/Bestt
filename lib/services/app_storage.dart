import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'storage_service.dart';

class AppStorage implements StorageService {
  final SharedPreferences _prefs;

  AppStorage(this._prefs);

  static Future<AppStorage> getInstance() async {
    final prefs = await SharedPreferences.getInstance();
    return AppStorage(prefs);
  }

  @override
  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  @override
  String? getString(String key) {
    return _prefs.getString(key);
  }

  @override
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  @override
  Future<void> clear() async {
    await _prefs.clear();
  }

  @override
  bool containsKey(String key) {
    return _prefs.containsKey(key);
  }

  // --- Defensive JSON Helpers (P0-3 Stabilization) ---

  /// Safely saves a JSON serializable object.
  Future<bool> setJson(String key, dynamic value) async {
    try {
      final jsonString = json.encode(value);
      return await _prefs.setString(key, jsonString);
    } catch (e, stack) {
      debugPrint('[AppStorage] Error serializing JSON for key "$key": $e\n$stack');
      return false;
    }
  }

  /// Safely decodes a JSON Map object with fallback default on malformed/corrupted data.
  Map<String, dynamic>? getJsonMap(String key, {Map<String, dynamic>? defaultValue}) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) {
      return defaultValue;
    }
    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      } else if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      } else {
        debugPrint('[AppStorage] Unexpected JSON structure for key "$key", expected Map, got ${decoded.runtimeType}');
        return defaultValue;
      }
    } catch (e) {
      debugPrint('[AppStorage] Corrupted JSON data detected for key "$key": $e');
      return defaultValue;
    }
  }

  /// Safely decodes a JSON List with fallback default and per-item resilience.
  List<dynamic> getJsonList(String key, {List<dynamic> defaultValue = const []}) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) {
      return defaultValue;
    }
    try {
      final decoded = json.decode(raw);
      if (decoded is List) {
        return decoded;
      } else {
        debugPrint('[AppStorage] Unexpected JSON structure for key "$key", expected List, got ${decoded.runtimeType}');
        return defaultValue;
      }
    } catch (e) {
      debugPrint('[AppStorage] Corrupted JSON list detected for key "$key": $e');
      return defaultValue;
    }
  }

  /// Safely decodes a List of Models with item-by-item fault tolerance.
  List<T> getModelList<T>(
    String key,
    T Function(Map<String, dynamic> json) fromJson, {
    List<T> defaultValue = const [],
  }) {
    final rawList = getJsonList(key, defaultValue: []);
    if (rawList.isEmpty) return defaultValue;

    final results = <T>[];
    for (int i = 0; i < rawList.length; i++) {
      final item = rawList[i];
      try {
        if (item is Map<String, dynamic>) {
          results.add(fromJson(item));
        } else if (item is Map) {
          results.add(fromJson(Map<String, dynamic>.from(item)));
        } else {
          debugPrint('[AppStorage] Skipping invalid list entry at index $i for key "$key" (not a map)');
        }
      } catch (e) {
        debugPrint('[AppStorage] Skipping corrupted item at index $i for key "$key": $e');
      }
    }
    return results;
  }
}
