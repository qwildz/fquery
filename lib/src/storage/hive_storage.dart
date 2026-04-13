import 'dart:async';

import 'storage_backend.dart';

/// Hive-based persistent storage backend for FQuery caches.
///
/// This implementation provides persistent storage using Hive boxes.
/// To use this storage backend, you need to add the `hive` and `hive_flutter`
/// dependencies to your pubspec.yaml and initialize Hive in your app.
///
/// Example usage with existing box:
/// ```dart
/// await Hive.initFlutter();
/// final box = await Hive.openBox('fquery_cache');
/// final storage = HiveStorage<String, dynamic>(
///   boxName: 'fquery_cache',
///   hiveBox: box,
///   serializer: const SimpleJsonSerializer(),
/// );
/// await storage.initialize();
///
/// final queryClient = QueryClient(
///   queryStorage: storage,
/// );
/// ```
///
/// Example usage with Hive instance:
/// ```dart
/// await Hive.initFlutter();
/// final storage = HiveStorage<String, dynamic>(
///   boxName: 'fquery_cache',
///   hive: Hive,
///   serializer: const SimpleJsonSerializer(),
/// );
/// await storage.initialize();
/// ```
///
/// Example with custom model:
/// ```dart
/// final storage = HiveStorage<String, User>(
///   boxName: 'user_cache',
///   hive: Hive,
///   serializer: JsonStorageSerializer<User>(
///     fromJson: User.fromJson,
///     toJson: (user) => user.toJson(),
///   ),
/// );
/// ```
class HiveStorage<K, V> implements StorageBackend<K, V> {
  final String? boxName;
  final StorageSerializer<V>? serializer;
  final dynamic hiveBox; // Pass Hive box directly to avoid dependency issues
  final dynamic hive; // Pass Hive instance to manage box lifecycle
  bool _isInitialized = false;
  dynamic _managedBox; // Box opened by this storage instance

  /// Lock to serialize Hive operations and prevent concurrent access
  /// that causes RangeError in Hive's internal IndexableSkipList.
  final _lock = _AsyncLock();

  HiveStorage({
    this.boxName,
    this.hiveBox,
    this.hive,
    this.serializer,
  }) : assert(
          hiveBox != null || (hive != null && boxName != null),
          'Either hiveBox or hive must be provided',
        );

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    // If we have a Hive instance but no box, open the box
    if (hive != null && hiveBox == null) {
      try {
        _managedBox = await hive.openBox<dynamic>(boxName);
      } catch (e) {
        throw Exception(
            'Failed to open Hive box "$boxName". Make sure Hive is properly initialized. Error: $e');
      }
    }

    _isInitialized = true;
  }

  @override
  Future<void> dispose() async {
    // Only close the box if we opened it (managed box)
    if (_managedBox != null) {
      await _managedBox.close();
      _managedBox = null;
    }
    // Don't close externally provided boxes
    _isInitialized = false;
  }

  /// Get the active box (either provided or managed)
  dynamic get _activeBox => hiveBox ?? _managedBox;

  @override
  Future<V?> get(K key) => _lock.synchronized(() async {
        _ensureInitialized();
        final value = await _activeBox.get(key);
        if (value == null) return null;

        if (serializer != null) {
          return serializer!.deserialize(value);
        }
        return value as V?;
      });

  @override
  Future<void> set(K key, V value) => _lock.synchronized(() async {
        _ensureInitialized();
        final serializedValue = serializer?.serialize(value) ?? value;
        await _activeBox.put(key, serializedValue);
      });

  @override
  Future<bool> remove(K key) => _lock.synchronized(() async {
        _ensureInitialized();
        final existed = await _activeBox.containsKey(key);
        await _activeBox.delete(key);
        return existed;
      });

  @override
  Future<void> clear() => _lock.synchronized(() async {
        _ensureInitialized();
        await _activeBox.clear();
      });

  @override
  Future<Iterable<K>> keys() => _lock.synchronized(() async {
        _ensureInitialized();
        // Take a snapshot of keys to avoid index shifting during iteration.
        return List<K>.from(_activeBox.keys.cast<K>());
      });

  @override
  Future<Iterable<V>> values() => _lock.synchronized(() async {
        _ensureInitialized();
        final values = _activeBox.values;
        if (serializer != null) {
          return List<V>.from(
              values.map((value) => serializer!.deserialize(value)).cast<V>());
        }
        return List<V>.from(values.cast<V>());
      });

  @override
  Future<Map<K, V>> entries() => _lock.synchronized(() async {
        _ensureInitialized();
        // Snapshot keys and read values inside the same lock to prevent
        // concurrent modifications from shifting Hive's internal index.
        final result = <K, V>{};
        final keySnapshot = List<K>.from(_activeBox.keys.cast<K>());
        for (final key in keySnapshot) {
          final value = await _activeBox.get(key);
          if (value != null) {
            final deserialized = serializer != null
                ? serializer!.deserialize(value)
                : value as V;
            result[key] = deserialized;
          }
        }
        return result;
      });

  @override
  Future<bool> containsKey(K key) => _lock.synchronized(() async {
        _ensureInitialized();
        return _activeBox.containsKey(key);
      });

  @override
  Future<int> length() => _lock.synchronized(() async {
        _ensureInitialized();
        return _activeBox.length;
      });

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
          'HiveStorage not initialized. Call initialize() before using the storage.');
    }

    if (_activeBox == null) {
      throw StateError(
          'No Hive box available. Make sure to provide either hiveBox or hive instance.');
    }
  }
}

/// JSON serializer for use with HiveStorage.
/// This serializer converts objects to/from JSON format for storage.
class JsonStorageSerializer<T> implements StorageSerializer<T> {
  final T Function(dynamic) fromJson;
  final dynamic Function(T) toJson;

  const JsonStorageSerializer({
    required this.fromJson,
    required this.toJson,
  });

  @override
  dynamic serialize(T object) => toJson(object);

  @override
  T deserialize(dynamic data) {
    return fromJson(data);
  }
}

/// Simple async mutex to serialize access to a Hive box.
///
/// Hive's internal IndexableSkipList is not safe for concurrent
/// read-while-write; interleaved operations can shift indices and
/// cause [RangeError]. This lock ensures only one operation runs
/// against the box at a time.
class _AsyncLock {
  Future<void> _last = Future.value();

  Future<T> synchronized<T>(Future<T> Function() action) {
    final prev = _last;
    // Chain the new action after the previous one completes (or fails).
    final completer = Completer<void>();
    _last = completer.future;

    return prev.then((_) => action()).whenComplete(completer.complete);
  }
}
