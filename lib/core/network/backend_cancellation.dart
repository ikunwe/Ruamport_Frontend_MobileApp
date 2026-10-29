import 'dart:async';

class BackendCancelled implements Exception {
  const BackendCancelled();
}

class BackendCancellation {
  final _done = Completer<void>();
  final _listeners = <void Function()>{};
  Object? reason;
  bool get cancelled => _done.isCompleted;
  Future<void> get whenCancelled => _done.future;
  void check() {
    if (cancelled) throw reason!;
  }

  void cancel([Object value = const BackendCancelled()]) {
    if (cancelled) return;
    reason = value;
    _done.complete();
    for (final listener in _listeners.toList()) {
      listener();
    }
    _listeners.clear();
  }

  void Function() listen(void Function() listener) {
    if (cancelled) {
      listener();
      return () {};
    }
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  Future<T> wait<T>(Future<T> future) async {
    check();
    final stopped = Completer<T>();
    final detach = listen(() => stopped.completeError(reason!));
    try {
      return await Future.any([future, stopped.future]);
    } finally {
      detach();
    }
  }

  Future<void> delay(Duration duration) async {
    check();
    final done = Completer<void>();
    final timer = Timer(duration, done.complete);
    try {
      await wait(done.future);
    } finally {
      timer.cancel();
    }
  }
}

class BackendScope extends BackendCancellation {
  BackendScope(Duration timeout, Iterable<BackendCancellation?> parents) {
    for (final parent in parents.whereType<BackendCancellation>()) {
      _detach.add(parent.listen(() => cancel(parent.reason!)));
    }
    _timer = Timer(
      timeout,
      () => cancel(TimeoutException('Backend request deadline')),
    );
  }
  final _detach = <void Function()>[];
  Timer? _timer;
  void dispose() {
    _timer?.cancel();
    for (final detach in _detach) {
      detach();
    }
    cancel();
  }
}
