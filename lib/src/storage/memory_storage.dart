import 'storage_backend.dart';

/// In-memory storage backend that uses a Map for storage.
/// This is the default storage backend and provides the same behavior
/// as the original FQuery implementation.
class MemoryStorage<K, V> implements StorageBackend<K, V> {
  final Map<K, V> _storage = <K, V>{};

  @override
  V? get(K key) => _storage[key];

  @override
  void set(K key, V value) => _storage[key] = value;

  @override
  bool remove(K key) => _storage.remove(key) != null;

  @override
  void clear() => _storage.clear();

  @override
  Iterable<K> keys() => _storage.keys;

  @override
  Iterable<V> values() => _storage.values;

  @override
  Map<K, V> entries() => Map<K, V>.from(_storage);

  @override
  bool containsKey(K key) => _storage.containsKey(key);

  @override
  int length() => _storage.length;

  @override
  void initialize() {}

  @override
  void dispose() {}
}
