import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../domain/models/enums.dart';
import '../../domain/models/operation.dart';
import '../storage/database_constants.dart';
import 'operation_repository.dart';

class SqliteOperationRepository implements OperationRepository {
  const SqliteOperationRepository(this._database);

  final Database _database;

  @override
  Future<void> append(CrdtOperation operation) async {
    await _database.insert(
      operationsTable,
      _toRow(operation),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  @override
  Future<void> appendBatch(List<CrdtOperation> operations) async {
    await _database.transaction((txn) async {
      final batch = txn.batch();
      for (final operation in operations) {
        batch.insert(
          operationsTable,
          _toRow(operation),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<bool> exists(String opId) async {
    final rows = await _database.query(
      operationsTable,
      columns: const ['op_id'],
      where: 'op_id = ?',
      whereArgs: [opId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  @override
  Future<List<CrdtOperation>> loadForHousehold(String householdId) async {
    final rows = await _database.query(
      operationsTable,
      where: 'household_id = ?',
      whereArgs: [householdId],
      orderBy: 'lamport_ts ASC, actor_device_id ASC, op_id ASC',
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<List<String>> listHouseholdIds() async {
    final rows = await _database.rawQuery(
      'SELECT DISTINCT household_id FROM $operationsTable ORDER BY household_id ASC',
    );
    return rows
        .map((row) => row['household_id'] as String)
        .toList(growable: false);
  }

  @override
  Future<int> maxLamportForDevice(String deviceId) async {
    final rows = await _database.rawQuery(
      '''
        SELECT COALESCE(MAX(lamport_ts), 0) AS max_lamport
        FROM $operationsTable
        WHERE actor_device_id = ?
      ''',
      [deviceId],
    );

    if (rows.isEmpty) {
      return 0;
    }

    return (rows.first['max_lamport'] as int?) ?? 0;
  }

  Map<String, Object?> _toRow(CrdtOperation operation) {
    return {
      'op_id': operation.opId,
      'household_id': operation.householdId,
      'actor_device_id': operation.actorDeviceId,
      'actor_member_id': operation.actorMemberId,
      'lamport_ts': operation.lamportTs,
      'wall_clock_ms': operation.wallClockMs,
      'entity_type': operation.entityType.name,
      'entity_id': operation.entityId,
      'op_type': operation.opType.name,
      'payload_json': jsonEncode(operation.payload),
      'schema_version': operation.schemaVersion,
      'protocol_version': operation.protocolVersion,
      'causal_parents_json': jsonEncode(operation.causalParents),
      'received_at_ms': DateTime.now().millisecondsSinceEpoch,
    };
  }

  CrdtOperation _fromRow(Map<String, Object?> row) {
    return CrdtOperation(
      opId: row['op_id'] as String,
      householdId: row['household_id'] as String,
      actorDeviceId: row['actor_device_id'] as String,
      actorMemberId: row['actor_member_id'] as String,
      lamportTs: row['lamport_ts'] as int,
      wallClockMs: row['wall_clock_ms'] as int?,
      entityType: _entityTypeFromName(row['entity_type'] as String),
      entityId: row['entity_id'] as String,
      opType: _operationTypeFromName(row['op_type'] as String),
      payload: (jsonDecode(row['payload_json'] as String) as Map)
          .cast<String, Object?>(),
      schemaVersion: row['schema_version'] as int,
      protocolVersion: row['protocol_version'] as int,
      causalParents: (jsonDecode(row['causal_parents_json'] as String) as List)
          .cast<String>(),
    );
  }

  EntityType _entityTypeFromName(String name) => EntityType.values.byName(name);

  OperationType _operationTypeFromName(String name) =>
      OperationType.values.byName(name);
}
