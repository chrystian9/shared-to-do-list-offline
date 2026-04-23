import '../../core/typedefs.dart';
import 'enums.dart';

class CreateOperationCommand {
  const CreateOperationCommand({
    required this.householdId,
    required this.actorDeviceId,
    required this.actorMemberId,
    required this.entityType,
    required this.entityId,
    required this.opType,
    required this.payload,
  });

  final HouseholdId householdId;
  final DeviceId actorDeviceId;
  final MemberId actorMemberId;
  final EntityType entityType;
  final String entityId;
  final OperationType opType;
  final Map<String, Object?> payload;
}
