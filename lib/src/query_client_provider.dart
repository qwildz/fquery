import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fquery/fquery.dart';

class _LifecycleObserver extends WidgetsBindingObserver {
  final QueryClient client;
  _LifecycleObserver(this.client);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      client.onFocus();
    }
  }
}

class ChildWidgetWrapper extends HookWidget {
  final Widget child;
  const ChildWidgetWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final client = useQueryClient();

    // Garbage collection cleanup on unmount
    useEffect(() {
      return () {
        for (var entry in client.queryCache.queries.entries) {
          final query = entry.value;
          query.cancelGarbageCollection();
        }
      };
    }, []);

    // App focus (lifecycle) detection
    useEffect(() {
      final observer = _LifecycleObserver(client);
      WidgetsBinding.instance.addObserver(observer);
      return () => WidgetsBinding.instance.removeObserver(observer);
    }, [client]);

    // Network reconnect detection
    useEffect(() {
      List<ConnectivityResult>? previousResult;
      StreamSubscription<List<ConnectivityResult>>? subscription;
      subscription = Connectivity().onConnectivityChanged.listen((results) {
        final wasDisconnected = previousResult == null ||
            previousResult!.every((r) => r == ConnectivityResult.none);
        final isConnected = results.any((r) => r != ConnectivityResult.none);
        if (wasDisconnected && isConnected) {
          client.onReconnect();
        }
        previousResult = results;
      });
      return () => subscription?.cancel();
    }, [client]);

    return child;
  }
}

/// This can be used to provide a [QueryClient] throughout the application.
class QueryClientProvider extends InheritedWidget {
  final QueryClient queryClient;
  QueryClientProvider({
    super.key,
    required this.queryClient,
    required Widget child,
  }) : super(child: ChildWidgetWrapper(child: child));

  @override
  bool updateShouldNotify(InheritedWidget oldWidget) => oldWidget != this;

  static QueryClientProvider of(BuildContext context) {
    final QueryClientProvider? result =
        context.dependOnInheritedWidgetOfExactType<QueryClientProvider>();
    assert(result != null, 'QueryClientProvider not found');
    return result!;
  }
}
