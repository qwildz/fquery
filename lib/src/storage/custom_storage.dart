import 'dart:async';

import 'storage_backend.dart';

/// A base class for creating custom storage backends.
///
/// This provides a foundation for implementing custom storage solutions
/// such as database storage, cloud storage, or any other persistence mechanism.
///
/// Example usage:
/// ```dart
/// class DatabaseStorage extends CustomStorage<String, Map<String, dynamic>> {
///   final Database database;
///
///   DatabaseStorage(this.database);
///
///   @override
///   Future<Map<String, dynamic>?> get(String key) async {
///     final result = await database.query('cache', where: 'key = ?', whereArgs: [key]);
///     if (result.isNotEmpty) {
///       return Map<String, dynamic>.from(result.first);
///     }
///     return null;
///   }
///
///   @override
///   Future<void> set(String key, Map<String, dynamic> value) async {
///     await database.insert('cache', {'key': key, ...value},
///       conflictAlgorithm: ConflictAlgorithm.replace);
///   }
///
///   // ... implement other methods
/// }
/// ```
abstract class CustomStorage<K, V> implements StorageBackend<K, V> {
  bool _isInitialized = false;

  /// Whether the storage has been initialized.
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    await onInitialize();
    _isInitialized = true;
  }

  @override
  Future<void> dispose() async {
    if (!_isInitialized) return;
    await onDispose();
    _isInitialized = false;
  }

  /// Override this method to perform custom initialization logic.
  /// This method is called once when initialize() is first called.
  Future<void> onInitialize() async {}

  /// Override this method to perform custom cleanup logic.
  /// This method is called when dispose() is called.
  Future<void> onDispose() async {}

  /// Ensures the storage is initialized before operations.
  void ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
          'CustomStorage not initialized. Call initialize() before using the storage.');
    }
  }

  // Abstract methods that must be implemented by subclasses
  @override
  FutureOr<V?> get(K key);

  @override
  FutureOr<void> set(K key, V value);

  @override
  FutureOr<bool> remove(K key);

  @override
  FutureOr<void> clear();

  @override
  FutureOr<Iterable<K>> keys();

  @override
  FutureOr<Iterable<V>> values();

  @override
  FutureOr<Map<K, V>> entries();

  @override
  FutureOr<bool> containsKey(K key);

  @override
  FutureOr<int> length();
}

/// Example implementation of CustomStorage using SharedPreferences.
/// This serves as a reference for how to implement custom storage backends.
///
/// To use this, add shared_preferences dependency to your pubspec.yaml.
class SharedPreferencesStorage extends CustomStorage<String, String> {
  dynamic _prefs; // SharedPreferences instance

  SharedPreferencesStorage();

  @override
  Future<void> onInitialize() async {
    try {
      // Note: This requires shared_preferences package
      // _prefs = await SharedPreferences.getInstance();
      throw UnimplementedError(
          'SharedPreferencesStorage requires shared_preferences package. '
          'Add shared_preferences to your dependencies and uncomment the implementation.');
    } catch (e) {
      throw Exception(
          'Failed to initialize SharedPreferencesStorage. Make sure you have added '
          'shared_preferences dependency. Error: $e');
    }
  }

  @override
  Future<String?> get(String key) async {
    ensureInitialized();
    return _prefs?.getString(key);
  }

  @override
  Future<void> set(String key, String value) async {
    ensureInitialized();
    await _prefs?.setString(key, value);
  }

  @override
  Future<bool> remove(String key) async {
    ensureInitialized();
    return await _prefs?.remove(key) ?? false;
  }

  @override
  Future<void> clear() async {
    ensureInitialized();
    await _prefs?.clear();
  }

  @override
  Future<Iterable<String>> keys() async {
    ensureInitialized();
    return _prefs?.getKeys() ?? <String>[];
  }

  @override
  Future<Iterable<String>> values() async {
    ensureInitialized();
    final keyList = await keys();
    final values = <String>[];
    for (final key in keyList) {
      final value = await get(key);
      if (value != null) {
        values.add(value);
      }
    }
    return values;
  }

  @override
  Future<Map<String, String>> entries() async {
    ensureInitialized();
    final result = <String, String>{};
    for (final key in await keys()) {
      final value = await get(key);
      if (value != null) {
        result[key] = value;
      }
    }
    return result;
  }

  @override
  Future<bool> containsKey(String key) async {
    ensureInitialized();
    return _prefs?.containsKey(key) ?? false;
  }

  @override
  Future<int> length() async {
    ensureInitialized();
    final keyList = await keys();
    return keyList.length;
  }
}
