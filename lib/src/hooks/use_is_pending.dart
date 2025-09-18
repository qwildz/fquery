import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fquery/fquery.dart';
import 'package:fquery/src/query_key.dart';

int useIsPending([RawQueryKey? queryKey]) {
  final client = useQueryClient();
  final result = useState(0);

  useListenable(client.mutationCache);

  WidgetsBinding.instance.addPostFrameCallback((_) {
    result.value = client.isPending(queryKey);
  });

  return result.value;
}
