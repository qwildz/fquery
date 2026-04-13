import 'dart:async';

/// Default cache duration used when no observer specifies one.
const _defaultCacheDuration = Duration(minutes: 5);

mixin Removable {
  Duration? _cacheDuration;
  Timer? _garbageCollectionTimer;

  /// Gets the current cache duration
  Duration? get cacheDuration => _cacheDuration;

  /// Sets the cache duration and reschedules the garbage collection timer.
  /// The most recently set value is used (allows dynamic durations to update).
  void setCacheDuration(Duration cacheDuration) {
    _cacheDuration = cacheDuration;
    scheduleGarbageCollection();
  }

  /// This is called when garbage collection timer fires
  //  Defined by the child class
  void onGarbageCollection() {}

  void scheduleGarbageCollection() {
    _garbageCollectionTimer?.cancel();
    final duration = _cacheDuration ?? _defaultCacheDuration;
    _garbageCollectionTimer = Timer(duration, onGarbageCollection);
  }

  void cancelGarbageCollection() {
    _garbageCollectionTimer?.cancel();
    _garbageCollectionTimer = null;
  }
}
