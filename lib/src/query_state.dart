import 'package:flutter/foundation.dart';
import 'package:fquery/src/query.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'query_state.freezed.dart';

@freezed
class QueryState<TData, TError> with _$QueryState<TData, TError> {
  const QueryState._();

  bool get isLoading => status == QueryStatus.loading;
  bool get isSuccess => status == QueryStatus.success;
  bool get isError => status == QueryStatus.error;
  bool get hasData => data != null;

  /// Determines if the data is stale based on staleDuration.
  /// This requires the staleDuration to be passed from the observer/query options.
  /// Returns true if data exists but is older than the stale duration.
  bool isStale(Duration staleDuration) {
    if (dataUpdatedAt == null) return false;
    final staleAt = dataUpdatedAt!.add(staleDuration);
    return staleAt.isBefore(DateTime.now());
  }

  const factory QueryState({
    TData? data,
    TError? error,
    DateTime? dataUpdatedAt,
    DateTime? errorUpdatedAt,
    @Default(false) bool isFetching,
    @Default(QueryStatus.loading) QueryStatus status,
    @Default(false) bool isInvalidated,
    FetchMeta? fetchMeta,
    @Default(false) bool isRefetchError,
  }) = _QueryState<TData, TError>;
}
