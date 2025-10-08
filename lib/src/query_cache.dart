import 'package:flutter/widgets.dart';
import 'package:fquery/src/query.dart';
import 'package:fquery/src/query_client.dart';
import 'package:fquery/src/query_key.dart';
import 'package:fquery/src/storage/storage_backend.dart';

typedef QueriesMap = Map<QueryKey, Query>;

class QueryCache extends ChangeNotifier {
  final QueriesMap _queries = {};
  final StorageBackend<String, dynamic>? _storage;
  final StorageSerializer<dynamic>? _serializer;

  QueriesMap get queries => _queries;

  QueryCache({
    StorageBackend<String, dynamic>? storage,
    StorageSerializer<dynamic>? serializer,
  })  : _storage = storage,
        _serializer = serializer;

  /// Initialize the storage backend if provided.
  Future<void> initialize() async {
    await _storage?.initialize();

    // Load cached data from storage if available
    if (_storage != null) {
      await _loadFromStorage();
    }
  }

  /// Dispose the storage backend if provided.
  Future<void> dispose() async {
    await _storage?.dispose();
    super.dispose();
  }

  /// Load cached query data from storage.
  Future<void> _loadFromStorage() async {
    if (_storage == null) return;

    try {
      final entries = await _storage!.entries();
      // For now, just track that we have storage available
      // The actual loading will happen when queries are requested
      debugPrint('Loaded ${entries.length} cached queries from storage');
    } catch (e) {
      // Handle storage loading errors gracefully
      debugPrint('Failed to load query cache from storage: $e');
    }
  }

  /// Store query data to storage if available.
  Future<void> _storeToStorage(QueryKey queryKey, Query query) async {
    if (_storage == null || query.state.data == null) return;

    try {
      final serializedData = <String, dynamic>{
        'data': _serializer?.serialize(query.state.data) ?? query.state.data,
        'dataUpdatedAt': query.state.dataUpdatedAt?.millisecondsSinceEpoch,
        'status': query.state.status.name,
      };

      await _storage!.set(queryKey.serialized, serializedData);
    } catch (e) {
      // Handle storage errors gracefully
      debugPrint('Failed to store query cache: $e');
    }
  }

  /// Remove query data from storage if available.
  Future<void> _removeFromStorage(QueryKey queryKey) async {
    if (_storage == null) return;

    try {
      await _storage!.remove(queryKey.serialized);
    } catch (e) {
      // Handle storage errors gracefully
      debugPrint('Failed to remove query cache from storage: $e');
    }
  }

  Query<TData, TError> get<TData, TError>(QueryKey queryKey) {
    final query = _queries[queryKey];
    if (query == null) {
      throw ArgumentError("Query with given key doesn't exist.");
    }
    return query as Query<TData, TError>;
  }

  void add(QueryKey queryKey, Query query) {
    _queries[queryKey] = query;
    // Store to persistent storage if available
    _storeToStorage(queryKey, query);
    onQueryUpdated();
  }

  void remove(Query query) {
    final keyToRemove = _queries.entries
        .where((entry) => entry.value == query)
        .map((entry) => entry.key)
        .firstOrNull;

    if (keyToRemove != null) {
      _queries.removeWhere((key, value) => value == query);
      // Remove from persistent storage if available
      _removeFromStorage(keyToRemove);
    }
    onQueryUpdated();
  }

  /// Returns a query identified by the query key.
  /// If it doesn't exist already,
  /// creates a new one and adds it to the cache.
  Query<TData, TError> build<TData, TError>({
    required QueryKey queryKey,
    required QueryClient client,
  }) {
    late final Query<TData, TError> query;
    try {
      query = get<TData, TError>(queryKey);
      add(queryKey, query);
    } catch (e) {
      query = Query(client: client, key: queryKey);
      add(queryKey, query);

      // Try to load data from storage if available
      _loadQueryFromStorage(queryKey, query);
    }
    return query;
  }

  /// Load specific query data from storage if available.
  Future<void> _loadQueryFromStorage(QueryKey queryKey, Query query) async {
    if (_storage == null) return;

    try {
      final storedData = await _storage!.get(queryKey.serialized);
      if (storedData != null) {
        final data =
            _serializer?.deserialize(storedData['data']) ?? storedData['data'];
        final dataUpdatedAt = storedData['dataUpdatedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(storedData['dataUpdatedAt'])
            : null;

        // If we have valid cached data, initialize the query with it
        if (data != null && dataUpdatedAt != null) {
          // Only load if the cached data is still fresh enough
          final now = DateTime.now();
          final age = now.difference(dataUpdatedAt);

          // Use a reasonable cache duration (can be made configurable)
          const maxCacheAge = Duration(minutes: 5);

          if (age <= maxCacheAge) {
            query.dispatch(DispatchAction.success, data);
          }
        }
      }
    } catch (e) {
      // Handle storage loading errors gracefully
      debugPrint('Failed to load query from storage: $e');
    }
  }

  void onQueryUpdated() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }
}
