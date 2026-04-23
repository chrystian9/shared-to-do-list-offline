import '../../core/typedefs.dart';
import 'enums.dart';
import 'registers.dart';

class HouseholdRecord {
  const HouseholdRecord({
    required this.householdId,
    required this.name,
    required this.isDeleted,
  });

  final HouseholdId householdId;
  final LwwRegister<String> name;
  final bool isDeleted;

  HouseholdRecord copyWith({
    LwwRegister<String>? name,
    bool? isDeleted,
  }) {
    return HouseholdRecord(
      householdId: householdId,
      name: name ?? this.name,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

class MemberRecord {
  const MemberRecord({
    required this.memberId,
    required this.householdId,
    required this.displayName,
    required this.isRemoved,
  });

  final MemberId memberId;
  final HouseholdId householdId;
  final LwwRegister<String> displayName;
  final bool isRemoved;

  MemberRecord copyWith({
    LwwRegister<String>? displayName,
    bool? isRemoved,
  }) {
    return MemberRecord(
      memberId: memberId,
      householdId: householdId,
      displayName: displayName ?? this.displayName,
      isRemoved: isRemoved ?? this.isRemoved,
    );
  }
}

class ListRecord {
  const ListRecord({
    required this.listId,
    required this.householdId,
    required this.type,
    required this.name,
    required this.archived,
    required this.orderKey,
    required this.deleted,
  });

  final ListId listId;
  final HouseholdId householdId;
  final ListType type;
  final LwwRegister<String> name;
  final LwwRegister<bool> archived;
  final LwwRegister<String> orderKey;
  final bool deleted;

  ListRecord copyWith({
    LwwRegister<String>? name,
    LwwRegister<bool>? archived,
    LwwRegister<String>? orderKey,
    bool? deleted,
  }) {
    return ListRecord(
      listId: listId,
      householdId: householdId,
      type: type,
      name: name ?? this.name,
      archived: archived ?? this.archived,
      orderKey: orderKey ?? this.orderKey,
      deleted: deleted ?? this.deleted,
    );
  }
}

class ItemRecord {
  const ItemRecord({
    required this.itemId,
    required this.listId,
    required this.parentListType,
    required this.orderKey,
    required this.deleted,
    this.todoText,
    this.todoNote,
    this.todoCompleted,
    this.shopName,
    this.shopQuantity,
    this.shopNote,
    this.shopAcquired,
    this.shopCategory,
  });

  final ItemId itemId;
  final ListId listId;
  final ListType parentListType;
  final LwwRegister<String>? todoText;
  final LwwRegister<String?>? todoNote;
  final LwwRegister<bool>? todoCompleted;
  final LwwRegister<String>? shopName;
  final LwwRegister<String?>? shopQuantity;
  final LwwRegister<String?>? shopNote;
  final LwwRegister<bool>? shopAcquired;
  final LwwRegister<String?>? shopCategory;
  final LwwRegister<String> orderKey;
  final bool deleted;

  ItemRecord copyWith({
    LwwRegister<String>? todoText,
    LwwRegister<String?>? todoNote,
    LwwRegister<bool>? todoCompleted,
    LwwRegister<String>? shopName,
    LwwRegister<String?>? shopQuantity,
    LwwRegister<String?>? shopNote,
    LwwRegister<bool>? shopAcquired,
    LwwRegister<String?>? shopCategory,
    LwwRegister<String>? orderKey,
    bool? deleted,
  }) {
    return ItemRecord(
      itemId: itemId,
      listId: listId,
      parentListType: parentListType,
      todoText: todoText ?? this.todoText,
      todoNote: todoNote ?? this.todoNote,
      todoCompleted: todoCompleted ?? this.todoCompleted,
      shopName: shopName ?? this.shopName,
      shopQuantity: shopQuantity ?? this.shopQuantity,
      shopNote: shopNote ?? this.shopNote,
      shopAcquired: shopAcquired ?? this.shopAcquired,
      shopCategory: shopCategory ?? this.shopCategory,
      orderKey: orderKey ?? this.orderKey,
      deleted: deleted ?? this.deleted,
    );
  }

  String get primaryText {
    return parentListType == ListType.todo
        ? todoText?.value ?? ''
        : shopName?.value ?? '';
  }

  bool get checkedState {
    return parentListType == ListType.todo
        ? (todoCompleted?.value ?? false)
        : (shopAcquired?.value ?? false);
  }
}

class MaterializedHouseholdState {
  const MaterializedHouseholdState({
    required this.household,
    required this.members,
    required this.lists,
    required this.items,
    required this.deletedListIds,
    required this.deletedItemIds,
    required this.appliedOpIds,
    required this.maxObservedLamport,
  });

  final HouseholdRecord? household;
  final Map<MemberId, MemberRecord> members;
  final Map<ListId, ListRecord> lists;
  final Map<ItemId, ItemRecord> items;
  final Set<ListId> deletedListIds;
  final Set<ItemId> deletedItemIds;
  final Set<String> appliedOpIds;
  final int maxObservedLamport;

  factory MaterializedHouseholdState.empty() {
    return const MaterializedHouseholdState(
      household: null,
      members: {},
      lists: {},
      items: {},
      deletedListIds: {},
      deletedItemIds: {},
      appliedOpIds: {},
      maxObservedLamport: 0,
    );
  }

  MaterializedHouseholdState copyWith({
    HouseholdRecord? household,
    Map<MemberId, MemberRecord>? members,
    Map<ListId, ListRecord>? lists,
    Map<ItemId, ItemRecord>? items,
    Set<ListId>? deletedListIds,
    Set<ItemId>? deletedItemIds,
    Set<String>? appliedOpIds,
    int? maxObservedLamport,
  }) {
    return MaterializedHouseholdState(
      household: household ?? this.household,
      members: members ?? this.members,
      lists: lists ?? this.lists,
      items: items ?? this.items,
      deletedListIds: deletedListIds ?? this.deletedListIds,
      deletedItemIds: deletedItemIds ?? this.deletedItemIds,
      appliedOpIds: appliedOpIds ?? this.appliedOpIds,
      maxObservedLamport: maxObservedLamport ?? this.maxObservedLamport,
    );
  }
}
