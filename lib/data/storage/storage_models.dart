class StoredSnapshot {
  const StoredSnapshot({
    required this.snapshotId,
    required this.householdId,
    required this.schemaVersion,
    required this.protocolVersion,
    required this.baseOpCount,
    required this.maxLamportCovered,
    required this.coveredOpsDigest,
    required this.snapshotJson,
    required this.createdAtMs,
  });

  final String snapshotId;
  final String householdId;
  final int schemaVersion;
  final int protocolVersion;
  final int baseOpCount;
  final int maxLamportCovered;
  final String coveredOpsDigest;
  final String snapshotJson;
  final int createdAtMs;
}
