import 'package:flutter/widgets.dart';
import 'package:fquery/src/mutation_observer.dart';

typedef MutationsMap = Map<int, MutationObserver>;

class MutationCache extends ChangeNotifier {
  final MutationsMap _mutations = {};
  MutationsMap get mutations => _mutations;
  int _nextId = 0;

  /// Adds a mutation observer to the cache and returns its ID
  int add(MutationObserver observer) {
    final id = _nextId++;
    _mutations[id] = observer;
    onMutationUpdated();
    return id;
  }

  void remove(int id) {
    _mutations.remove(id);
    onMutationUpdated();
  }

  void onMutationUpdated() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }
}
