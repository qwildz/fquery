import 'dart:async';

/// Abstract interface for storage backends used by FQuery caches.
///
/// This allows for flexible storage solutions including in-memory,
/// persistent storage like Hive, SharedPreferences, or custom implementations.
abstract class StorageBackend<K, V> {
  /// Retrieves a value by key from storage.
  /// Returns null if the key doesn't exist.
  FutureOr<V?> get(K key);

  /// Stores a key-value pair in storage.
  FutureOr<void> set(K key, V value);

  /// Removes a key-value pair from storage.
  /// Returns true if the key existed and was removed, false otherwise.
  FutureOr<bool> remove(K key);

  /// Clears all entries from storage.
  FutureOr<void> clear();

  /// Returns all keys currently in storage.
  FutureOr<Iterable<K>> keys();

  /// Returns all values currently in storage.
  FutureOr<Iterable<V>> values();

  /// Returns all key-value pairs currently in storage.
  FutureOr<Map<K, V>> entries();

  /// Checks if a key exists in storage.
  FutureOr<bool> containsKey(K key);

  /// Returns the number of entries in storage.
  FutureOr<int> length();

  /// Optional: Initialize the storage backend.
  /// This can be used for async initialization like opening database connections.
  FutureOr<void> initialize() async {}

  /// Optional: Dispose/cleanup the storage backend.
  /// This can be used for cleanup like closing database connections.
  FutureOr<void> dispose() async {}
}

/// A serialization interface for storage backends that need to serialize complex objects.
/// This is useful for persistent storage backends like Hive or SharedPreferences.
abstract class StorageSerializer<T> {
  /// Serializes an object to a format suitable for storage (e.g., JSON, bytes).
  dynamic serialize(T object);

  /// Deserializes storage data back to the original object.
  T deserialize(dynamic data);
}
