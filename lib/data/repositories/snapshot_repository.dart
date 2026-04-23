import '../storage/storage_models.dart';

abstract interface class SnapshotRepository {
  Future<StoredSnapshot?> loadLatest(String householdId);
  Future<void> save(StoredSnapshot snapshot);
}
