import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fquery/fquery.dart';
import 'package:fquery/src/observer.dart';
import 'package:fquery/src/query_key.dart';

class UseLazyQueryResult<TData, TError> {
  final TData? data;
  final DateTime? dataUpdatedAt;
  final TError? error;
  final DateTime? errorUpdatedAt;
  final bool isError;
  final bool isLoading;
  final bool isFetching;
  final bool isSuccess;
  final bool hasData;
  final bool isStale;
  final QueryStatus status;
  final Future<void> Function() refetch;
  final bool isInvalidated;
  final bool isRefetchError;
  final Future<void> Function() execute;
  final bool called;

  UseLazyQueryResult({
    required this.data,
    required this.dataUpdatedAt,
    required this.error,
    required this.errorUpdatedAt,
    required this.isError,
    required this.isLoading,
    required this.isFetching,
    required this.isSuccess,
    required this.hasData,
    required this.isStale,
    required this.status,
    required this.refetch,
    required this.isInvalidated,
    required this.isRefetchError,
    required this.execute,
    required this.called,
  });
}

class UseLazyQueryOptions<TData, TError> {
  final RefetchOnMount? refetchOnMount;
  final Duration? staleDuration;
  final Duration? cacheDuration;
  final Duration? refetchInterval;
  final int? retryCount;
  final Duration? retryDelay;
  final dynamic Function(dynamic dataFromStorage)? dataFromStorage;

  UseLazyQueryOptions({
    this.refetchOnMount,
    this.staleDuration,
    this.cacheDuration,
    this.refetchInterval,
    this.retryCount,
    this.retryDelay,
    this.dataFromStorage,
  });
}

/// A lazy version of [useQuery] that doesn't automatically fetch data on mount.
/// Instead, it returns an `execute` function to manually trigger the query.
///
/// This is useful for queries that should only be executed in response to user actions,
/// such as form submissions or button clicks.
///
/// Example:
/// ```dart
/// final lazyPosts = useLazyQuery(
///   ['posts', userId],
///   () => getPosts(userId),
///   cacheDuration: const Duration(minutes: 5),
///   staleDuration: const Duration(seconds: 10),
/// );
///
/// // In your widget:
/// ElevatedButton(
///   onPressed: lazyPosts.execute,
///   child: Text('Load Posts'),
/// )
///
/// if (lazyPosts.isLoading) {
///   return CircularProgressIndicator();
/// }
///
/// if (lazyPosts.isSuccess && lazyPosts.data != null) {
///   return ListView.builder(...);
/// }
/// ```
///
/// - `cacheDuration` - specifies the duration unused/inactive cache data remains in memory
/// - `refetchInterval` - specifies the time interval for automatic refetching (null to disable)
/// - `refetchOnMount` - behavior when widget mounts and data exists (defaults to never for lazy queries)
/// - `staleDuration` - duration until data becomes stale
/// - `retryCount` - number of retry attempts on failure
/// - `retryDelay` - delay between retry attempts
UseLazyQueryResult<TData, TError> useLazyQuery<TData, TError>(
  RawQueryKey queryKey,
  QueryFn<TData> fetcher, {
  RefetchOnMount? refetchOnMount,
  Duration? staleDuration,
  Duration? cacheDuration,
  Duration? refetchInterval,
  int? retryCount,
  Duration? retryDelay,
  dynamic Function(dynamic dataFromStorage)? dataFromStorage,
}) {
  final called = useState(false);

  final options = useMemoized(
    () => UseLazyQueryOptions<TData, TError>(
      refetchOnMount: refetchOnMount,
      staleDuration: staleDuration,
      cacheDuration: cacheDuration,
      refetchInterval: refetchInterval,
      retryCount: retryCount,
      retryDelay: retryDelay,
      dataFromStorage: dataFromStorage,
    ),
    [
      refetchOnMount,
      staleDuration,
      cacheDuration,
      refetchInterval,
      retryCount,
      retryDelay,
      dataFromStorage,
    ],
  );

  final client = useQueryClient();

  final observerRef = useRef<Observer<TData, TError>?>(null);
  useEffect(() {
    // Create observer with enabled: false initially
    observerRef.value = Observer(
      QueryKey(queryKey),
      fetcher,
      client: client,
      options: UseQueryOptions<TData, TError>(
        enabled: false, // Key difference: start with enabled: false
        refetchOnMount: options.refetchOnMount ?? RefetchOnMount.never,
        staleDuration: options.staleDuration,
        cacheDuration: options.cacheDuration,
        refetchInterval: options.refetchInterval,
        retryCount: options.retryCount,
        retryDelay: options.retryDelay,
        dataFromStorage: options.dataFromStorage,
      ),
    );
    return;
  }, [QueryKey(queryKey)]);

  // Rebuild observer if the query is changed somehow,
  // typically when the query is removed from the cache.
  final query = useListenableSelector(
    client.queryCache,
    () => client.queryCache.queries[QueryKey(queryKey)],
  );
  useEffect(() {
    if (query == null) {
      observerRef.value = Observer(
        QueryKey(queryKey),
        fetcher,
        client: client,
        options: UseQueryOptions<TData, TError>(
          enabled: false, // Keep disabled until explicitly called
          refetchOnMount: options.refetchOnMount ?? RefetchOnMount.never,
          staleDuration: options.staleDuration,
          cacheDuration: options.cacheDuration,
          refetchInterval: options.refetchInterval,
          retryCount: options.retryCount,
          retryDelay: options.retryDelay,
          dataFromStorage: options.dataFromStorage,
        ),
      );
    }
    return;
  }, [query]);

  final observer = observerRef.value as Observer<TData, TError>;

  // This subscribes to the observer
  // and rebuilds the widgets on updates.
  useListenable<Observer<TData, TError>>(observer);

  useEffect(() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      observer.updateOptions(UseQueryOptions<TData, TError>(
        enabled: called.value, // Enable based on whether execute was called
        refetchOnMount: options.refetchOnMount ?? RefetchOnMount.never,
        staleDuration: options.staleDuration,
        cacheDuration: options.cacheDuration,
        refetchInterval: options.refetchInterval,
        retryCount: options.retryCount,
        retryDelay: options.retryDelay,
        dataFromStorage: options.dataFromStorage,
      ));
    });
    return;
  }, [observer, options, called.value]);

  useEffect(() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      observer.initialize();
    });
    return () {
      observer.destroy();
    };
  }, [observer]);

  // Execute function to manually trigger the query
  final execute = useCallback(() async {
    called.value = true;
    // Update options to enable the query
    observer.updateOptions(UseQueryOptions<TData, TError>(
      enabled: true,
      refetchOnMount: options.refetchOnMount ?? RefetchOnMount.never,
      staleDuration: options.staleDuration,
      cacheDuration: options.cacheDuration,
      refetchInterval: options.refetchInterval,
      retryCount: options.retryCount,
      retryDelay: options.retryDelay,
      dataFromStorage: options.dataFromStorage,
    ));
    return observer.fetch();
  }, [observer, options]);

  return UseLazyQueryResult<TData, TError>(
    data: observer.query.state.data,
    dataUpdatedAt: observer.query.state.dataUpdatedAt,
    error: observer.query.state.error,
    errorUpdatedAt: observer.query.state.errorUpdatedAt,
    isError: observer.query.state.isError,
    isLoading: observer.query.state.isLoading,
    isFetching: observer.query.state.isFetching,
    isSuccess: observer.query.state.isSuccess,
    hasData: observer.query.state.hasData,
    isStale: observer.query.state.isStale(
      options.staleDuration ??
          observer.client.defaultQueryOptions.staleDuration,
    ),
    status: observer.query.state.status,
    refetch: observer.fetch,
    isInvalidated: observer.query.state.isInvalidated,
    isRefetchError: observer.query.state.isRefetchError,
    execute: execute,
    called: called.value,
  );
}
