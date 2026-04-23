import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/typedefs.dart';
import '../data/repositories/operation_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/snapshot_repository.dart';
import '../data/storage/storage_models.dart';
import '../domain/crdt/clock.dart';
import '../domain/crdt/crdt_engine.dart';
import '../domain/crdt/operation_factory.dart';
import '../domain/models/commands.dart';
import '../domain/models/enums.dart';
import '../domain/models/operation.dart';
import '../domain/models/state.dart';
import '../sync/models.dart';
import '../sync/transports.dart';
import 'app_models.dart';
import 'materialized_state_codec.dart';

class AppService extends ChangeNotifier {
  AppService({
    required OperationRepository operationRepository,
    required SnapshotRepository snapshotRepository,
    required SettingsRepository settingsRepository,
    required SyncTransport syncTransport,
    CrdtEngine? engine,
    Uuid? uuid,
  })  : _operationRepository = operationRepository,
        _snapshotRepository = snapshotRepository,
        _settingsRepository = settingsRepository,
        _syncTransport = syncTransport,
        _engine = engine ?? CrdtEngine(),
        _uuid = uuid ?? const Uuid();

  static const int schemaVersion = 1;
  static const int protocolVersion = 1;
  static const String _deviceIdKey = 'app.device_id';
  static const String _memberIdKey = 'app.member_id';
  static const String _memberNameKey = 'app.member_name';

  final OperationRepository _operationRepository;
  final SnapshotRepository _snapshotRepository;
  final SettingsRepository _settingsRepository;
  final SyncTransport _syncTransport;
  final CrdtEngine _engine;
  final Uuid _uuid;
  final MaterializedStateCodec _codec = MaterializedStateCodec();

  late String _deviceId;
  late String _memberId;
  late String _memberName;
  late LamportClock _clock;
  late LocalOperationFactory _operationFactory;

  final Map<HouseholdId, MaterializedHouseholdState> _states = {};
  HouseholdId? _selectedHouseholdId;
  bool _initialized = false;

  bool get initialized => _initialized;
  String get memberName => _memberName;
  HouseholdId? get selectedHouseholdId => _selectedHouseholdId;
  List<HouseholdSummaryVm> get households => _buildHouseholdSummaries();

  Future<void> initialize() async {
    _deviceId = await _readOrCreateId(_deviceIdKey);
    _memberId = await _readOrCreateId(_memberIdKey);
    _memberName = await _settingsRepository.readJsonValue<String>(_memberNameKey) ??
        'Family member';
    final maxLamport = await _operationRepository.maxLamportForDevice(_deviceId);
    _clock = LamportClock(maxLamport);
    _operationFactory = LocalOperationFactory(
      schemaVersion: schemaVersion,
      protocolVersion: protocolVersion,
      nextLamport: _clock.next,
      uuid: _uuid,
    );

    final householdIds = await _operationRepository.listHouseholdIds();
    for (final householdId in householdIds) {
      _states[householdId] = await _loadState(householdId);
    }

    _selectedHouseholdId = householdIds.isEmpty ? null : householdIds.first;
    _initialized = true;
    notifyListeners();
  }

  Future<void> setMemberName(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return;
    }

    _memberName = trimmed;
    await _settingsRepository.writeJsonValue(_memberNameKey, trimmed);
    notifyListeners();
  }

  Future<void> createHousehold(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final householdId = _uuid.v4();
    final householdCreate = _operationFactory.create(
      CreateOperationCommand(
        householdId: householdId,
        actorDeviceId: _deviceId,
        actorMemberId: _memberId,
        entityType: EntityType.household,
        entityId: householdId,
        opType: OperationType.householdCreate,
        payload: {'name': trimmed},
      ),
    );
    final memberAdd = _operationFactory.create(
      CreateOperationCommand(
        householdId: householdId,
        actorDeviceId: _deviceId,
        actorMemberId: _memberId,
        entityType: EntityType.member,
        entityId: _memberId,
        opType: OperationType.memberAdd,
        payload: {
          'memberId': _memberId,
          'displayName': _memberName,
        },
      ),
    );

    await _operationRepository.appendBatch([householdCreate, memberAdd]);
    await _refreshHousehold(householdId);
    _selectedHouseholdId = householdId;
    notifyListeners();
  }

  Future<void> renameHousehold({
    required HouseholdId householdId,
    required String name,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }

    await _appendAndRefresh(
      householdId,
      CreateOperationCommand(
        householdId: householdId,
        actorDeviceId: _deviceId,
        actorMemberId: _memberId,
        entityType: EntityType.household,
        entityId: householdId,
        opType: OperationType.householdRename,
        payload: {'name': trimmed},
      ),
    );
  }

  Future<void> createList({
    required HouseholdId householdId,
    required String name,
    required ListType type,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final listId = _uuid.v4();
    final operation = _operationFactory.create(
      CreateOperationCommand(
        householdId: householdId,
        actorDeviceId: _deviceId,
        actorMemberId: _memberId,
        entityType: EntityType.list,
        entityId: listId,
        opType: OperationType.listCreate,
        payload: {
          'listId': listId,
          'name': trimmed,
          'type': type.name,
          'initialOrderKey': _newOrderKey(),
        },
      ),
    );
    await _operationRepository.append(operation);
    await _refreshHousehold(householdId);
    notifyListeners();
  }

  Future<void> renameList({
    required HouseholdId householdId,
    required ListId listId,
    required String name,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }

    await _appendAndRefresh(
      householdId,
      CreateOperationCommand(
        householdId: householdId,
        actorDeviceId: _deviceId,
        actorMemberId: _memberId,
        entityType: EntityType.list,
        entityId: listId,
        opType: OperationType.listRename,
        payload: {'name': trimmed},
      ),
    );
  }

  Future<void> setListArchived({
    required HouseholdId householdId,
    required ListId listId,
    required bool archived,
  }) async {
    await _appendAndRefresh(
      householdId,
      CreateOperationCommand(
        householdId: householdId,
        actorDeviceId: _deviceId,
        actorMemberId: _memberId,
        entityType: EntityType.list,
        entityId: listId,
        opType: OperationType.listArchiveSet,
        payload: {'archived': archived},
      ),
    );
  }

  Future<void> deleteList({
    required HouseholdId householdId,
    required ListId listId,
  }) async {
    await _appendAndRefresh(
      householdId,
      CreateOperationCommand(
        householdId: householdId,
        actorDeviceId: _deviceId,
        actorMemberId: _memberId,
        entityType: EntityType.list,
        entityId: listId,
        opType: OperationType.listDelete,
        payload: const {},
      ),
    );
  }

  Future<void> addTodoItem({
    required HouseholdId householdId,
    required ListId listId,
    required String text,
    String? note,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final itemId = _uuid.v4();
    await _appendAndRefresh(
      householdId,
      CreateOperationCommand(
        householdId: householdId,
        actorDeviceId: _deviceId,
        actorMemberId: _memberId,
        entityType: EntityType.item,
        entityId: itemId,
        opType: OperationType.itemCreate,
        payload: {
          'itemId': itemId,
          'listId': listId,
          'text': trimmed,
          'note': note,
          'completed': false,
          'initialOrderKey': _newOrderKey(),
        },
      ),
    );
  }

  Future<void> addShoppingItem({
    required HouseholdId householdId,
    required ListId listId,
    required String name,
    String? quantityText,
    String? note,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final itemId = _uuid.v4();
    await _appendAndRefresh(
      householdId,
      CreateOperationCommand(
        householdId: householdId,
        actorDeviceId: _deviceId,
        actorMemberId: _memberId,
        entityType: EntityType.item,
        entityId: itemId,
        opType: OperationType.itemCreate,
        payload: {
          'itemId': itemId,
          'listId': listId,
          'name': trimmed,
          'quantityText': quantityText,
          'note': note,
          'acquired': false,
          'initialOrderKey': _newOrderKey(),
        },
      ),
    );
  }

  Future<void> setItemChecked({
    required HouseholdId householdId,
    required ItemId itemId,
    required bool checked,
  }) async {
    final item = _states[householdId]?.items[itemId];
    if (item == null) {
      return;
    }

    final opType = item.parentListType == ListType.todo
        ? OperationType.todoCompletedSet
        : OperationType.shopAcquiredSet;
    final payload = item.parentListType == ListType.todo
        ? {'completed': checked}
        : {'acquired': checked};

    await _appendAndRefresh(
      householdId,
      CreateOperationCommand(
        householdId: householdId,
        actorDeviceId: _deviceId,
        actorMemberId: _memberId,
        entityType: EntityType.item,
        entityId: itemId,
        opType: opType,
        payload: payload,
      ),
    );
  }

  Future<void> renameItem({
    required HouseholdId householdId,
    required ItemId itemId,
    required String value,
  }) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final item = _states[householdId]?.items[itemId];
    if (item == null) {
      return;
    }

    final opType = item.parentListType == ListType.todo
        ? OperationType.todoTextSet
        : OperationType.shopNameSet;
    final payload =
        item.parentListType == ListType.todo ? {'text': trimmed} : {'name': trimmed};

    await _appendAndRefresh(
      householdId,
      CreateOperationCommand(
        householdId: householdId,
        actorDeviceId: _deviceId,
        actorMemberId: _memberId,
        entityType: EntityType.item,
        entityId: itemId,
        opType: opType,
        payload: payload,
      ),
    );
  }

  Future<void> updateItemSecondaryText({
    required HouseholdId householdId,
    required ItemId itemId,
    String? value,
  }) async {
    final item = _states[householdId]?.items[itemId];
    if (item == null) {
      return;
    }

    final opType = item.parentListType == ListType.todo
        ? OperationType.todoNoteSet
        : OperationType.shopQuantitySet;
    final payload =
        item.parentListType == ListType.todo ? {'note': value} : {'quantityText': value};

    await _appendAndRefresh(
      householdId,
      CreateOperationCommand(
        householdId: householdId,
        actorDeviceId: _deviceId,
        actorMemberId: _memberId,
        entityType: EntityType.item,
        entityId: itemId,
        opType: opType,
        payload: payload,
      ),
    );
  }

  Future<void> deleteItem({
    required HouseholdId householdId,
    required ItemId itemId,
  }) async {
    await _appendAndRefresh(
      householdId,
      CreateOperationCommand(
        householdId: householdId,
        actorDeviceId: _deviceId,
        actorMemberId: _memberId,
        entityType: EntityType.item,
        entityId: itemId,
        opType: OperationType.itemDelete,
        payload: const {},
      ),
    );
  }

  Future<String> exportHousehold(HouseholdId householdId) async {
    final operations = await _operationRepository.loadForHousehold(householdId);
    final summary = ReplicaSummary(
      householdId: householdId,
      protocolVersion: protocolVersion,
      schemaVersion: schemaVersion,
      deviceId: _deviceId,
      maxLamport: operations.isEmpty ? 0 : operations.last.lamportTs,
      operationCount: operations.length,
      opsDigest: _digestOperations(operations),
    );
    return _syncTransport.exportPayload(
      ExportPayload(summary: summary, operations: operations),
    );
  }

  Future<void> importHousehold(String serializedPayload) async {
    final payload = await _syncTransport.importPayload(serializedPayload);
    await _operationRepository.appendBatch(payload.operations);
    await _refreshHousehold(payload.summary.householdId);

    if (_selectedHouseholdId == null) {
      _selectedHouseholdId = payload.summary.householdId;
    }
    notifyListeners();
  }

  void selectHousehold(HouseholdId householdId) {
    _selectedHouseholdId = householdId;
    notifyListeners();
  }

  MaterializedHouseholdState? householdState(HouseholdId householdId) {
    return _states[householdId];
  }

  List<ListVm> visibleLists(HouseholdId householdId) {
    final state = _states[householdId];
    if (state == null) {
      return const [];
    }

    final listEntries = state.lists.values
        .where((list) => !list.deleted)
        .toList(growable: false)
      ..sort((a, b) {
        final order = a.orderKey.value.compareTo(b.orderKey.value);
        return order != 0 ? order : a.listId.compareTo(b.listId);
      });

    return listEntries.map((list) {
      final items = state.items.values
          .where((item) => item.listId == list.listId && !item.deleted)
          .toList(growable: false);
      final completedCount = items.where((item) => item.checkedState).length;
      return ListVm(
        listId: list.listId,
        name: list.name.value,
        type: list.type,
        archived: list.archived.value,
        itemCount: items.length,
        completedCount: completedCount,
      );
    }).toList(growable: false);
  }

  List<ItemVm> visibleItems(HouseholdId householdId, ListId listId) {
    final state = _states[householdId];
    if (state == null) {
      return const [];
    }

    final items = state.items.values
        .where((item) => item.listId == listId && !item.deleted)
        .toList(growable: false)
      ..sort((a, b) {
        final order = a.orderKey.value.compareTo(b.orderKey.value);
        return order != 0 ? order : a.itemId.compareTo(b.itemId);
      });

    return items.map((item) {
      final subtitle = item.parentListType == ListType.todo
          ? item.todoNote?.value
          : item.shopQuantity?.value ?? item.shopNote?.value;
      return ItemVm(
        itemId: item.itemId,
        listId: item.listId,
        title: item.primaryText,
        subtitle: subtitle,
        checked: item.checkedState,
      );
    }).toList(growable: false);
  }

  Future<void> _appendAndRefresh(
    HouseholdId householdId,
    CreateOperationCommand command,
  ) async {
    final operation = _operationFactory.create(command);
    await _operationRepository.append(operation);
    await _refreshHousehold(householdId);
    notifyListeners();
  }

  Future<void> _refreshHousehold(HouseholdId householdId) async {
    _states[householdId] = await _loadState(householdId);
    await _maybePersistSnapshot(householdId);
  }

  Future<MaterializedHouseholdState> _loadState(HouseholdId householdId) async {
    final snapshot = await _snapshotRepository.loadLatest(householdId);
    final operations = await _operationRepository.loadForHousehold(householdId);

    if (snapshot != null && operations.length <= snapshot.baseOpCount) {
      return _codec.decode(snapshot.snapshotJson);
    }

    return _engine.rebuild(operations);
  }

  Future<void> _maybePersistSnapshot(HouseholdId householdId) async {
    final operations = await _operationRepository.loadForHousehold(householdId);
    if (operations.isEmpty || operations.length % 25 != 0) {
      return;
    }

    final state = _states[householdId];
    if (state == null) {
      return;
    }

    final snapshot = StoredSnapshot(
      snapshotId: _uuid.v4(),
      householdId: householdId,
      schemaVersion: schemaVersion,
      protocolVersion: protocolVersion,
      baseOpCount: operations.length,
      maxLamportCovered: operations.last.lamportTs,
      coveredOpsDigest: _digestOperations(operations),
      snapshotJson: _codec.encode(state),
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _snapshotRepository.save(snapshot);
  }

  Future<String> _readOrCreateId(String key) async {
    final existing = await _settingsRepository.readJsonValue<String>(key);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final value = _uuid.v4();
    await _settingsRepository.writeJsonValue(key, value);
    return value;
  }

  List<HouseholdSummaryVm> _buildHouseholdSummaries() {
    final summaries = <HouseholdSummaryVm>[];
    for (final entry in _states.entries) {
      final state = entry.value;
      final household = state.household;
      if (household == null || household.isDeleted) {
        continue;
      }
      summaries.add(
        HouseholdSummaryVm(
          householdId: entry.key,
          name: household.name.value,
          activeListCount: state.lists.values.where((list) => !list.deleted).length,
          memberCount: state.members.values.where((member) => !member.isRemoved).length,
        ),
      );
    }
    summaries.sort((a, b) => a.name.compareTo(b.name));
    return summaries;
  }

  String _newOrderKey() {
    final timestamp = DateTime.now().microsecondsSinceEpoch.toString().padLeft(20, '0');
    final suffix = _uuid.v4().replaceAll('-', '');
    return '$timestamp-$suffix';
  }

  String _digestOperations(List<CrdtOperation> operations) {
    final encoded = operations.map((operation) => operation.toJson()).toList();
    return base64Encode(utf8.encode(jsonEncode(encoded)));
  }
}
