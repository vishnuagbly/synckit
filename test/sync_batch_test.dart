import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synckit/synckit.dart';

class _Item {
  final String id;
  final String label;

  const _Item(this.id, this.label);
}

class _Other {
  final String id;
  final String label;

  const _Other(this.id, this.label);
}

class _Box<T> with SyncedState<T> {
  Dataset<T> _state = <String, T>{}.lock;
  int sets = 0;

  @override
  Dataset<T> get state => _state;

  @override
  set state(Dataset<T> value) {
    sets++;
    _state = value;
  }

  Future<void> ready(
    SyncManager<T> manager, {
    Dataset<T>? initialState,
  }) async {
    state = initialize(
      SyncConfig<T>(manager: manager, initialState: initialState),
    );
    await waitForInitialization;
  }
}

/// Records each queued write and registers a Hive callback, without touching
/// Firestore. Mirrors [SyncManager.batchUpdate] and [SyncManager.batchRemove]:
/// one callback per call, including a second write of the same id.
class _RecordingSyncManager<T> extends SyncManager<T> {
  final List<List<String>> updateIds = [];
  final List<List<String>> removeIds = [];
  int hiveCallbackRuns = 0;
  Future<void> Function()? beforeQueue;
  void Function()? onHive;

  _RecordingSyncManager(StdObjParams<T> params)
      : super(
          stdObjParams: params,
          storage: const LocalStorage.disabled(),
          network: const NetworkStorage.disabled(),
        );

  @override
  Future<void> batchUpdate(Dataset<T> data, SyncBatch syncBatch) async {
    updateIds.add(data.keys.toList());
    final pause = beforeQueue;
    if (pause != null) await pause();
    syncBatch.addAsyncCallback(() async {
      hiveCallbackRuns++;
      onHive?.call();
    });
  }

  @override
  Future<void> batchRemove(Dataset<T> data, SyncBatch syncBatch) async {
    removeIds.add(data.keys.toList());
    final pause = beforeQueue;
    if (pause != null) await pause();
    syncBatch.addAsyncCallback(() async {
      hiveCallbackRuns++;
      onHive?.call();
    });
  }
}

StdObjParams<T> _params<T>(String Function(T) getId) {
  return StdObjParams<T>(
    fromJson: (_) => throw UnimplementedError(),
    toJson: (_) => const {},
    getId: getId,
  );
}

void main() {
  test('await batchUpdate registers the state callback without running it',
      () async {
    final gate = Completer<void>();
    final manager = _RecordingSyncManager<_Item>(_params((item) => item.id))
      ..beforeQueue = () => gate.future;
    final box = _Box<_Item>();
    await box.ready(manager);
    final before = box.state;
    final setsAfterReady = box.sets;

    final batch = SyncBatch.forTest(commitWrites: () async {});
    final pending = box.batchUpdate(const _Item('a', 'one'), batch);

    expect(batch.syncCallbacks, isEmpty);
    expect(manager.hiveCallbackRuns, 0);

    gate.complete();
    await pending;

    expect(batch.syncCallbacks, hasLength(1));
    expect(manager.updateIds, [
      ['a'],
    ]);
    expect(box.state, before);
    expect(box.sets, setsAfterReady);
    expect(manager.hiveCallbackRuns, 0);
  });

  test('await batchRemoveAll registers the state callback without running it',
      () async {
    final manager = _RecordingSyncManager<_Item>(_params((item) => item.id));
    final box = _Box<_Item>();
    const item = _Item('a', 'one');
    await box.ready(
      manager,
      initialState: {item.id: item}.lock,
    );
    final setsAfterReady = box.sets;
    final batch = SyncBatch.forTest(commitWrites: () async {});

    await box.batchRemoveAll(const ['a'], batch);

    expect(batch.syncCallbacks, hasLength(1));
    expect(manager.removeIds, [
      ['a'],
    ]);
    expect(box.state[item.id], item);
    expect(box.sets, setsAfterReady);
    expect(manager.hiveCallbackRuns, 0);
  });

  test('commit failure leaves state unchanged and skips Hive callbacks',
      () async {
    final manager = _RecordingSyncManager<_Item>(_params((item) => item.id));
    final box = _Box<_Item>();
    await box.ready(manager);
    final before = box.state;
    final batch = SyncBatch.forTest(
      commitWrites: () async => throw StateError('firestore failed'),
    );

    await box.batchUpdate(const _Item('a', 'one'), batch);

    await expectLater(batch.commit(), throwsStateError);
    expect(box.state, before);
    expect(manager.hiveCallbackRuns, 0);
    expect(batch.syncCallbacks, hasLength(1));
  });

  test('two notifiers share one batch and each state callback runs once',
      () async {
    final order = <String>[];
    final items = _RecordingSyncManager<_Item>(_params((item) => item.id))
      ..onHive = () => order.add('items-hive');
    final others = _RecordingSyncManager<_Other>(_params((item) => item.id))
      ..onHive = () => order.add('others-hive');
    final itemBox = _Box<_Item>();
    final otherBox = _Box<_Other>();
    await itemBox.ready(items);
    await otherBox.ready(others);
    final itemSets = itemBox.sets;
    final otherSets = otherBox.sets;

    final batch = SyncBatch.forTest(
      commitWrites: () async => order.add('firestore'),
    );
    await itemBox.batchUpdate(const _Item('a', 'one'), batch);
    await otherBox.batchUpdate(const _Other('b', 'two'), batch);
    batch.addSyncCallback(() => order.add('tail'));

    await batch.commit();

    expect(order, ['firestore', 'items-hive', 'others-hive', 'tail']);
    expect(itemBox.state['a']?.label, 'one');
    expect(otherBox.state['b']?.label, 'two');
    expect(itemBox.sets, itemSets + 1);
    expect(otherBox.sets, otherSets + 1);
  });

  test('a second batchUpdate of the same id is forwarded as its own write',
      () async {
    // Callers must coalesce to the final object per id. SyncKit does not
    // collapse two writes of the same id into one batch operation.
    final manager = _RecordingSyncManager<_Item>(_params((item) => item.id));
    final box = _Box<_Item>();
    await box.ready(manager);
    final batch = SyncBatch.forTest(commitWrites: () async {});

    await box.batchUpdate(const _Item('a', 'first'), batch);
    await box.batchUpdate(const _Item('a', 'second'), batch);

    expect(manager.updateIds, [
      ['a'],
      ['a'],
    ]);
    expect(batch.syncCallbacks, hasLength(2));

    final setsBeforeCommit = box.sets;
    await batch.commit();

    expect(box.state['a']?.label, 'second');
    expect(box.sets, setsBeforeCommit + 2);
    expect(manager.hiveCallbackRuns, 2);
  });
}
