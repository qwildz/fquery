import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fquery/fquery.dart';
import 'package:fquery/src/query_key.dart';

int useIsFetching([RawQueryKey? queryKey, bool exact = false]) {
  final client = useQueryClient();

  useListenable(client.queryCache);

  return client.isFetching(queryKey, exact);
}
