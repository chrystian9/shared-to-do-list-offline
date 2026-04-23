import '../models/operation.dart';
import '../models/registers.dart';

int compareOperationOrder(CrdtOperation left, CrdtOperation right) {
  final lamport = left.lamportTs.compareTo(right.lamportTs);
  if (lamport != 0) {
    return lamport;
  }

  final actor = left.actorDeviceId.compareTo(right.actorDeviceId);
  if (actor != 0) {
    return actor;
  }

  return left.opId.compareTo(right.opId);
}

int compareRegisterVersion({
  required int lamportTsA,
  required String actorDeviceIdA,
  required String opIdA,
  required int lamportTsB,
  required String actorDeviceIdB,
  required String opIdB,
}) {
  final lamport = lamportTsA.compareTo(lamportTsB);
  if (lamport != 0) {
    return lamport;
  }

  final actor = actorDeviceIdA.compareTo(actorDeviceIdB);
  if (actor != 0) {
    return actor;
  }

  return opIdA.compareTo(opIdB);
}

LwwRegister<T> mergeRegisters<T>(LwwRegister<T> current, LwwRegister<T> incoming) {
  final compare = compareRegisterVersion(
    lamportTsA: incoming.lamportTs,
    actorDeviceIdA: incoming.actorDeviceId,
    opIdA: incoming.opId,
    lamportTsB: current.lamportTs,
    actorDeviceIdB: current.actorDeviceId,
    opIdB: current.opId,
  );
  return compare > 0 ? incoming : current;
}
