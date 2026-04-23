import '../../core/typedefs.dart';
import 'enums.dart';

class CrdtOperation {
  const CrdtOperation({
    required this.opId,
    required this.householdId,
    required this.actorDeviceId,
    required this.actorMemberId,
    required this.lamportTs,
    required this.entityType,
    required this.entityId,
    required this.opType,
    required this.payload,
    required this.schemaVersion,
    required this.protocolVersion,
    this.wallClockMs,
    this.causalParents = const [],
  });

  final OperationId opId;
  final HouseholdId householdId;
  final DeviceId actorDeviceId;
  final MemberId actorMemberId;
  final int lamportTs;
  final int? wallClockMs;
  final EntityType entityType;
  final String entityId;
  final OperationType opType;
  final Map<String, Object?> payload;
  final int schemaVersion;
  final int protocolVersion;
  final List<OperationId> causalParents;

  Map<String, Object?> toJson() {
    return {
      'opId': opId,
      'householdId': householdId,
      'actorDeviceId': actorDeviceId,
      'actorMemberId': actorMemberId,
      'lamportTs': lamportTs,
      'wallClockMs': wallClockMs,
      'entityType': entityType.name,
      'entityId': entityId,
      'opType': opType.name,
      'payload': payload,
      'schemaVersion': schemaVersion,
      'protocolVersion': protocolVersion,
      'causalParents': causalParents,
    };
  }

  factory CrdtOperation.fromJson(Map<String, Object?> json) {
    return CrdtOperation(
      opId: json['opId'] as String,
      householdId: json['householdId'] as String,
      actorDeviceId: json['actorDeviceId'] as String,
      actorMemberId: json['actorMemberId'] as String,
      lamportTs: json['lamportTs'] as int,
      wallClockMs: json['wallClockMs'] as int?,
      entityType: EntityType.values.byName(json['entityType'] as String),
      entityId: json['entityId'] as String,
      opType: OperationType.values.byName(json['opType'] as String),
      payload: (json['payload'] as Map).cast<String, Object?>(),
      schemaVersion: json['schemaVersion'] as int,
      protocolVersion: json['protocolVersion'] as int,
      causalParents:
          (json['causalParents'] as List? ?? const []).cast<OperationId>(),
    );
  }
}
