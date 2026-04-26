import 'package:uuid/uuid.dart';
 
import '../models/commands.dart';
import '../models/operation.dart';

class LocalOperationFactory {
  LocalOperationFactory({
    required this.schemaVersion,
    required this.protocolVersion,
    required this.nextLamport,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final int schemaVersion;
  final int protocolVersion;
  final int Function() nextLamport;
  final Uuid _uuid;

  CrdtOperation create(CreateOperationCommand command) {
    return CrdtOperation(
      opId: _uuid.v4(),
      householdId: command.householdId,
      actorDeviceId: command.actorDeviceId,
      actorMemberId: command.actorMemberId,
      lamportTs: nextLamport(),
      wallClockMs: DateTime.now().millisecondsSinceEpoch,
      entityType: command.entityType,
      entityId: command.entityId,
      opType: command.opType,
      payload: command.payload,
      schemaVersion: schemaVersion,
      protocolVersion: protocolVersion,
    );
  }
}
