import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'database_constants.dart';

class LocalDatabase {
  LocalDatabase._(this.database);

  final Database database;

  static Future<LocalDatabase> open() async {
    final basePath = await getDatabasesPath();
    final dbPath = p.join(basePath, 'shared_lists_offline.db');
    final database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $householdsTable(
            household_id TEXT PRIMARY KEY,
            protocol_version INTEGER NOT NULL,
            schema_version INTEGER NOT NULL,
            is_purged INTEGER NOT NULL DEFAULT 0,
            created_at_ms INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE $operationsTable(
            op_id TEXT PRIMARY KEY,
            household_id TEXT NOT NULL,
            actor_device_id TEXT NOT NULL,
            actor_member_id TEXT NOT NULL,
            lamport_ts INTEGER NOT NULL,
            wall_clock_ms INTEGER,
            entity_type TEXT NOT NULL,
            entity_id TEXT NOT NULL,
            op_type TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            schema_version INTEGER NOT NULL,
            protocol_version INTEGER NOT NULL,
            causal_parents_json TEXT NOT NULL,
            received_at_ms INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE INDEX operations_household_lamport_idx
          ON $operationsTable(household_id, lamport_ts)
        ''');

        await db.execute('''
          CREATE INDEX operations_household_entity_idx
          ON $operationsTable(household_id, entity_id)
        ''');

        await db.execute('''
          CREATE TABLE $snapshotsTable(
            snapshot_id TEXT PRIMARY KEY,
            household_id TEXT NOT NULL,
            schema_version INTEGER NOT NULL,
            protocol_version INTEGER NOT NULL,
            base_op_count INTEGER NOT NULL,
            max_lamport_covered INTEGER NOT NULL,
            covered_ops_digest TEXT NOT NULL,
            snapshot_json TEXT NOT NULL,
            created_at_ms INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE INDEX snapshots_household_created_idx
          ON $snapshotsTable(household_id, created_at_ms)
        ''');

        await db.execute('''
          CREATE TABLE $localSettingsTable(
            key TEXT PRIMARY KEY,
            value_json TEXT NOT NULL
          )
        ''');
      },
    );

    return LocalDatabase._(database);
  }
}
