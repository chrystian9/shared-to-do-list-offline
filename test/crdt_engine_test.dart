import 'package:flutter_test/flutter_test.dart';

import 'package:shared_to_do_list_offline/domain/crdt/crdt_engine.dart';
import 'package:shared_to_do_list_offline/domain/models/enums.dart';
import 'package:shared_to_do_list_offline/domain/models/operation.dart';

void main() {
  group('CrdtEngine', () {
    test('converges regardless of receive order for independent operations', () {
      final engine = CrdtEngine();
      final operations = [
        _op(
          opId: '1',
          lamportTs: 1,
          entityType: EntityType.household,
          entityId: 'hh1',
          opType: OperationType.householdCreate,
          payload: {'name': 'Home'},
        ),
        _op(
          opId: '2',
          lamportTs: 2,
          entityType: EntityType.member,
          entityId: 'mem1',
          opType: OperationType.memberAdd,
          payload: {
            'memberId': 'mem1',
            'displayName': 'Alex',
          },
        ),
        _op(
          opId: '3',
          lamportTs: 3,
          entityType: EntityType.list,
          entityId: 'list1',
          opType: OperationType.listCreate,
          payload: {
            'listId': 'list1',
            'name': 'Groceries',
            'type': 'shopping',
            'initialOrderKey': '001',
          },
        ),
      ];

      final stateA = engine.rebuild(operations);
      final stateB = engine.rebuild(operations.reversed.toList());

      expect(stateA.household?.name.value, stateB.household?.name.value);
      expect(stateA.members['mem1']?.displayName.value, 'Alex');
      expect(stateB.lists['list1']?.name.value, 'Groceries');
    });

    test('duplicate operations are idempotent', () {
      final engine = CrdtEngine();
      final createHousehold = _op(
        opId: '1',
        lamportTs: 1,
        entityType: EntityType.household,
        entityId: 'hh1',
        opType: OperationType.householdCreate,
        payload: {'name': 'Home'},
      );
      final createMember = _op(
        opId: '2',
        lamportTs: 2,
        entityType: EntityType.member,
        entityId: 'mem1',
        opType: OperationType.memberAdd,
        payload: {
          'memberId': 'mem1',
          'displayName': 'Alex',
        },
      );

      final state = engine.rebuild([
        createHousehold,
        createMember,
        createMember,
      ]);

      expect(state.members.length, 1);
      expect(state.appliedOpIds.length, 2);
    });

    test('delete wins over later field updates', () {
      final engine = CrdtEngine();
      final operations = [
        _op(
          opId: '1',
          lamportTs: 1,
          entityType: EntityType.household,
          entityId: 'hh1',
          opType: OperationType.householdCreate,
          payload: {'name': 'Home'},
        ),
        _op(
          opId: '2',
          lamportTs: 2,
          entityType: EntityType.member,
          entityId: 'mem1',
          opType: OperationType.memberAdd,
          payload: {
            'memberId': 'mem1',
            'displayName': 'Alex',
          },
        ),
        _op(
          opId: '3',
          lamportTs: 3,
          entityType: EntityType.list,
          entityId: 'list1',
          opType: OperationType.listCreate,
          payload: {
            'listId': 'list1',
            'name': 'Tasks',
            'type': 'todo',
            'initialOrderKey': '001',
          },
        ),
        _op(
          opId: '4',
          lamportTs: 4,
          entityType: EntityType.item,
          entityId: 'item1',
          opType: OperationType.itemCreate,
          payload: {
            'itemId': 'item1',
            'listId': 'list1',
            'text': 'Pay bills',
            'note': null,
            'completed': false,
            'initialOrderKey': '002',
          },
        ),
        _op(
          opId: '5',
          lamportTs: 5,
          entityType: EntityType.item,
          entityId: 'item1',
          opType: OperationType.itemDelete,
          payload: const {},
        ),
        _op(
          opId: '6',
          lamportTs: 6,
          entityType: EntityType.item,
          entityId: 'item1',
          opType: OperationType.todoTextSet,
          payload: {'text': 'Pay rent'},
        ),
      ];

      final state = engine.rebuild(operations);
      expect(state.items['item1']?.deleted, isTrue);
      expect(state.deletedItemIds.contains('item1'), isTrue);
      expect(state.items['item1']?.todoText?.value, 'Pay bills');
    });

    test('LWW register resolves ties by actor device id and op id', () {
      final engine = CrdtEngine();
      final operations = [
        _op(
          opId: '1',
          lamportTs: 1,
          entityType: EntityType.household,
          entityId: 'hh1',
          opType: OperationType.householdCreate,
          payload: {'name': 'Home'},
          actorDeviceId: 'device-a',
        ),
        _op(
          opId: '2',
          lamportTs: 2,
          entityType: EntityType.household,
          entityId: 'hh1',
          opType: OperationType.householdRename,
          payload: {'name': 'Alpha'},
          actorDeviceId: 'device-a',
        ),
        _op(
          opId: '3',
          lamportTs: 2,
          entityType: EntityType.household,
          entityId: 'hh1',
          opType: OperationType.householdRename,
          payload: {'name': 'Beta'},
          actorDeviceId: 'device-z',
        ),
      ];

      final state = engine.rebuild(operations);
      expect(state.household?.name.value, 'Beta');
    });
  });
}

CrdtOperation _op({
  required String opId,
  required int lamportTs,
  required EntityType entityType,
  required String entityId,
  required OperationType opType,
  required Map<String, Object?> payload,
  String householdId = 'hh1',
  String actorDeviceId = 'device-1',
  String actorMemberId = 'member-1',
}) {
  return CrdtOperation(
    opId: opId,
    householdId: householdId,
    actorDeviceId: actorDeviceId,
    actorMemberId: actorMemberId,
    lamportTs: lamportTs,
    entityType: entityType,
    entityId: entityId,
    opType: opType,
    payload: payload,
    schemaVersion: 1,
    protocolVersion: 1,
  );
}
