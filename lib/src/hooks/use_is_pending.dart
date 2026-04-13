import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fquery/fquery.dart';
import 'package:fquery/src/query_key.dart';

int useIsPending([RawQueryKey? queryKey]) {
  final client = useQueryClient();

  useListenable(client.mutationCache);

  return client.isPending(queryKey);
}
