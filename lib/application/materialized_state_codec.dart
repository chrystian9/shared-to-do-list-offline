import 'dart:convert';

import '../domain/models/enums.dart';
import '../domain/models/registers.dart';
import '../domain/models/state.dart';

class MaterializedStateCodec {
  String encode(MaterializedHouseholdState state) {
    return jsonEncode({
      'household': state.household == null ? null : _household(state.household!),
      'members': state.members.map((key, value) => MapEntry(key, _member(value))),
      'lists': state.lists.map((key, value) => MapEntry(key, _list(value))),
      'items': state.items.map((key, value) => MapEntry(key, _item(value))),
      'deletedListIds': state.deletedListIds.toList(),
      'deletedItemIds': state.deletedItemIds.toList(),
      'appliedOpIds': state.appliedOpIds.toList(),
      'maxObservedLamport': state.maxObservedLamport,
    });
  }

  MaterializedHouseholdState decode(String input) {
    final json = (jsonDecode(input) as Map).cast<String, Object?>();
    final householdJson = json['household'] as Map?;
    final membersJson = (json['members'] as Map? ?? const {}).cast<String, Object?>();
    final listsJson = (json['lists'] as Map? ?? const {}).cast<String, Object?>();
    final itemsJson = (json['items'] as Map? ?? const {}).cast<String, Object?>();

    return MaterializedHouseholdState(
      household: householdJson == null
          ? null
          : _decodeHousehold(householdJson.cast<String, Object?>()),
      members: membersJson.map(
        (key, value) => MapEntry(
          key,
          _decodeMember((value as Map).cast<String, Object?>()),
        ),
      ),
      lists: listsJson.map(
        (key, value) => MapEntry(
          key,
          _decodeList((value as Map).cast<String, Object?>()),
        ),
      ),
      items: itemsJson.map(
        (key, value) => MapEntry(
          key,
          _decodeItem((value as Map).cast<String, Object?>()),
        ),
      ),
      deletedListIds: ((json['deletedListIds'] as List?) ?? const []).cast<String>().toSet(),
      deletedItemIds: ((json['deletedItemIds'] as List?) ?? const []).cast<String>().toSet(),
      appliedOpIds: ((json['appliedOpIds'] as List?) ?? const []).cast<String>().toSet(),
      maxObservedLamport: json['maxObservedLamport'] as int? ?? 0,
    );
  }

  Map<String, Object?> _household(HouseholdRecord record) => {
        'householdId': record.householdId,
        'name': _register(record.name),
        'isDeleted': record.isDeleted,
      };

  Map<String, Object?> _member(MemberRecord record) => {
        'memberId': record.memberId,
        'householdId': record.householdId,
        'displayName': _register(record.displayName),
        'isRemoved': record.isRemoved,
      };

  Map<String, Object?> _list(ListRecord record) => {
        'listId': record.listId,
        'householdId': record.householdId,
        'type': record.type.name,
        'name': _register(record.name),
        'archived': _register(record.archived),
        'orderKey': _register(record.orderKey),
        'deleted': record.deleted,
      };

  Map<String, Object?> _item(ItemRecord record) => {
        'itemId': record.itemId,
        'listId': record.listId,
        'parentListType': record.parentListType.name,
        'todoText': record.todoText == null ? null : _register(record.todoText!),
        'todoNote': record.todoNote == null ? null : _register(record.todoNote!),
        'todoCompleted':
            record.todoCompleted == null ? null : _register(record.todoCompleted!),
        'shopName': record.shopName == null ? null : _register(record.shopName!),
        'shopQuantity':
            record.shopQuantity == null ? null : _register(record.shopQuantity!),
        'shopNote': record.shopNote == null ? null : _register(record.shopNote!),
        'shopAcquired':
            record.shopAcquired == null ? null : _register(record.shopAcquired!),
        'shopCategory':
            record.shopCategory == null ? null : _register(record.shopCategory!),
        'orderKey': _register(record.orderKey),
        'deleted': record.deleted,
      };

  Map<String, Object?> _register(LwwRegister<dynamic> register) => {
        'value': register.value,
        'lamportTs': register.lamportTs,
        'actorDeviceId': register.actorDeviceId,
        'opId': register.opId,
      };

  HouseholdRecord _decodeHousehold(Map<String, Object?> json) {
    return HouseholdRecord(
      householdId: json['householdId'] as String,
      name: _decodeTypedRegister<String>((json['name'] as Map).cast<String, Object?>()),
      isDeleted: json['isDeleted'] as bool,
    );
  }

  MemberRecord _decodeMember(Map<String, Object?> json) {
    return MemberRecord(
      memberId: json['memberId'] as String,
      householdId: json['householdId'] as String,
      displayName:
          _decodeTypedRegister<String>((json['displayName'] as Map).cast<String, Object?>()),
      isRemoved: json['isRemoved'] as bool,
    );
  }

  ListRecord _decodeList(Map<String, Object?> json) {
    return ListRecord(
      listId: json['listId'] as String,
      householdId: json['householdId'] as String,
      type: ListType.values.byName(json['type'] as String),
      name: _decodeTypedRegister<String>((json['name'] as Map).cast<String, Object?>()),
      archived:
          _decodeTypedRegister<bool>((json['archived'] as Map).cast<String, Object?>()),
      orderKey:
          _decodeTypedRegister<String>((json['orderKey'] as Map).cast<String, Object?>()),
      deleted: json['deleted'] as bool,
    );
  }

  ItemRecord _decodeItem(Map<String, Object?> json) {
    return ItemRecord(
      itemId: json['itemId'] as String,
      listId: json['listId'] as String,
      parentListType: ListType.values.byName(json['parentListType'] as String),
      todoText: _decodeNullableRegister<String>(json['todoText']),
      todoNote: _decodeNullableRegister<String?>(json['todoNote']),
      todoCompleted: _decodeNullableRegister<bool>(json['todoCompleted']),
      shopName: _decodeNullableRegister<String>(json['shopName']),
      shopQuantity: _decodeNullableRegister<String?>(json['shopQuantity']),
      shopNote: _decodeNullableRegister<String?>(json['shopNote']),
      shopAcquired: _decodeNullableRegister<bool>(json['shopAcquired']),
      shopCategory: _decodeNullableRegister<String?>(json['shopCategory']),
      orderKey:
          _decodeTypedRegister<String>((json['orderKey'] as Map).cast<String, Object?>()),
      deleted: json['deleted'] as bool,
    );
  }

  LwwRegister<T> _decodeTypedRegister<T>(Map<String, Object?> json) {
    return LwwRegister<T>(
      value: json['value'] as T,
      lamportTs: json['lamportTs'] as int,
      actorDeviceId: json['actorDeviceId'] as String,
      opId: json['opId'] as String,
    );
  }

  LwwRegister<T>? _decodeNullableRegister<T>(Object? raw) {
    if (raw == null) {
      return null;
    }
    return _decodeTypedRegister<T>((raw as Map).cast<String, Object?>());
  }
}
