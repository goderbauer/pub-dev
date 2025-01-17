// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:gcloud/datastore.dart' as ds;
import 'package:gcloud/db.dart';
import 'package:retry/retry.dart';
import 'package:logging/logging.dart';
import 'exceptions.dart';

export 'package:gcloud/datastore.dart' show BlobValue, DatastoreError;
export 'package:gcloud/db.dart';

final Logger _logger = Logger('pub.datastore_helper');

/// Returns the raw Datastore Key using segments.
ds.Key rawDatastoreKey(List segments) {
  if (segments.length % 2 != 0) throw ArgumentError();

  final elements = <ds.KeyElement>[];
  for (var i = 0; i < segments.length; i += 2) {
    elements.add(ds.KeyElement(segments[i] as String, segments[i + 1]));
  }
  return ds.Key(elements);
}

/// Wrap [Transaction] to avoid exposing [Transaction.commit] and
/// [Transaction.rollback].
class TransactionWrapper {
  final Transaction _tx;
  bool _mutated = false;

  TransactionWrapper._(this._tx);

  /// See [Transaction.lookup].
  Future<List<T>> lookup<T extends Model>(List<Key> keys) =>
      _tx.lookup<T>(keys);

  /// [lookupValue] or return `null`.
  Future<T> lookupOrNull<T extends Model>(Key key) =>
      _tx.lookupValue<T>(key, orElse: () => null);

  /// See [Transaction.lookupValue].
  Future<T> lookupValue<T extends Model>(Key key, {T Function() orElse}) =>
      _tx.lookupValue<T>(key, orElse: orElse);

  /// See [Transaction.query].
  Query<T> query<T extends Model>(Key ancestorKey, {Partition partition}) =>
      _tx.query<T>(ancestorKey, partition: partition);

  /// Insert [entity] in this transaction.
  void insert(Model entity) => queueMutations(inserts: [entity]);

  /// Delete entity at [key] in this transaction.
  void delete(Key key) => queueMutations(deletes: [key]);

  /// See [Transaction.queueMutations].
  void queueMutations({List<Model> inserts, List<Key> deletes}) {
    _mutated = true;
    _tx.queueMutations(inserts: inserts, deletes: deletes);
  }
}

extension DatastoreDBExt on DatastoreDB {
  // Deletes the entries that are returned from the [query].
  Future<void> deleteWithQuery<T extends Model>(
    Query<T> query, {
    bool Function(T model) where,
  }) async {
    final deletes = <Key>[];
    final stream = query.run().where((model) => where == null || where(model));
    await for (T model in stream) {
      deletes.add(model.key);
      if (deletes.length == 20) {
        await commit(deletes: deletes);
        deletes.clear();
      }
    }
    if (deletes.isNotEmpty) {
      await commit(deletes: deletes);
      deletes.clear();
    }
  }
}

/// Call [fn] with a [TransactionWrapper] that is either committed or
/// rolled back when [fn] returns.
Future<T> _withTransaction<T>(
  DatastoreDB db,
  Future<T> Function(TransactionWrapper tx) fn,
) async {
  try {
    return await db.withTransaction<T>((tx) async {
      bool commitAttempted = false;
      try {
        final wrapper = TransactionWrapper._(tx);
        final retval = await fn(wrapper);
        if (wrapper._mutated) {
          commitAttempted = true;
          await tx.commit();
        }
        return retval;
      } finally {
        // If a commit has been attempted trying to rollback will always throw
        // a StateError, hence, we never try to rollback if commit was attempted
        if (!commitAttempted) {
          await tx.rollback();
        }
      }
    });
  } catch (e, st) {
    _logger.info('Transaction failed.', e, st);
    rethrow;
  }
}

/// Transaction retry options.
///
/// Transactions should be retried within the 30s timeout for sending an inital
/// response header on AppEngine Flexible. We suspect that AppEngine Flexible
/// has such a timeout, because it uses GCP HTTPS load-balancer under the hood.
///
/// When we would prefer to finish in 30s, and, thus, lower the delays between
/// retries to ensure that:
/// * 0th attempt is delayed    0 ms, with max accumulated delay     0 ms.
/// * 1st attempt is delayed  100 ms, with max accumulated delay   125 ms.
/// * 2nd attempt is delayed  200 ms, with max accumulated delay   375 ms.
/// * 3rd attempt is delayed  400 ms, with max accumulated delay   875 ms.
/// * 4th attempt is delayed  800 ms, with max accumulated delay  1875 ms.
/// * 5th attempt is delayed 1600 ms, with max accumulated delay  3875 ms.
/// * 6th attempt is delayed 3200 ms, with max accumulated delay  7875 ms.
/// * 7th attempt is delayed 5000 ms, with max accumulated delay 14125 ms.
final _transactionRetrier = RetryOptions(
  maxAttempts: 8,
  delayFactor: Duration(milliseconds: 20),
  maxDelay: Duration(seconds: 5),
  randomizationFactor: 0.25,
);

/// Call [fn] with a [TransactionWrapper] that is either committed or
/// rolled back when [fn] returns, and retried if [fn] fails.
///
/// This does not retry [ResponseException].
Future<T> withRetryTransaction<T>(
  DatastoreDB db,
  Future<T> Function(TransactionWrapper tx) fn,
) =>
    _transactionRetrier.retry<T>(
      () => _withTransaction<T>(db, fn),
      // TODO(jonasfj): Over time we want reduce the number exceptions on which
      //                we retry. The following is a list of exceptions we know
      //                we want to retry:
      //  - TransactionAbortedError, implies a transaction conflict.
      // Never retry a ResponseException
      retryIf: (e) => e is! ResponseException,
      onRetry: (e) {
        final message =
            e is ds.DatastoreError ? 'DatastoreError' : 'non-DatastoreError';
        _logger.info('retrying transaction - $message ${e.runtimeType}', e);
      },
    );
