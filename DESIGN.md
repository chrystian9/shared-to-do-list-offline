# DESIGN.md

## 1. Architecture Overview

### 1.1 Goals
This design defines the technical architecture for an offline-first Flutter app for shared family lists. It follows `SPEC.md` exactly:
- operation-based CRDT replication
- no central server
- deterministic convergence
- tombstone-based deletion
- durable local-first writes

The design is implementation-ready at the architectural level but intentionally avoids full implementation code.

### 1.2 High-Level Layers
The system shall be divided into the following layers:

#### Presentation Layer
Responsibilities:
- Render screens and local interaction state
- Translate user intents into application commands
- Observe derived view models
- Show sync status, validation errors, and conflict outcomes
- Apply local-only layout and visual theme preferences without changing shared-state semantics

Includes:
- Flutter widgets
- View models / controllers
- Local-only UI preferences

#### Application Layer
Responsibilities:
- Coordinate user use cases
- Validate commands against business rules from `SPEC.md`
- Create operations through the CRDT/application services
- Trigger local persistence and sync scheduling
- Expose read models for UI

Includes:
- Use case handlers
- Command validators
- Query services
- Sync coordinator

#### Domain Layer
Responsibilities:
- Define canonical entities, value types, invariants, and merge semantics
- Materialize state from operations
- Resolve conflicts deterministically
- Enforce delete/tombstone rules

Includes:
- CRDT engine
- operation model
- materialized household state
- invariant checks

#### Infrastructure Layer
Responsibilities:
- Persist operations, snapshots, metadata, and local settings
- Provide peer-to-peer transport implementations
- Handle serialization, integrity checks, and version negotiation
- Schedule and execute sync sessions

Includes:
- SQLite storage
- transport adapters
- import/export codecs
- snapshot manager

### 1.3 Architectural Principles
- Local write is authoritative for immediate UX, but only after durable persistence.
- Shared state is represented as immutable operations plus snapshots.
- Materialized state is derived and replaceable.
- Sync exchanges data through abstract transports and must not affect semantics.
- Every merge path must use the same domain logic as local replay.
- Read models may be cached, but canonical correctness comes from operation fold semantics.

### 1.4 Deployment Model
Each mobile device hosts a complete replica subsystem:
- local operation log
- local snapshot store
- materializer
- sync engine
- UI

No external server is required for correctness.

### 1.5 Current Implementation Snapshot (Apr 2026)
Implemented modules in code:
- CRDT engine with deterministic replay and invariant checks.
- SQLite-backed repositories for operations and snapshots.
- App service orchestration for household/list/item use cases.
- Manual JSON sync transport (`manual_json`) for export/import.
- LAN sync transport with local HTTP export, peer discovery, and Wi-Fi sync dialogs.
- Basic sync dialogs in UI (paste/import, payload export, invitations, and LAN sync).
- Responsive compact/mobile layout that prioritizes list content and moves household navigation into a drawer on narrow screens.
- Local visual theme preference with `classic` and `terminal` modes persisted per device.

Current sync limitations:
- No background sync scheduler.
- No peer auth/capability negotiation flow in runtime transport.
- LAN sync depends on local network availability and platform permissions; discovery/startup failures are surfaced in the UI and do not block opening the sync dialog.

## 2. Module Breakdown

### 2.1 CRDT Engine Module
Purpose:
- Own all shared-state semantics
- Accept valid operations
- Merge remote operations
- Materialize deterministic household state

Submodules:

#### Operation Registry
Responsibilities:
- Define supported operation kinds
- Validate payload schema per operation type
- Route operation application logic

#### Operation Validator
Responsibilities:
- Validate structural correctness
- Validate entity existence/dependencies
- Validate text constraints
- Validate actor and membership constraints where locally knowable

#### Lamport Clock Service
Responsibilities:
- Produce monotonically increasing local timestamps per device
- Advance local logical clock when receiving remote operations

#### Merge Resolver
Responsibilities:
- Apply LWW register semantics
- Apply delete dominance
- Apply parent delete dominance
- Apply deterministic ordering tie-breakers

#### Materializer
Responsibilities:
- Fold operations into current household state
- Produce entities, tombstones, and derived projections
- Rebuild from snapshot + tail operations

#### Invariant Checker
Responsibilities:
- Assert system invariants after replay or sync import
- Detect corruption or invalid transitions

### 2.2 Storage Module
Purpose:
- Persist operations durably
- Support efficient replay and sync
- Store snapshots and metadata

Submodules:

#### Operation Store
- Append operations atomically
- Query by household
- Query missing operations for sync
- Deduplicate by `op_id`

#### Snapshot Store
- Persist compact household snapshots
- Track snapshot coverage
- Load latest valid snapshot

#### Metadata Store
- Store device identity, member identity, protocol versions
- Store peer sync cursors and summaries
- Store local UI preferences separately from shared data

#### Transaction Manager
- Provide atomic commit for local operations and sync batches
- Ensure crash-safe durability semantics

### 2.3 Sync Module
Purpose:
- Discover peers
- Negotiate compatibility
- Exchange replica summaries and missing data
- Validate and import remote data safely

Submodules:

#### Sync Coordinator
- Orchestrates sync sessions
- Selects transport
- Schedules retries

#### Transport Abstraction
- Defines generic send/receive session API
- Hides Bluetooth, LAN, file import/export, and share flows

#### Protocol Codec
- Serializes messages, operations, summaries, and snapshots
- Validates versions and checksums

#### Import Pipeline
- Stages remote data
- Validates integrity and dependencies
- Commits atomically

#### Export Pipeline
- Builds operation batches or snapshot bundles
- Generates invitation payloads and export files

### 2.4 UI Module
Purpose:
- Present household/list/item read models
- Capture user commands
- Display sync and validation state

Submodules:

#### Screens
- Household selector
- Household members
- List overview
- To-do list screen
- Shopping list screen
- Sync/pairing flows
- Settings and data management

#### View Models
- Expose derived state optimized for rendering
- Translate UI intents into application commands
- Observe materialized projections

#### Local Preferences
- Collapsed completed-items state
- sort/filter settings
- last opened views
- selected visual theme mode
- compact vs split-pane navigation depending on available width

## 3. Data Flow

### 3.1 Local User Action Flow
The canonical local write path is:

1. User performs an action in UI.
2. UI emits an application command.
3. Application layer validates command-level preconditions.
4. Domain layer creates one immutable operation.
5. Operation is validated structurally and semantically.
6. Operation is persisted durably in a local transaction.
7. Lamport clock metadata is advanced and persisted.
8. Materialized state is updated from the new operation.
9. Read models are refreshed.
10. Sync coordinator marks the household as having outbound changes.

### 3.2 Remote Sync Flow
The canonical remote import path is:

1. Transport establishes a sync session.
2. Peers exchange capability and replica summaries.
3. Missing operations and/or snapshot are received into staging.
4. Protocol codec validates schema version, checksums, and household identity.
5. Domain validator checks operation validity.
6. Import batch is atomically committed to operation store.
7. Materializer rebuilds from latest valid snapshot plus new operations.
8. Sync metadata is updated.
9. UI observers receive refreshed projections.

### 3.3 Data Flow Diagram
```text
User Action
  -> UI Intent
  -> Application Command
  -> Operation Builder
  -> Operation Validator
  -> Local Transaction
  -> Operation Store
  -> Materializer
  -> Read Models
  -> UI Refresh
  -> Sync Queue
  -> Transport Session
  -> Remote Peer
```

### 3.4 Delete Flow
For delete actions:
- UI issues delete command
- Application emits tombstone operation
- Operation store persists delete
- Materializer marks entity deleted
- Read models exclude entity from normal views
- Sync propagates tombstone like any other operation

## 4. CRDT Design

### 4.1 CRDT Model Choice
The design uses an operation-based CRDT with:
- immutable append-only operation log
- tombstone-based OR-set style identity retention for deleted entities
- LWW registers for mutable scalar fields
- sequence ordering keys for deterministic list/item ordering

This is not a single generic CRDT object. It is a composition of:
- entity identity set
- per-field LWW registers
- tombstone set
- ordered sequence positions

### 4.2 Internal Structures

#### Canonical Operation
```dart
typedef EntityId = String;
typedef OperationId = String;
typedef HouseholdId = String;
typedef DeviceId = String;
typedef MemberId = String;

enum EntityType { household, member, list, item }

enum OperationType {
  householdCreate,
  householdRename,
  householdDelete,
  memberAdd,
  memberRename,
  memberRemove,
  listCreate,
  listRename,
  listArchiveSet,
  listDelete,
  listMove,
  itemCreate,
  itemDelete,
  itemMove,
  todoTextSet,
  todoNoteSet,
  todoCompletedSet,
  shopNameSet,
  shopQuantitySet,
  shopNoteSet,
  shopAcquiredSet,
  shopCategorySet,
}

class CrdtOperation {
  final OperationId opId;
  final HouseholdId householdId;
  final DeviceId actorDeviceId;
  final MemberId actorMemberId;
  final int lamportTs;
  final int? wallClockMs;
  final EntityType entityType;
  final EntityId entityId;
  final OperationType opType;
  final Map<String, Object?> payload;
  final int schemaVersion;
  final int protocolVersion;
  final List<OperationId> causalParents;
}
```

#### Materialized Household State
```dart
class MaterializedHouseholdState {
  final HouseholdRecord? household;
  final Map<MemberId, MemberRecord> members;
  final Map<String, ListRecord> lists;
  final Map<String, ItemRecord> items;
  final Set<String> deletedListIds;
  final Set<String> deletedItemIds;
  final Set<OperationId> appliedOps;
  final int maxObservedLamport;
}
```

#### Field Register
Each mutable field is represented internally as:
```dart
class LwwRegister<T> {
  final T? value;
  final int lamportTs;
  final String actorDeviceId;
  final String opId;
}
```

Comparison rule:
1. Higher `lamportTs` wins
2. If tied, higher lexicographic `actorDeviceId` wins
3. If tied, higher lexicographic `opId` wins

#### Tombstone Tracking
```dart
class Tombstone {
  final String entityId;
  final int lamportTs;
  final String actorDeviceId;
  final String opId;
}
```

Delete lookup is required for:
- entity visibility
- rejecting resurrection
- parent delete dominance

#### Order Key
`order_key` shall be modeled as an opaque, sortable sequence key.

Required properties:
- deterministic total ordering when combined with entity ID
- supports insertion between existing neighbors
- serializable across devices
- comparable without transport-specific interpretation

Design choice:
- represent as canonical string or byte sequence
- tie-break by entity ID lexicographically if equal

### 4.3 Materialized Records
```dart
enum ListType { todo, shopping }

class HouseholdRecord {
  final HouseholdId householdId;
  final LwwRegister<String> name;
  final bool isDeleted;
}

class MemberRecord {
  final MemberId memberId;
  final HouseholdId householdId;
  final LwwRegister<String> displayName;
  final bool isRemoved;
}

class ListRecord {
  final String listId;
  final HouseholdId householdId;
  final ListType type;
  final LwwRegister<String> name;
  final LwwRegister<bool> archived;
  final LwwRegister<String> orderKey;
  final bool deleted;
}

class ItemRecord {
  final String itemId;
  final String listId;
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
}
```

### 4.4 Merge Semantics by Entity

#### Household
- `HOUSEHOLD_CREATE` creates base record
- `HOUSEHOLD_RENAME` updates `name` LWW register
- `HOUSEHOLD_DELETE` marks household deleted

#### Member
- `MEMBER_ADD` creates base record
- `MEMBER_RENAME` updates display name LWW register
- `MEMBER_REMOVE` marks member removed

#### List
- `LIST_CREATE` creates base record with immutable `type`
- `LIST_RENAME` updates name register
- `LIST_ARCHIVE_SET` updates archived register
- `LIST_MOVE` updates order key register
- `LIST_DELETE` marks deleted

#### Item
- `ITEM_CREATE` creates typed base record according to parent list type
- typed update ops update only fields valid for that type
- `ITEM_MOVE` updates order key register
- `ITEM_DELETE` marks deleted

### 4.5 Merge Algorithm Pseudocode
```text
function importBatch(householdId, incomingOps):
  begin transaction
    dedupedOps = filter op where op.opId not already stored
    for each op in dedupedOps:
      validateSchema(op)
      validateHousehold(op, householdId)
      validateActor(op)
      stage op
    commit staged ops atomically
  end transaction

  rebuildHouseholdState(householdId)
```

```text
function rebuildHouseholdState(householdId):
  snapshot = loadLatestCoveredSnapshot(householdId)
  state = snapshot.state if snapshot exists else emptyState()
  ops = loadOpsAfterSnapshotCoverage(householdId, snapshot)
  orderedOps = deterministicReplayOrder(ops)

  for each op in orderedOps:
    if state.appliedOps contains op.opId:
      continue
    applyOperation(state, op)
    state.appliedOps.add(op.opId)

  assertInvariants(state)
  persistMaterializedCaches(state)
  maybeCreateSnapshot(state)
  return state
```

```text
function applyOperation(state, op):
  switch op.opType:
    case HOUSEHOLD_CREATE:
      ensure household absent or identical
      create household record

    case HOUSEHOLD_RENAME:
      if household exists and not household.isDeleted:
        household.name = lwwMerge(household.name, op.value)

    case HOUSEHOLD_DELETE:
      mark household deleted

    case MEMBER_ADD:
      create member if absent

    case MEMBER_RENAME:
      if member exists and not member.isRemoved:
        member.displayName = lwwMerge(member.displayName, op.value)

    case MEMBER_REMOVE:
      mark member removed

    case LIST_CREATE:
      create list if absent

    case LIST_RENAME:
      if list exists and not list.deleted:
        list.name = lwwMerge(list.name, op.value)

    case LIST_ARCHIVE_SET:
      if list exists and not list.deleted:
        list.archived = lwwMerge(list.archived, op.value)

    case LIST_MOVE:
      if list exists and not list.deleted:
        list.orderKey = lwwMerge(list.orderKey, op.value)

    case LIST_DELETE:
      mark list deleted

    case ITEM_CREATE:
      create item if absent and parent list exists

    case ITEM_MOVE:
      if item exists and not item.deleted and not parentListDeleted(item):
        item.orderKey = lwwMerge(item.orderKey, op.value)

    case ITEM_DELETE:
      mark item deleted

    case TODO_TEXT_SET / TODO_NOTE_SET / TODO_COMPLETED_SET:
      apply typed field update if item exists, type matches, and item not deleted

    case SHOP_NAME_SET / SHOP_QUANTITY_SET / SHOP_NOTE_SET / SHOP_ACQUIRED_SET / SHOP_CATEGORY_SET:
      apply typed field update if item exists, type matches, and item not deleted
```

```text
function lwwMerge(currentRegister, incomingOperationValue):
  incomingRegister = registerFromOperation(incomingOperationValue)
  if incomingRegister > currentRegister by totalOrder:
    return incomingRegister
  return currentRegister
```

### 4.6 Replay Order
Canonical replay order for stored operations:
1. ascending `lamport_ts`
2. ascending `actor_device_id`
3. ascending `op_id`

Reason:
- stable deterministic fold
- easy rebuilding from log
- consistent with tie-breaking semantics

Note:
- correctness must not rely on receive order
- invalid dependency cases may be staged but not materialized until satisfiable

### 4.7 Dependency Handling
Some operations reference entities that may not yet be known locally.

Design rule:
- store valid-but-unresolved operations in the operation log if they are structurally valid and household-valid
- during rebuild, an operation with unresolved prerequisites is skipped into a deferred set
- replay continues until fixpoint
- if unresolved operations remain after no progress, mark sync/import state as incomplete or invalid

Example unresolved cases:
- `ITEM_CREATE` received before parent `LIST_CREATE`
- field update received before `ITEM_CREATE`

Fixpoint replay pseudocode:
```text
function applyWithDependencies(state, ops):
  pending = ops
  progress = true

  while progress and pending not empty:
    progress = false
    nextPending = []
    for op in pending:
      if canApply(state, op):
        applyOperation(state, op)
        progress = true
      else:
        nextPending.add(op)
    pending = nextPending

  if pending not empty:
    record unresolved dependency condition
```

## 5. Sync Architecture

### 5.1 Sync Model
Sync is peer-to-peer replica exchange. The sync subsystem shall:
- compare replica summaries
- exchange missing operations or snapshot+tail
- validate and commit atomically
- be resumable and idempotent

### 5.2 Transport Abstraction
The current implementation exposes a minimal transport contract focused on payload import/export.

```dart
abstract interface class SyncTransport {
  String get transportId;
  Future<List<DiscoveredPeer>> discoverPeers();
  Future<String> exportPayload(ExportPayload payload);
  Future<ExportPayload> importPayload(String serializedPayload);
}
```

Current transport implementation:
- `ManualJsonSyncTransport`

Planned transport implementations:
- `LanTransport` (Wi-Fi local network)
- `BluetoothTransport`
- `FileTransferTransport`
- `OsShareTransport`
- `QrBootstrapTransport` for invitation/bootstrap payloads

### 5.3 Sync Coordinator Responsibilities
- Start manual or scheduled sync
- Choose transport and peer
- Execute protocol state machine
- Retry on transient failure
- Update sync status read models

Protocol state machine:
1. `idle`
2. `connecting`
3. `negotiating`
4. `exchanging_summaries`
5. `transferring`
6. `validating`
7. `committing`
8. `complete` or `failed`

### 5.4 Replica Summary Design
A summary shall be lightweight and sufficient to decide whether to:
- exchange deltas
- request a snapshot
- reject incompatible peer

```dart
class ReplicaSummary {
  final String householdId;
  final int protocolVersion;
  final int schemaVersion;
  final String deviceId;
  final int maxLamport;
  final int operationCount;
  final String opsDigest;
  final SnapshotCoverage? latestSnapshotCoverage;
}
```

`opsDigest` is informational for quick mismatch detection and shall not replace per-operation idempotency.

### 5.5 Message Formats

#### Base Envelope
```dart
class ProtocolMessage {
  final String messageId;
  final String sessionId;
  final MessageType type;
  final int protocolVersion;
  final Map<String, Object?> body;
}
```

#### Message Types
```dart
enum MessageType {
  hello,
  capability,
  auth,
  householdOffer,
  summaryRequest,
  summaryResponse,
  opsRequest,
  opsChunk,
  snapshotOffer,
  snapshotChunk,
  ack,
  nack,
  error,
  complete,
}
```

#### Example Bodies

`hello`
```json
{
  "deviceId": "dev_a",
  "supportedProtocolVersions": [1],
  "supportedTransports": ["lan", "bluetooth", "file"]
}
```

`summaryResponse`
```json
{
  "householdId": "hh_1",
  "protocolVersion": 1,
  "schemaVersion": 1,
  "maxLamport": 934,
  "operationCount": 412,
  "opsDigest": "sha256:...",
  "latestSnapshotCoverage": {
    "upToLamport": 900,
    "coveredOpCount": 390
  }
}
```

`opsChunk`
```json
{
  "householdId": "hh_1",
  "chunkIndex": 2,
  "chunkCount": 5,
  "operations": [
    {
      "opId": "op_123",
      "actorDeviceId": "dev_a",
      "lamportTs": 901,
      "opType": "ITEM_CREATE",
      "entityId": "item_9",
      "payload": {}
    }
  ],
  "checksum": "sha256:..."
}
```

`error`
```json
{
  "code": "protocol_version_mismatch",
  "message": "Peer protocol is incompatible",
  "retryable": false
}
```

### 5.6 Sync Import Pipeline
Stages:
1. Receive payload into staging
2. Validate envelope and checksums
3. Validate household identity and compatibility
4. Deduplicate known operations
5. Persist import batch transactionally
6. Rebuild materialized state
7. Record success cursor/summary

### 5.7 Invitation / Bootstrap
Invitation payload shall minimally contain:
- household identifier
- household name
- inviter device/member identity
- protocol/schema version
- optional trust token or membership proof
- optional initial snapshot seed metadata

QR bootstrap is optimized for identity exchange, not full sync payload volume.

## 6. Storage Design

### 6.1 Storage Technology
The local database shall be an embedded transactional store suitable for Flutter mobile, such as SQLite.

Required properties:
- transactional durability
- indexes
- binary/text payload support
- crash-safe commit semantics

### 6.2 Storage Model
Canonical persisted sources:
- operation log
- snapshot store
- metadata tables
- local-only settings

Optional persisted caches:
- materialized projections for fast queries

### 6.3 Tables

#### `households`
Purpose:
- local registry of known households

Columns:
- `household_id` TEXT PRIMARY KEY
- `local_alias` TEXT NULL
- `protocol_version` INTEGER NOT NULL
- `schema_version` INTEGER NOT NULL
- `is_purged` INTEGER NOT NULL DEFAULT 0
- `created_at_ms` INTEGER NOT NULL

#### `members`
Purpose:
- local known member-device mapping metadata

Columns:
- `member_id` TEXT NOT NULL
- `household_id` TEXT NOT NULL
- `display_name_cache` TEXT NULL
- `is_removed_cache` INTEGER NOT NULL DEFAULT 0
- PRIMARY KEY (`household_id`, `member_id`)

Note:
- cache columns are rebuildable from operation log

#### `devices`
Columns:
- `device_id` TEXT PRIMARY KEY
- `member_id` TEXT NOT NULL
- `device_name` TEXT NULL
- `protocol_version` INTEGER NOT NULL
- `last_seen_lamport` INTEGER NULL

#### `operations`
Purpose:
- canonical shared data store

Columns:
- `op_id` TEXT PRIMARY KEY
- `household_id` TEXT NOT NULL
- `actor_device_id` TEXT NOT NULL
- `actor_member_id` TEXT NOT NULL
- `lamport_ts` INTEGER NOT NULL
- `wall_clock_ms` INTEGER NULL
- `entity_type` TEXT NOT NULL
- `entity_id` TEXT NOT NULL
- `op_type` TEXT NOT NULL
- `payload_json` TEXT NOT NULL
- `schema_version` INTEGER NOT NULL
- `protocol_version` INTEGER NOT NULL
- `causal_parents_json` TEXT NOT NULL DEFAULT '[]'
- `integrity_hash` TEXT NULL
- `received_at_ms` INTEGER NOT NULL

#### `snapshots`
Columns:
- `snapshot_id` TEXT PRIMARY KEY
- `household_id` TEXT NOT NULL
- `schema_version` INTEGER NOT NULL
- `protocol_version` INTEGER NOT NULL
- `base_op_count` INTEGER NOT NULL
- `max_lamport_covered` INTEGER NOT NULL
- `covered_ops_digest` TEXT NOT NULL
- `snapshot_blob` BLOB NOT NULL
- `created_at_ms` INTEGER NOT NULL

#### `sync_peers`
Columns:
- `peer_id` TEXT PRIMARY KEY
- `last_known_address` TEXT NULL
- `last_transport_id` TEXT NULL
- `last_seen_ms` INTEGER NULL
- `last_protocol_version` INTEGER NULL

#### `sync_sessions`
Columns:
- `session_id` TEXT PRIMARY KEY
- `household_id` TEXT NOT NULL
- `peer_id` TEXT NULL
- `transport_id` TEXT NOT NULL
- `started_at_ms` INTEGER NOT NULL
- `finished_at_ms` INTEGER NULL
- `status` TEXT NOT NULL
- `error_code` TEXT NULL

#### `sync_cursors`
Purpose:
- store last accepted peer summary for optimization only

Columns:
- `household_id` TEXT NOT NULL
- `peer_id` TEXT NOT NULL
- `remote_max_lamport` INTEGER NOT NULL
- `remote_operation_count` INTEGER NOT NULL
- `remote_ops_digest` TEXT NOT NULL
- `updated_at_ms` INTEGER NOT NULL
- PRIMARY KEY (`household_id`, `peer_id`)

#### `local_settings`
Columns:
- `key` TEXT PRIMARY KEY
- `value_json` TEXT NOT NULL

#### Optional Projection Tables
If query speed requires persisted projections:

`lists_projection`
- `list_id` TEXT PRIMARY KEY
- `household_id` TEXT NOT NULL
- `type` TEXT NOT NULL
- `name` TEXT NOT NULL
- `archived` INTEGER NOT NULL
- `deleted` INTEGER NOT NULL
- `order_key` TEXT NOT NULL

`items_projection`
- `item_id` TEXT PRIMARY KEY
- `household_id` TEXT NOT NULL
- `list_id` TEXT NOT NULL
- `kind` TEXT NOT NULL
- `primary_text` TEXT NOT NULL
- `secondary_text` TEXT NULL
- `checked_state` INTEGER NOT NULL
- `deleted` INTEGER NOT NULL
- `order_key` TEXT NOT NULL

These projections are caches and may be rebuilt.

### 6.4 Indexes
Required indexes:

On `operations`:
- index on (`household_id`, `lamport_ts`)
- index on (`household_id`, `entity_id`)
- index on (`household_id`, `op_type`)
- index on (`household_id`, `actor_device_id`, `lamport_ts`)

On `snapshots`:
- index on (`household_id`, `created_at_ms`)
- index on (`household_id`, `max_lamport_covered`)

On projection tables:
- `lists_projection`: (`household_id`, `deleted`, `archived`, `order_key`)
- `items_projection`: (`household_id`, `list_id`, `deleted`, `order_key`)
- optional text-search indexes depending on chosen search implementation

### 6.5 Snapshot Strategy
Snapshots are optimization artifacts, not authoritative data.

Rules:
- snapshot must be equivalent to replaying a known prefix of operations
- snapshot creation must not block local writes for long periods
- snapshot coverage must be explicit
- import of snapshot + tail must yield identical state to full replay

Trigger policy:
- create snapshot after N new operations in a household
- or when replay time crosses threshold
- or after successful full import/bootstrap

Recommended trigger examples:
- every 500 to 2,000 operations per household
- after bootstrap imports larger than 1,000 operations

Snapshot contents:
- materialized household state
- applied operation coverage metadata
- tombstones
- ordering keys
- schema/protocol versions

Compaction rule:
- operations covered by a retained snapshot may remain in the log
- hard compaction may be allowed later only if import/export/idempotency guarantees remain intact

### 6.6 Transaction Boundaries
Atomic transactions are required for:
- local operation append + lamport clock update
- import batch append + sync metadata update
- snapshot write + coverage metadata update
- projection refresh if projections are persisted transactionally

## 7. API Contracts

### 7.1 Domain Interfaces
```dart
abstract interface class OperationFactory {
  Future<CrdtOperation> createOperation(CreateOperationCommand command);
}

abstract interface class OperationValidator {
  ValidationResult validate(CrdtOperation operation, ValidationContext context);
}

abstract interface class CrdtEngine {
  Future<ApplyResult> applyLocal(CrdtOperation operation);
  Future<ImportResult> importRemoteBatch(
    String householdId,
    List<CrdtOperation> operations,
  );
  Future<MaterializedHouseholdState> rebuildHousehold(String householdId);
  Future<MaterializedHouseholdState?> loadMaterialized(String householdId);
}

abstract interface class InvariantChecker {
  InvariantCheckResult check(MaterializedHouseholdState state);
}
```

### 7.2 Storage Interfaces
```dart
abstract interface class OperationRepository {
  Future<bool> exists(String opId);
  Future<void> append(CrdtOperation operation);
  Future<void> appendBatch(List<CrdtOperation> operations);
  Future<List<CrdtOperation>> loadForHousehold(String householdId);
  Future<List<CrdtOperation>> loadAfterLamport(
    String householdId,
    int lamportExclusive,
  );
}

abstract interface class SnapshotRepository {
  Future<StoredSnapshot?> loadLatest(String householdId);
  Future<void> save(StoredSnapshot snapshot);
}

abstract interface class ProjectionRepository {
  Future<void> replaceHouseholdProjection(MaterializedHouseholdState state);
  Future<List<ListProjection>> loadVisibleLists(String householdId);
  Future<List<ItemProjection>> loadVisibleItems(String listId);
}

abstract interface class TransactionRunner {
  Future<T> runInTransaction<T>(Future<T> Function() action);
}
```

### 7.3 Sync Interfaces
```dart
abstract interface class SyncCoordinator {
  Future<SyncRunResult> syncHousehold(
    String householdId, {
    String? peerId,
    String? transportId,
  });
}

abstract interface class ProtocolCodec {
  Uint8List encodeMessage(ProtocolMessage message);
  ProtocolMessage decodeMessage(Uint8List bytes);
  ExportPayload buildExportPayload(
    String householdId,
    ExportMode mode,
  );
}

abstract interface class ReplicaSummaryService {
  Future<ReplicaSummary> buildSummary(String householdId);
  Future<MissingOpsPlan> diff(
    ReplicaSummary local,
    ReplicaSummary remote,
  );
}
```

### 7.4 Application Use Case Interfaces
```dart
abstract interface class HouseholdUseCases {
  Future<void> createHousehold(String name);
  Future<void> renameHousehold(String householdId, String name);
  Future<void> deleteHousehold(String householdId);
}

abstract interface class ListUseCases {
  Future<void> createList({
    required String householdId,
    required String name,
    required ListType type,
  });

  Future<void> renameList(String listId, String name);
  Future<void> setListArchived(String listId, bool archived);
  Future<void> moveList(String listId, String newOrderKey);
  Future<void> deleteList(String listId);
}

abstract interface class TodoItemUseCases {
  Future<void> addTodoItem({
    required String listId,
    required String text,
    String? note,
  });

  Future<void> setTodoText(String itemId, String text);
  Future<void> setTodoNote(String itemId, String? note);
  Future<void> setTodoCompleted(String itemId, bool completed);
  Future<void> moveItem(String itemId, String newOrderKey);
  Future<void> deleteItem(String itemId);
}

abstract interface class ShoppingItemUseCases {
  Future<void> addShoppingItem({
    required String listId,
    required String name,
    String? quantityText,
    String? note,
    String? category,
  });

  Future<void> setShoppingName(String itemId, String name);
  Future<void> setShoppingQuantity(String itemId, String? quantityText);
  Future<void> setShoppingNote(String itemId, String? note);
  Future<void> setShoppingAcquired(String itemId, bool acquired);
  Future<void> setShoppingCategory(String itemId, String? category);
  Future<void> moveItem(String itemId, String newOrderKey);
  Future<void> deleteItem(String itemId);
}
```

### 7.5 Query Interfaces
```dart
abstract interface class HouseholdQueries {
  Stream<List<HouseholdSummaryVm>> watchHouseholds();
  Stream<HouseholdVm?> watchHousehold(String householdId);
}

abstract interface class ListQueries {
  Stream<List<ListVm>> watchVisibleLists(String householdId);
  Stream<List<ItemVm>> watchVisibleItems(String listId);
  Stream<List<ItemVm>> searchItems(String householdId, String query);
}

abstract interface class SyncQueries {
  Stream<SyncStatusVm> watchSyncStatus(String householdId);
}
```

### 7.6 Core Result Types
```dart
class ValidationResult {
  final bool isValid;
  final List<ValidationIssue> issues;
}

class ApplyResult {
  final bool accepted;
  final List<DomainError> errors;
}

class ImportResult {
  final int importedCount;
  final int duplicateCount;
  final List<DomainError> errors;
}

class InvariantCheckResult {
  final bool passed;
  final List<String> violations;
}
```

## 8. Error Handling Strategy

### 8.1 Error Categories
Errors shall be categorized so the app can decide retryability and user messaging.

Categories:
- validation errors
- invariant violations
- storage errors
- transport errors
- protocol errors
- compatibility errors
- authorization/membership errors
- corruption errors

### 8.2 Domain Validation Errors
Examples:
- empty item text
- invalid parent list
- wrong item type for operation
- operation references deleted entity in disallowed way
- member/device not authorized

Handling:
- reject before persistence for local operations
- reject before commit for imported operations
- present user-friendly message for local actions

### 8.3 Storage Errors
Examples:
- transaction failure
- database unavailable
- disk full
- snapshot write failure

Handling:
- local action must fail visibly if durable persistence fails
- operation must not be acknowledged
- sync batch must roll back atomically

### 8.4 Sync and Transport Errors
Examples:
- peer unreachable
- session timeout
- interrupted transfer
- duplicate chunk

Handling:
- safe retry
- no partial visible apply
- preserve previous committed state
- mark sync status as failed with retryable flag where applicable

### 8.5 Protocol Errors
Examples:
- malformed message
- checksum mismatch
- wrong household in payload
- out-of-range schema version

Handling:
- abort session
- discard uncommitted staged data
- record diagnostics

### 8.6 Invariant Violations
Invariant violations are severe.

Handling:
- stop projection refresh for the affected batch if correctness is uncertain
- retain diagnostic evidence
- mark household replica as degraded
- require rebuild from snapshot/log, reimport, or purge/rejoin depending on recoverability

### 8.7 User-Facing Error Policy
User-facing messages shall be:
- concise
- actionable
- non-technical by default

Examples:
- "Couldn’t save change locally."
- "Sync stopped before completion. Your local changes are still safe."
- "This device version can’t sync with the other device."

## 9. Testing Strategy

### 9.1 Testing Principles
Testing must prove the invariants and convergence guarantees from `SPEC.md`.

The strategy shall include:
- unit tests
- property-based tests
- integration tests
- transport/session tests
- crash/recovery tests
- deterministic replay tests

### 9.2 Unit Tests
Focus:
- operation validation
- LWW register comparison
- tombstone behavior
- ordering key comparison
- dependency handling

Examples:
- later lamport wins
- equal lamport resolves by device ID then op ID
- deleted item stays deleted after later field update
- list delete hides child items

### 9.3 CRDT Property Tests
Properties:
- commutativity: applying operations in different receive orders converges
- idempotency: duplicate operations do not change result
- associativity: batched imports vs split imports converge
- transport independence: same operations via file/LAN/Bluetooth yield same state

Example property:
```text
for any valid op set S:
  materialize(shuffle(S)) == materialize(sort(S)) == materialize(splitAndImport(S))
```

### 9.4 Integration Tests
Scenarios:
- create household, lists, items offline
- sync two devices and verify convergence
- concurrent rename conflict
- concurrent delete and update conflict
- partial sync then retry
- file export/import with duplicate reimport
- member removal with offline device

### 9.5 Crash and Recovery Tests
Scenarios:
- crash after operation persisted but before projection refresh
- crash during sync batch before commit
- crash during sync batch after commit
- crash during snapshot write

Assertions:
- acknowledged operations survive
- incomplete batches are not partially visible
- rebuild is deterministic after restart

### 9.6 Corruption and Compatibility Tests
Scenarios:
- malformed payload import
- checksum mismatch
- unsupported protocol version
- invalid operation schema

Assertions:
- bad data is rejected
- valid existing state remains intact
- session fails safely

### 9.7 Performance Tests
Required benchmarks:
- 10,000 item search
- household open with 100 lists / 10,000 items
- import of 10,000 operations
- snapshot rebuild vs full replay

### 9.8 Golden Scenario Matrix
The design should be validated with a scenario matrix covering:
- online/offline
- one device/two devices/many devices
- to-do/shopping
- rename/move/delete conflicts
- bootstrap/full sync/partial sync/import

### 9.9 Acceptance Mapping
Each acceptance criterion from `SPEC.md` shall map to at least one automated test.

Minimum required mapping:
- offline usability -> integration tests
- convergence -> property + multi-device integration tests
- idempotent sync -> duplicate import/session tests
- delete finality -> unit + integration tests
- no duplicate identity -> repository + sync tests
- crash safety -> recovery tests

## 10. Design Constraints and Open Technical Choices

The following are constrained by `SPEC.md` and may vary in implementation without changing semantics:
- concrete order-key generation algorithm
- exact transport plugins/libraries
- exact serialization format, if deterministic and versioned
- whether projections are fully persisted or rebuilt on launch

The following may not vary:
- operation immutability
- tombstone delete semantics
- LWW deterministic tie-break rules
- durable local-first acknowledgment
- transport-independent convergence

## 11. Summary

This design implements `SPEC.md` through a layered architecture centered on:
- an operation log as canonical shared state
- a CRDT engine that folds operations into deterministic materialized state
- a transactional local store with snapshots and rebuild support
- a transport-agnostic sync protocol for peer replica exchange
- application services and UI built entirely on top of those guarantees

The design preserves the required invariants:
- same operations, same final state
- duplicate sync is harmless
- deleted entities do not reappear
- crashes do not corrupt committed state
- transport does not change semantics
