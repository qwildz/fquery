import 'package:flutter/widgets.dart';
import 'package:fquery/src/mutation_observer.dart';
import 'package:fquery/src/storage/storage_backend.dart';

typedef MutationsMap = Map<int, MutationObserver>;

class MutationCache extends ChangeNotifier {
  final MutationsMap _mutations = {};
  final StorageBackend<String, dynamic>? _storage;
  final StorageSerializer<dynamic>? _serializer;

  MutationsMap get mutations => _mutations;
  int _nextId = 0;

  MutationCache({
    StorageBackend<String, dynamic>? storage,
    StorageSerializer<dynamic>? serializer,
  })  : _storage = storage,
        _serializer = serializer;

  /// Initialize the storage backend if provided.
  Future<void> initialize() async {
    await _storage?.initialize();
  }

  /// Dispose the storage backend if provided.
  Future<void> dispose() async {
    await _storage?.dispose();
    super.dispose();
  }

  /// Adds a mutation observer to the cache and returns its ID
  int add(MutationObserver observer) {
    final id = _nextId++;
    _mutations[id] = observer;

    // Optionally store mutation state for persistence
    // Note: Mutations are typically transient, but this allows for
    // storing pending mutations across app restarts
    _storeMutationToStorage(id, observer);

    onMutationUpdated();
    return id;
  }

  void remove(int id) {
    _mutations.remove(id);

    // Remove from persistent storage if available
    _removeMutationFromStorage(id);

    onMutationUpdated();
  }

  /// Store mutation data to storage if available.
  /// Note: This is optional as mutations are typically transient.
  Future<void> _storeMutationToStorage(
      int id, MutationObserver observer) async {
    if (_storage == null) return;

    try {
      final serializedData = <String, dynamic>{
        'id': id,
        'isPending': observer.mutation.state.isPending,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      };

      await _storage!.set('mutation_$id', serializedData);
    } catch (e) {
      // Handle storage errors gracefully
      debugPrint('Failed to store mutation cache: $e');
    }
  }

  /// Remove mutation data from storage if available.
  Future<void> _removeMutationFromStorage(int id) async {
    if (_storage == null) return;

    try {
      await _storage!.remove('mutation_$id');
    } catch (e) {
      // Handle storage errors gracefully
      debugPrint('Failed to remove mutation cache from storage: $e');
    }
  }

  void onMutationUpdated() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }
}
