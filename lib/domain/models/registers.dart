class LwwRegister<T> {
  const LwwRegister({
    required this.value,
    required this.lamportTs,
    required this.actorDeviceId,
    required this.opId,
  });

  final T value;
  final int lamportTs;
  final String actorDeviceId;
  final String opId;
}

class Tombstone {
  const Tombstone({
    required this.entityId,
    required this.lamportTs,
    required this.actorDeviceId,
    required this.opId,
  });

  final String entityId;
  final int lamportTs;
  final String actorDeviceId;
  final String opId;
}
