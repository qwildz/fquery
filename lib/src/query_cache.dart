import 'package:flutter/widgets.dart';
import 'package:fquery/src/query.dart';
import 'package:fquery/src/query_client.dart';
import 'package:fquery/src/query_key.dart';
import 'package:fquery/src/storage/storage_backend.dart';

typedef QueriesMap = Map<QueryKey, Query>;

class QueryCache extends ChangeNotifier {
  final QueriesMap _queries = {};
  final StorageBackend<String, dynamic>? _storage;

  QueriesMap get queries => _queries;

  QueryCache({
    StorageBackend<String, dynamic>? storage,
  }) : _storage = storage;

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
  /// Only stores for queries that have dataFromStorage callback enabled.
  ///
  /// Data is stored as dynamic object for user to handle with their dataFromStorage callback.
  /// This supports Hive TypeAdapters and other serialization methods.
  ///
  /// Example usage:
  /// ```dart
  /// final posts = useQuery<List<Post>, Error>(
  ///   ['posts'],
  ///   fetchPosts,
  ///   dataFromStorage: (data) {
  ///     // data is the raw dynamic object from storage
  ///     // For Hive: data is already the correct type
  ///     // For JSON: data might be List<dynamic> that needs mapping
  ///     if (data is List) {
  ///       return data.map((e) => Post.fromJson(e)).toList();
  ///     }
  ///     return data as List<Post>;
  ///   },
  /// );
  /// ```
  Future<void> storeToStorage(QueryKey queryKey, Query query) async {
    debugPrint(
        'Attempting to store query ${queryKey.serialized} to storage with data: ${query.state.data}');

    if (_storage == null || query.state.data == null) return;

    try {
      debugPrint(
          'Storing cached query ${queryKey.serialized} to storage with data: ${query.state.data}');

      final serializedData = <String, dynamic>{
        'data': query.state.data, // Store as dynamic instead of JSON encoding
        'dataUpdatedAt': query.state.dataUpdatedAt?.millisecondsSinceEpoch,
        'status': query.state.status.name,
      };

      debugPrint('Storing cached query ${queryKey.serialized} to storage');
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
      debugPrint('Removing cached query ${queryKey.serialized} from storage');
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
    onQueryUpdated();
  }

  Future<void> remove(Query query) async {
    _queries.removeWhere((key, value) => value == query);
    await _removeFromStorage(query.key);
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
      // Note: Storage loading is now handled by Observer after setup
    }
    return query;
  }

  /// Try to load data from storage for a query with dataFromStorage callback.
  /// Called by Observer after setup is complete.
  /// Returns true if data was successfully loaded from storage, false otherwise.
  Future<bool> tryLoadFromStorage<TData>(QueryKey queryKey, Query query,
      dynamic Function(dynamic dataFromStorage) dataFromStorageCallback) async {
    if (_storage == null) return false;

    debugPrint('Loading cached query ${queryKey.serialized} from storage');

    try {
      final storedData = await _storage!.get(queryKey.serialized);

      debugPrint(
          'Retrieved data for query ${queryKey.serialized} from storage: $storedData');

      if (storedData != null) {
        final dataUpdatedAt = storedData['dataUpdatedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(storedData['dataUpdatedAt'])
            : null;

        debugPrint(
            'Cached data for query ${queryKey.serialized} found in storage, dataUpdatedAt: $dataUpdatedAt');

        // If we have valid cached data, check if it's still fresh
        if (dataUpdatedAt != null) {
          debugPrint(
              'Restoring cached data for query ${queryKey.serialized} from storage');

          // Only load if the cached data is still fresh enough
          final now = DateTime.now();
          final age = now.difference(dataUpdatedAt);

          // Use the query's configured cache duration or fallback to default
          final maxCacheAge = query.cacheDuration ??
              query.client.defaultQueryOptions.cacheDuration;

          debugPrint(
              'Checking if cached data for query ${queryKey.serialized} is still fresh, age: $age, maxCacheAge: $maxCacheAge');
          if (age <= maxCacheAge) {
            debugPrint(
                'Loaded cached data for query ${queryKey.serialized} from storage');

            // Call user's dataFromStorage callback with the dynamic data
            final rawData = storedData['data'];
            final parsedData = dataFromStorageCallback(rawData);
            query.dispatch(DispatchAction.success, parsedData,
                fromStorage: true);
            return true; // Successfully loaded from storage
          } else {
            debugPrint(
                'Cached data for query ${queryKey.serialized} is too old, age: $age > maxCacheAge: $maxCacheAge');
          }
        }
      }
    } catch (e) {
      // Handle storage loading errors gracefully
      debugPrint(
          'Failed to load query ${queryKey.serialized} from storage: $e');
    }
    return false; // Failed to load from storage
  }

  void onQueryUpdated() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }
}
