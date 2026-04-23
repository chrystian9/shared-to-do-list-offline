import 'package:sqflite/sqflite.dart';

import '../storage/database_constants.dart';
import '../storage/storage_models.dart';
import 'snapshot_repository.dart';

class SqliteSnapshotRepository implements SnapshotRepository {
  const SqliteSnapshotRepository(this._database);

  final Database _database;

  @override
  Future<StoredSnapshot?> loadLatest(String householdId) async {
    final rows = await _database.query(
      snapshotsTable,
      where: 'household_id = ?',
      whereArgs: [householdId],
      orderBy: 'created_at_ms DESC',
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return _fromRow(rows.first);
  }

  @override
  Future<void> save(StoredSnapshot snapshot) async {
    await _database.insert(
      snapshotsTable,
      {
        'snapshot_id': snapshot.snapshotId,
        'household_id': snapshot.householdId,
        'schema_version': snapshot.schemaVersion,
        'protocol_version': snapshot.protocolVersion,
        'base_op_count': snapshot.baseOpCount,
        'max_lamport_covered': snapshot.maxLamportCovered,
        'covered_ops_digest': snapshot.coveredOpsDigest,
        'snapshot_json': snapshot.snapshotJson,
        'created_at_ms': snapshot.createdAtMs,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  StoredSnapshot _fromRow(Map<String, Object?> row) {
    return StoredSnapshot(
      snapshotId: row['snapshot_id'] as String,
      householdId: row['household_id'] as String,
      schemaVersion: row['schema_version'] as int,
      protocolVersion: row['protocol_version'] as int,
      baseOpCount: row['base_op_count'] as int,
      maxLamportCovered: row['max_lamport_covered'] as int,
      coveredOpsDigest: row['covered_ops_digest'] as String,
      snapshotJson: row['snapshot_json'] as String,
      createdAtMs: row['created_at_ms'] as int,
    );
  }
}
