import '../../core/errors.dart';
import '../../core/results.dart';
import '../../core/typedefs.dart';
import '../models/enums.dart';
import '../models/operation.dart';
import '../models/registers.dart';
import '../models/state.dart';
import 'invariant_checker.dart';
import 'operation_validator.dart';
import 'order.dart';

class CrdtEngine {
  CrdtEngine({
    OperationValidator? validator,
    InvariantChecker? invariantChecker,
  })  : _validator = validator ?? OperationValidator(),
        _invariantChecker = invariantChecker ?? InvariantChecker();

  final OperationValidator _validator;
  final InvariantChecker _invariantChecker;

  ApplyResult validateOperation(
    CrdtOperation operation,
    MaterializedHouseholdState state,
  ) {
    final validation = _validator.validate(
      operation,
      OperationValidationContext(state: state),
    );

    if (!validation.isValid) {
      return ApplyResult(
        accepted: false,
        errors: validation.issues
            .map(
              (issue) => DomainError(
                category: ErrorCategory.validation,
                code: issue.code,
                message: issue.message,
              ),
            )
            .toList(),
      );
    }

    return const ApplyResult(accepted: true);
  }

  MaterializedHouseholdState rebuild(List<CrdtOperation> operations) {
    final sorted = [...operations]..sort(compareOperationOrder);
    var state = MaterializedHouseholdState.empty();
    var pending = sorted;
    var madeProgress = true;

    while (pending.isNotEmpty && madeProgress) {
      madeProgress = false;
      final nextRound = <CrdtOperation>[];

      for (final operation in pending) {
        if (state.appliedOpIds.contains(operation.opId)) {
          continue;
        }

        final validation = validateOperation(operation, state);
        if (!validation.accepted) {
          continue;
        }

        if (!_canApply(operation, state)) {
          nextRound.add(operation);
          continue;
        }

        state = _applyOperation(state, operation);
        madeProgress = true;
      }

      pending = nextRound;
    }

    final invariantResult = _invariantChecker.check(state);
    if (!invariantResult.passed) {
      throw StateError(
        'Invariant violation: ${invariantResult.violations.join('; ')}',
      );
    }

    return state;
  }

  ImportResult summarizeImport(
    MaterializedHouseholdState baseState,
    List<CrdtOperation> existingOperations,
    List<CrdtOperation> incomingOperations,
  ) {
    final knownOpIds = existingOperations.map((op) => op.opId).toSet();
    var duplicateCount = 0;
    var importedCount = 0;

    for (final operation in incomingOperations) {
      if (knownOpIds.contains(operation.opId)) {
        duplicateCount += 1;
        continue;
      }

      final validation = validateOperation(operation, baseState);
      if (validation.accepted) {
        importedCount += 1;
      }
    }

    return ImportResult(
      importedCount: importedCount,
      duplicateCount: duplicateCount,
    );
  }

  bool _canApply(CrdtOperation operation, MaterializedHouseholdState state) {
    switch (operation.opType) {
      case OperationType.householdCreate:
      case OperationType.householdRename:
      case OperationType.householdDelete:
        return true;
      case OperationType.memberAdd:
      case OperationType.memberRename:
      case OperationType.memberRemove:
      case OperationType.listCreate:
      case OperationType.listRename:
      case OperationType.listArchiveSet:
      case OperationType.listDelete:
      case OperationType.listMove:
        return state.household != null;
      case OperationType.itemCreate:
        final listId = operation.payload['listId'] as String?;
        return listId != null && state.lists.containsKey(listId);
      case OperationType.itemDelete:
      case OperationType.itemMove:
      case OperationType.todoTextSet:
      case OperationType.todoNoteSet:
      case OperationType.todoCompletedSet:
      case OperationType.shopNameSet:
      case OperationType.shopQuantitySet:
      case OperationType.shopNoteSet:
      case OperationType.shopAcquiredSet:
      case OperationType.shopCategorySet:
        final item = state.items[operation.entityId];
        return item != null && state.lists.containsKey(item.listId);
    }
  }

  MaterializedHouseholdState _applyOperation(
    MaterializedHouseholdState current,
    CrdtOperation operation,
  ) {
    final members = Map<MemberId, MemberRecord>.from(current.members);
    final lists = Map<ListId, ListRecord>.from(current.lists);
    final items = Map<ItemId, ItemRecord>.from(current.items);
    final deletedListIds = Set<ListId>.from(current.deletedListIds);
    final deletedItemIds = Set<ItemId>.from(current.deletedItemIds);
    final applied = Set<String>.from(current.appliedOpIds)..add(operation.opId);
    var household = current.household;

    switch (operation.opType) {
      case OperationType.householdCreate:
        household = HouseholdRecord(
          householdId: operation.entityId,
          name: _stringRegister(operation.payload['name'] as String, operation),
          isDeleted: false,
        );
        break;
      case OperationType.householdRename:
        if (household != null && !household.isDeleted) {
          household = household.copyWith(
            name: mergeRegisters(
              household.name,
              _stringRegister(operation.payload['name'] as String, operation),
            ),
          );
        }
        break;
      case OperationType.householdDelete:
        if (household != null) {
          household = household.copyWith(isDeleted: true);
        }
        break;
      case OperationType.memberAdd:
        final memberId = operation.payload['memberId'] as String;
        final existing = members[memberId];
        final incomingName =
            _stringRegister(operation.payload['displayName'] as String, operation);
        members[memberId] = existing == null
            ? MemberRecord(
                memberId: memberId,
                householdId: operation.householdId,
                displayName: incomingName,
                isRemoved: false,
              )
            : existing.copyWith(
                displayName: mergeRegisters(existing.displayName, incomingName),
              );
        break;
      case OperationType.memberRename:
        final existing = members[operation.entityId];
        if (existing != null && !existing.isRemoved) {
          members[operation.entityId] = existing.copyWith(
            displayName: mergeRegisters(
              existing.displayName,
              _stringRegister(
                operation.payload['displayName'] as String,
                operation,
              ),
            ),
          );
        }
        break;
      case OperationType.memberRemove:
        final existing = members[operation.entityId];
        if (existing != null) {
          members[operation.entityId] = existing.copyWith(isRemoved: true);
        }
        break;
      case OperationType.listCreate:
        final listId = operation.payload['listId'] as String;
        final incomingName =
            _stringRegister(operation.payload['name'] as String, operation);
        final orderKey = _stringRegister(
          operation.payload['initialOrderKey'] as String,
          operation,
        );
        final type = ListType.values.byName(operation.payload['type'] as String);
        lists.putIfAbsent(
          listId,
          () => ListRecord(
            listId: listId,
            householdId: operation.householdId,
            type: type,
            name: incomingName,
            archived: _boolRegister(false, operation),
            orderKey: orderKey,
            deleted: false,
          ),
        );
        break;
      case OperationType.listRename:
        final existing = lists[operation.entityId];
        if (existing != null && !existing.deleted) {
          lists[operation.entityId] = existing.copyWith(
            name: mergeRegisters(
              existing.name,
              _stringRegister(operation.payload['name'] as String, operation),
            ),
          );
        }
        break;
      case OperationType.listArchiveSet:
        final existing = lists[operation.entityId];
        if (existing != null && !existing.deleted) {
          lists[operation.entityId] = existing.copyWith(
            archived: mergeRegisters(
              existing.archived,
              _boolRegister(operation.payload['archived'] as bool, operation),
            ),
          );
        }
        break;
      case OperationType.listDelete:
        final existing = lists[operation.entityId];
        if (existing != null) {
          lists[operation.entityId] = existing.copyWith(deleted: true);
          deletedListIds.add(operation.entityId);
        }
        break;
      case OperationType.listMove:
        final existing = lists[operation.entityId];
        if (existing != null && !existing.deleted) {
          lists[operation.entityId] = existing.copyWith(
            orderKey: mergeRegisters(
              existing.orderKey,
              _stringRegister(
                operation.payload['newOrderKey'] as String,
                operation,
              ),
            ),
          );
        }
        break;
      case OperationType.itemCreate:
        final itemId = operation.payload['itemId'] as String;
        final listId = operation.payload['listId'] as String;
        final parentList = lists[listId];
        if (parentList == null || parentList.deleted) {
          break;
        }

        if (!items.containsKey(itemId)) {
          items[itemId] = _createItemRecord(parentList.type, listId, operation);
        }
        break;
      case OperationType.itemDelete:
        final existing = items[operation.entityId];
        if (existing != null) {
          items[operation.entityId] = existing.copyWith(deleted: true);
          deletedItemIds.add(operation.entityId);
        }
        break;
      case OperationType.itemMove:
        final existing = items[operation.entityId];
        final parent = existing == null ? null : lists[existing.listId];
        if (existing != null &&
            !existing.deleted &&
            parent != null &&
            !parent.deleted) {
          items[operation.entityId] = existing.copyWith(
            orderKey: mergeRegisters(
              existing.orderKey,
              _stringRegister(
                operation.payload['newOrderKey'] as String,
                operation,
              ),
            ),
          );
        }
        break;
      case OperationType.todoTextSet:
        _applyTodoText(items, operation);
        break;
      case OperationType.todoNoteSet:
        _applyTodoNote(items, operation);
        break;
      case OperationType.todoCompletedSet:
        _applyTodoCompleted(items, operation);
        break;
      case OperationType.shopNameSet:
        _applyShopName(items, operation);
        break;
      case OperationType.shopQuantitySet:
        _applyShopQuantity(items, operation);
        break;
      case OperationType.shopNoteSet:
        _applyShopNote(items, operation);
        break;
      case OperationType.shopAcquiredSet:
        _applyShopAcquired(items, operation);
        break;
      case OperationType.shopCategorySet:
        _applyShopCategory(items, operation);
        break;
    }

    return current.copyWith(
      household: household,
      members: members,
      lists: lists,
      items: items,
      deletedListIds: deletedListIds,
      deletedItemIds: deletedItemIds,
      appliedOpIds: applied,
      maxObservedLamport: operation.lamportTs > current.maxObservedLamport
          ? operation.lamportTs
          : current.maxObservedLamport,
    );
  }

  void _applyTodoText(Map<ItemId, ItemRecord> items, CrdtOperation operation) {
    final existing = items[operation.entityId];
    if (existing != null &&
        !existing.deleted &&
        existing.parentListType == ListType.todo) {
      items[operation.entityId] = existing.copyWith(
        todoText: mergeRegisters(
          existing.todoText!,
          _stringRegister(operation.payload['text'] as String, operation),
        ),
      );
    }
  }

  void _applyTodoNote(Map<ItemId, ItemRecord> items, CrdtOperation operation) {
    final existing = items[operation.entityId];
    if (existing != null &&
        !existing.deleted &&
        existing.parentListType == ListType.todo) {
      items[operation.entityId] = existing.copyWith(
        todoNote: mergeRegisters(
          existing.todoNote!,
          _nullableStringRegister(operation.payload['note'] as String?, operation),
        ),
      );
    }
  }

  void _applyTodoCompleted(
    Map<ItemId, ItemRecord> items,
    CrdtOperation operation,
  ) {
    final existing = items[operation.entityId];
    if (existing != null &&
        !existing.deleted &&
        existing.parentListType == ListType.todo) {
      items[operation.entityId] = existing.copyWith(
        todoCompleted: mergeRegisters(
          existing.todoCompleted!,
          _boolRegister(operation.payload['completed'] as bool, operation),
        ),
      );
    }
  }

  void _applyShopName(Map<ItemId, ItemRecord> items, CrdtOperation operation) {
    final existing = items[operation.entityId];
    if (existing != null &&
        !existing.deleted &&
        existing.parentListType == ListType.shopping) {
      items[operation.entityId] = existing.copyWith(
        shopName: mergeRegisters(
          existing.shopName!,
          _stringRegister(operation.payload['name'] as String, operation),
        ),
      );
    }
  }

  void _applyShopQuantity(
    Map<ItemId, ItemRecord> items,
    CrdtOperation operation,
  ) {
    final existing = items[operation.entityId];
    if (existing != null &&
        !existing.deleted &&
        existing.parentListType == ListType.shopping) {
      items[operation.entityId] = existing.copyWith(
        shopQuantity: mergeRegisters(
          existing.shopQuantity!,
          _nullableStringRegister(
            operation.payload['quantityText'] as String?,
            operation,
          ),
        ),
      );
    }
  }

  void _applyShopNote(Map<ItemId, ItemRecord> items, CrdtOperation operation) {
    final existing = items[operation.entityId];
    if (existing != null &&
        !existing.deleted &&
        existing.parentListType == ListType.shopping) {
      items[operation.entityId] = existing.copyWith(
        shopNote: mergeRegisters(
          existing.shopNote!,
          _nullableStringRegister(operation.payload['note'] as String?, operation),
        ),
      );
    }
  }

  void _applyShopAcquired(
    Map<ItemId, ItemRecord> items,
    CrdtOperation operation,
  ) {
    final existing = items[operation.entityId];
    if (existing != null &&
        !existing.deleted &&
        existing.parentListType == ListType.shopping) {
      items[operation.entityId] = existing.copyWith(
        shopAcquired: mergeRegisters(
          existing.shopAcquired!,
          _boolRegister(operation.payload['acquired'] as bool, operation),
        ),
      );
    }
  }

  void _applyShopCategory(
    Map<ItemId, ItemRecord> items,
    CrdtOperation operation,
  ) {
    final existing = items[operation.entityId];
    if (existing != null &&
        !existing.deleted &&
        existing.parentListType == ListType.shopping) {
      items[operation.entityId] = existing.copyWith(
        shopCategory: mergeRegisters(
          existing.shopCategory!,
          _nullableStringRegister(
            operation.payload['category'] as String?,
            operation,
          ),
        ),
      );
    }
  }

  ItemRecord _createItemRecord(
    ListType listType,
    String listId,
    CrdtOperation operation,
  ) {
    final orderKey = _stringRegister(
      operation.payload['initialOrderKey'] as String,
      operation,
    );

    if (listType == ListType.todo) {
      final text = operation.payload['text'] as String? ?? '';
      final note = operation.payload['note'] as String?;
      final completed = operation.payload['completed'] as bool? ?? false;
      return ItemRecord(
        itemId: operation.payload['itemId'] as String,
        listId: listId,
        parentListType: listType,
        todoText: _stringRegister(text, operation),
        todoNote: _nullableStringRegister(note, operation),
        todoCompleted: _boolRegister(completed, operation),
        orderKey: orderKey,
        deleted: false,
      );
    }

    final name = operation.payload['name'] as String? ?? '';
    final quantity = operation.payload['quantityText'] as String?;
    final note = operation.payload['note'] as String?;
    final acquired = operation.payload['acquired'] as bool? ?? false;
    final category = operation.payload['category'] as String?;
    return ItemRecord(
      itemId: operation.payload['itemId'] as String,
      listId: listId,
      parentListType: listType,
      shopName: _stringRegister(name, operation),
      shopQuantity: _nullableStringRegister(quantity, operation),
      shopNote: _nullableStringRegister(note, operation),
      shopAcquired: _boolRegister(acquired, operation),
      shopCategory: _nullableStringRegister(category, operation),
      orderKey: orderKey,
      deleted: false,
    );
  }

  LwwRegister<String> _stringRegister(String value, CrdtOperation operation) {
    return LwwRegister<String>(
      value: value,
      lamportTs: operation.lamportTs,
      actorDeviceId: operation.actorDeviceId,
      opId: operation.opId,
    );
  }

  LwwRegister<String?> _nullableStringRegister(
    String? value,
    CrdtOperation operation,
  ) {
    return LwwRegister<String?>(
      value: value,
      lamportTs: operation.lamportTs,
      actorDeviceId: operation.actorDeviceId,
      opId: operation.opId,
    );
  }

  LwwRegister<bool> _boolRegister(bool value, CrdtOperation operation) {
    return LwwRegister<bool>(
      value: value,
      lamportTs: operation.lamportTs,
      actorDeviceId: operation.actorDeviceId,
      opId: operation.opId,
    );
  }
}
