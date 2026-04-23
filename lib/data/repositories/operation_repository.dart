import '../../domain/models/operation.dart';

abstract interface class OperationRepository {
  Future<bool> exists(String opId);
  Future<void> append(CrdtOperation operation);
  Future<void> appendBatch(List<CrdtOperation> operations);
  Future<List<CrdtOperation>> loadForHousehold(String householdId);
  Future<int> maxLamportForDevice(String deviceId);
  Future<List<String>> listHouseholdIds();
}
