# SPEC.md

## 1. Overview

### 1.1 Purpose
Define the complete specification for an offline-first Flutter mobile application that supports shared family lists with:
- To-do lists
- Shopping lists
- Multi-device sync without a central server

This document specifies behavior, data model, sync semantics, conflict resolution, failure handling, and invariants. It does not prescribe implementation details beyond what is necessary to guarantee deterministic behavior.

### 1.2 Scope
The app supports:
- Local-only usage on a single device
- Shared usage across multiple devices owned by one or more family members
- Peer-to-peer synchronization using supported transports
- Eventual convergence without a central server

The app does not require:
- Cloud accounts
- Always-on connectivity
- A permanent coordinator node

## 2. Functional Requirements

### 2.1 User Concepts
The system shall support the following concepts:
- `Household`: a shared collaboration space
- `Member`: a person participating in a household
- `Device`: one installation of the app owned by a member
- `List`: a shared collection of items
- `Item`: an entry in a list
- `Operation`: an immutable change event replicated across devices

### 2.2 Household Management
The app shall allow a user to:
- Create a new household locally
- Assign a household name
- Join an existing household using a device-to-device invitation
- Leave a household from a device
- View household members
- Rename the household
- Archive or permanently delete a household only when explicitly confirmed

Edge cases:
- A device may belong to multiple households
- A member may use multiple devices
- A device that leaves a household shall stop creating new operations for that household
- Historical operations for a household may remain locally for audit/replay unless the household is explicitly purged
- A household invitation accepted twice on the same device shall be idempotent

### 2.3 Member Identity
The app shall allow a user to:
- Set and edit their display name
- View the display names of other members
- Distinguish devices belonging to the same member if needed for diagnostics

Edge cases:
- Two members may choose the same display name
- Display names are non-unique and non-authoritative
- Member rename conflicts shall resolve deterministically

### 2.4 List Management
The app shall allow a user to:
- Create a list
- Choose list type: `todo` or `shopping`
- Rename a list
- Archive a list
- Unarchive a list
- Delete a list
- Reorder lists in the household view
- Filter visible lists by state where supported: active, archived, deleted-hidden

Edge cases:
- Creating two lists with the same name is allowed
- Renaming a deleted list shall have no visible effect on active UI state
- Deleting an archived list is allowed
- Reordering while offline shall preserve intent and converge deterministically
- Deleting a list shall hide its items from normal views

### 2.5 To-do List Behavior
For `todo` lists, the app shall allow a user to:
- Add an item
- Edit item text
- Mark item complete
- Mark item incomplete
- Delete an item
- Restore an item only if the deletion operation itself is not finalized by invariant rules; otherwise restore shall create a new item with copied content
- Reorder items
- Assign optional notes
- Assign optional due state if the product later adds due dates; if unsupported, this field is absent from the current spec

Edge cases:
- Empty item text shall be rejected
- Whitespace-only item text shall be rejected
- Completing an already completed item shall be idempotent
- Editing a deleted item shall not resurrect it
- Reordering items with concurrent deletes shall not reintroduce deleted items
- Duplicate visible to-do item texts are allowed unless a future feature explicitly forbids them

### 2.6 Shopping List Behavior
For `shopping` lists, the app shall allow a user to:
- Add an item
- Edit item name
- Edit quantity text
- Mark item as acquired
- Mark item as not acquired
- Delete an item
- Reorder items
- Optionally categorize an item if categories are enabled in the product configuration
- Optionally add notes

Edge cases:
- Empty item name shall be rejected
- Quantity is free-form text and may be empty
- Marking acquired twice shall be idempotent
- Concurrent edits to quantity and acquired state shall merge deterministically
- Editing a deleted shopping item shall not resurrect it

### 2.7 Item Presentation
The app shall:
- Show active items by default
- Allow completed/acquired items to remain visible or be collapsed according to local UI preference
- Preserve shared data independent of local-only view preferences
- Show tombstoned/deleted items only in diagnostic or recovery views if such views are enabled

Edge cases:
- Local display preferences shall never replicate as shared state unless explicitly defined as shared settings
- The same shared state may be rendered differently per device based on local preferences

### 2.8 Search and Filtering
The app shall support:
- Searching lists by name
- Searching items by visible text fields
- Filtering list items by completion/acquired status

Edge cases:
- Deleted items shall not appear in normal search results
- Archived lists may be excluded by default but must remain accessible
- Search behavior while local state is partially synced shall still be deterministic over currently known state

### 2.9 Invitations and Onboarding
The app shall allow:
- Generating an invitation payload for a household
- Accepting an invitation payload on another device
- Sync bootstrap during invitation acceptance

Edge cases:
- Reusing the same invitation on multiple devices is allowed if invitation policy permits multi-use
- Expired or revoked invitations, if supported, must fail deterministically
- Accepting an invitation with partial state transfer must still produce a valid household replica capable of later catch-up sync

### 2.10 Device Pairing and Sync Initiation
The app shall allow users to:
- Discover nearby peers if a transport supports discovery
- Manually initiate sync
- Accept or reject incoming sync requests
- View last sync status per household and/or peer
- Retry failed sync

Edge cases:
- A sync session interrupted midway shall not corrupt local state
- Repeating the same sync after a partial sync must be safe and idempotent
- Sync with an older device version may be rejected if protocol compatibility rules fail

### 2.11 Local Data Control
The app shall allow a user to:
- Export household data
- Import household data if the product supports file-based transfer
- Purge local data for a household from a device
- Reset the entire app with explicit confirmation

Edge cases:
- Importing already known operations shall be idempotent
- Purging local data on one device shall not affect other devices
- Purging and later rejoining a household shall recreate state from replicated operations

## 3. Non-Functional Requirements

### 3.1 Offline-First
The app shall:
- Allow all primary list operations while fully offline
- Never require network/server reachability for create/edit/delete/check actions
- Persist operations locally before acknowledging success to the user
- Treat sync as asynchronous replication, never as the source of truth

### 3.2 Determinism
The system shall guarantee:
- Given the same set of valid operations, every device computes the same final state
- Merge outcomes are independent of transport
- Merge outcomes are independent of sync session boundaries
- Reapplying the same operation any number of times does not change final state after first application

### 3.3 Performance
On a reference mobile device, the app shall meet:
- Local user action acknowledgment: under 100 ms after durable local persistence for typical operations
- Opening a household with up to 100 lists and 10,000 total items: under 1 second from warm local storage
- Incremental merge of 10,000 previously unseen operations: under 3 seconds
- Search across 10,000 visible items: under 300 ms for typical queries
- Memory usage shall remain bounded such that routine operations do not cause process termination on mid-range devices

### 3.4 Durability
The app shall:
- Persist all accepted operations durably before reporting success
- Recover to the latest fully persisted state after app crash or device restart
- Never acknowledge an operation that can be silently lost after a normal process kill

### 3.5 Data Consistency Guarantees
The app shall provide:
- Strong local consistency on each device for its own persisted operations
- Eventual consistency across devices that continue to exchange operations
- Causal preservation where metadata is available, but convergence shall not depend on real-time clocks
- Monotonic replica growth for operation logs except for approved compaction/snapshot rules

### 3.6 Privacy and Security
The spec requires:
- No central server dependency
- Household data exchanged only over explicit peer transports or explicit file export/import
- Device identity and household membership validation during sync
- Optional encryption at rest and in transit may be product requirements, but convergence semantics must not depend on encryption

### 3.7 Compatibility
The system shall define:
- A protocol version for sync
- A data schema version for operations and snapshots
- Rules for rejecting or degrading gracefully on incompatible versions

## 4. Data Model

## 4.1 Identifier Rules
All primary entities shall use globally unique identifiers.
Requirements:
- IDs must be unique across devices without coordination
- IDs are immutable
- IDs are never reused, even after deletion

### 4.2 Entity: Household
Fields:
- `household_id`: globally unique, immutable
- `name`: non-empty string
- `created_at_lamport`: logical timestamp
- `created_by_member_id`
- `is_deleted`: boolean derived from operations, default false

Constraints:
- A deleted household is not shown in active UI
- Household deletion dominates child visibility

### 4.3 Entity: Member
Fields:
- `member_id`: globally unique, immutable
- `household_id`
- `display_name`: non-empty string
- `joined_at_lamport`
- `is_removed`: boolean derived from operations, default false

Constraints:
- `member_id` is unique within and across households
- Display name need not be unique
- Removed members remain referencable in historical metadata

### 4.4 Entity: Device
Fields:
- `device_id`: globally unique, immutable
- `member_id`
- `device_name`: optional string
- `protocol_version`
- `last_seen_lamport`: derived or informational only

Constraints:
- A device belongs to exactly one member
- A member may have multiple devices
- Device metadata shall not affect merge semantics except compatibility gating

### 4.5 Entity: List
Fields:
- `list_id`: globally unique, immutable
- `household_id`
- `type`: enum `todo | shopping`
- `name`: non-empty string
- `created_by_member_id`
- `created_at_lamport`
- `archived`: boolean derived
- `deleted`: boolean derived
- `order_key`: CRDT-derived ordering value
- `last_modified_lamport`: derived informational field

Constraints:
- `type` is immutable after creation
- `list_id` remains unique forever
- A deleted list is excluded from active and archived list views
- `order_key` must permit deterministic total ordering

### 4.6 Entity: Item
Fields common to all items:
- `item_id`: globally unique, immutable
- `list_id`
- `created_by_member_id`
- `created_at_lamport`
- `deleted`: boolean derived
- `order_key`: CRDT-derived ordering value
- `last_modified_lamport`: derived informational field

Fields for to-do items:
- `text`: non-empty string
- `note`: optional string
- `completed`: boolean derived

Fields for shopping items:
- `name`: non-empty string
- `quantity_text`: optional string
- `note`: optional string
- `acquired`: boolean derived
- `category`: optional string if enabled

Constraints:
- Item type is implied by parent list type
- Fields invalid for a parent list type must be absent or ignored
- Empty or whitespace-only primary text fields are invalid
- A deleted item remains addressable by ID for tombstone semantics

### 4.7 Entity: Operation
Fields:
- `op_id`: globally unique, immutable
- `household_id`
- `actor_device_id`
- `actor_member_id`
- `lamport_ts`: strictly increasing per device
- `wall_clock_ms`: optional informational field, non-authoritative
- `entity_type`: enum
- `entity_id`
- `op_type`
- `payload`: operation-specific object
- `schema_version`
- `protocol_version`
- `causal_parents`: optional set of op_ids or version summary
- `auth_context`: optional transport/member proof metadata

Constraints:
- `op_id` uniqueness is absolute
- An operation is immutable once created
- `lamport_ts` must be monotonic per device
- Invalid operations must be rejected and never partially applied

## 5. Operation Model (CRDT)

### 5.1 General Model
The system shall use an operation-based CRDT model.
Rules:
- State is the deterministic fold of all valid operations for a household
- Operations are immutable and idempotent
- Sync exchanges operations and/or snapshots plus sufficient metadata for deterministic replay
- Snapshot import must be semantically equivalent to replaying its source operations

### 5.2 Supported Operation Types
Household operations:
- `HOUSEHOLD_CREATE`
- `HOUSEHOLD_RENAME`
- `HOUSEHOLD_DELETE`

Member operations:
- `MEMBER_ADD`
- `MEMBER_RENAME`
- `MEMBER_REMOVE`

List operations:
- `LIST_CREATE`
- `LIST_RENAME`
- `LIST_ARCHIVE_SET`
- `LIST_DELETE`
- `LIST_MOVE`

Item operations common:
- `ITEM_CREATE`
- `ITEM_DELETE`
- `ITEM_MOVE`

To-do item operations:
- `TODO_TEXT_SET`
- `TODO_NOTE_SET`
- `TODO_COMPLETED_SET`

Shopping item operations:
- `SHOP_NAME_SET`
- `SHOP_QUANTITY_SET`
- `SHOP_NOTE_SET`
- `SHOP_ACQUIRED_SET`
- `SHOP_CATEGORY_SET`

Optional transport/bootstrap operations:
- `SNAPSHOT_IMPORT` is not a logical shared operation; it is a local ingestion event and must not enter the replicated log

### 5.3 Operation Schema by Type
Each operation shall include the common fields in 4.7 plus payload:

`HOUSEHOLD_CREATE`
- `name`

`HOUSEHOLD_RENAME`
- `name`

`HOUSEHOLD_DELETE`
- empty payload

`MEMBER_ADD`
- `member_id`
- `display_name`

`MEMBER_RENAME`
- `display_name`

`MEMBER_REMOVE`
- empty payload

`LIST_CREATE`
- `list_id`
- `type`
- `name`
- `initial_order_key`

`LIST_RENAME`
- `name`

`LIST_ARCHIVE_SET`
- `archived: boolean`

`LIST_DELETE`
- empty payload

`LIST_MOVE`
- `new_order_key`

`ITEM_CREATE`
- `item_id`
- fields required by parent list type
- `initial_order_key`

`ITEM_DELETE`
- empty payload

`ITEM_MOVE`
- `new_order_key`

`TODO_TEXT_SET`
- `text`

`TODO_NOTE_SET`
- `note | null`

`TODO_COMPLETED_SET`
- `completed: boolean`

`SHOP_NAME_SET`
- `name`

`SHOP_QUANTITY_SET`
- `quantity_text | null`

`SHOP_NOTE_SET`
- `note | null`

`SHOP_ACQUIRED_SET`
- `acquired: boolean`

`SHOP_CATEGORY_SET`
- `category | null`

### 5.4 Operation Validity Rules
An operation is valid only if:
- `household_id` exists or is created by the operation itself
- Referenced parent entities exist or can be resolved through valid prior/current operation set
- `actor_device_id` belongs to the stated member for that household, unless joining/bootstrap rules explicitly allow otherwise
- Payload conforms to schema
- Primary text fields are non-empty after trimming when required
- `lamport_ts` is greater than any previously emitted timestamp by the same device

If invalid:
- The operation must be rejected
- Rejection must not corrupt local state
- Rejected operations must not be forwarded as accepted state

### 5.5 Idempotency Rules
The system shall ensure:
- Applying an operation with an already-known `op_id` has no effect
- Applying the same logical content with a different `op_id` is treated as a distinct operation unless semantic constraints reject it
- Reprocessing a snapshot and then receiving underlying operations must not change state if snapshot metadata proves coverage

### 5.6 Ordering Rules
The system shall distinguish:
- Causal order for replay safety
- Conflict resolution order for concurrent writes
- Presentation order for lists/items

Rules:
- Operations may be received in any order
- Replay must produce the same final state regardless of receive order
- A deterministic total order for tie-breaking shall be defined as:
  1. Higher effective logical timestamp wins where LWW applies
  2. If equal, compare `actor_device_id` lexicographically
  3. If still equal, compare `op_id` lexicographically

This total order must be used consistently on all devices.

### 5.7 Tombstones
The model shall use tombstones for deletions.
Rules:
- `LIST_DELETE` creates a list tombstone
- `ITEM_DELETE` creates an item tombstone
- Once tombstoned, an entity is not resurrected by non-create operations
- Tombstones must replicate like all other operations
- Compaction may remove old tombstones only if it preserves the invariant that deleted entities never reappear

## 6. Conflict Resolution Rules

### 6.1 General Principles
Conflict resolution must be:
- Deterministic
- Associative
- Commutative
- Idempotent

### 6.2 Register Fields
The following fields shall use Last-Writer-Wins register semantics under the total order defined in 5.6:
- Household name
- Member display name
- List name
- To-do text
- To-do note
- To-do completed flag
- Shopping name
- Shopping quantity text
- Shopping note
- Shopping acquired flag
- Shopping category
- List archived flag

Rule:
- The winning value is from the highest ordered valid operation targeting that field and entity

### 6.3 Deletes vs Updates
Rule:
- Delete wins over all non-create updates on the same entity
- After an entity is deleted, later field updates do not restore visibility
- A delete does not remove the historical existence of the entity ID; it marks it tombstoned

Special case:
- Concurrent `ITEM_CREATE` and `ITEM_DELETE` for the same `item_id` are resolved by total order if they originate from malformed duplication; valid systems should not emit such a case except under corruption recovery

### 6.4 Parent Delete Dominance
Rules:
- If a list is deleted, all child items are effectively non-visible regardless of their individual item state
- Child operations may still be stored historically but have no visible effect while parent delete is in force
- Item delete tombstones remain meaningful if the list is later restored only if restore is a supported operation; in this spec list restore after delete is not supported, only unarchive after archive is supported

### 6.5 Move/Reorder Conflicts
List and item order shall be represented using a deterministic sequence CRDT order key.
Rules:
- Concurrent moves resolve by order key comparison after all move operations are applied
- If two entities have equal resulting order key, tie-break by entity ID lexicographically
- A move targeting a deleted entity has no visible effect
- A move of an item whose parent list differs from local inferred parent is invalid unless cross-list move is explicitly added; this spec does not support cross-list move

### 6.6 Concurrent Create Duplicates
Rule:
- Two users creating conceptually similar items independently produce two distinct items unless they share the same `item_id`
- The system shall not attempt semantic deduplication based on text similarity
- “No duplicate items” in invariants refers to duplicate entity identity, not duplicate human-readable content

### 6.7 Member Conflicts
Rules:
- Concurrent member renames use LWW
- Member removal wins over later non-membership metadata updates
- Historical authorship remains preserved even if a member is removed

## 7. Sync Requirements

### 7.1 Supported Transport Classes
The system shall support one or more of the following transport classes:
- Local network peer-to-peer
- Bluetooth peer-to-peer
- QR code / manual invitation bootstrap
- File export/import
- Nearby-device OS-native sharing mechanisms

This spec is transport-agnostic at the replication layer.

### 7.2 Common Sync Behavior
For any transport, sync shall:
- Authenticate household identity and peer compatibility
- Exchange replica summaries before full transfer where supported
- Transfer only missing operations when possible
- Permit full snapshot plus delta transfer for bootstrap optimization
- Be resumable by simple retry without corruption
- Never require one device to be permanently online

### 7.3 Sync Session Phases
A sync session shall conceptually perform:
1. Peer discovery or explicit peer selection
2. Capability/version negotiation
3. Household selection and authorization
4. Replica summary exchange
5. Missing operation and/or snapshot transfer
6. Integrity validation
7. Atomic local apply
8. Acknowledgment and session close

### 7.4 Behavior Per Transport

#### Local Network Peer-to-Peer
Expected behavior:
- May support discovery
- May support larger batch transfer efficiently
- Must tolerate disconnects and retries
- Must not assume stable IPs or persistent reachability

#### Bluetooth Peer-to-Peer
Expected behavior:
- May have smaller payload windows and more interruptions
- Must support chunked transfer
- Must tolerate repeated packet/session duplication
- Must preserve exact semantics of operation exchange

#### QR / Invitation Bootstrap
Expected behavior:
- Used for identity/bootstrap, not full high-volume sync unless payload size allows
- May transfer household ID, peer info, trust token, or compact snapshot seed
- Must be safe to scan multiple times

#### File Export/Import
Expected behavior:
- Export shall produce a self-contained package with schema/protocol version metadata
- Import shall be idempotent
- Importing older data than local known state must not roll back state
- File-based transfer may be used when direct connectivity is unavailable

#### OS-Native Share Flows
Expected behavior:
- The transfer payload must remain verifiable and idempotent
- Interrupted import must not partially apply without validation

### 7.5 Partial Sync
The system shall support:
- Receiving only a subset of missing operations in one session
- Retrying later with no duplication or corruption
- Preserving local validity even if some causal history is delayed

Requirement:
- An operation lacking required dependencies may be staged temporarily but must not become visible until dependencies are satisfied, unless the operation can be safely interpreted independently

### 7.6 Sync Safety
The system shall:
- Validate integrity before commit
- Apply imported operations atomically per batch
- Record progress only after successful durable persistence
- Prevent cross-household contamination of operations

## 8. Failure Scenarios

### 8.1 Device Offline
When a device is offline:
- All local create/edit/delete/reorder actions shall still work
- Operations shall be queued locally
- UI shall clearly indicate unsynced changes if product UX includes status indicators
- No user action shall block waiting for connectivity

### 8.2 Partial Sync
If a sync stops midway:
- Already committed operations remain valid
- Uncommitted transferred data must not affect visible state
- Retrying sync shall continue safely
- Duplicate chunks or repeated sessions must not duplicate state

### 8.3 Conflicting Updates
If two devices edit the same field concurrently:
- Resolution uses the deterministic LWW rule
- Both operations remain in history
- Final visible value must be identical on all devices after convergence

### 8.4 Conflicting Delete and Update
If one device deletes an entity while another edits it:
- Delete wins for visible state
- Edit remains in history but has no visible effect
- Entity shall not reappear after convergence

### 8.5 Device Crash During Local Write
If the app crashes during operation creation:
- Either the operation is fully persisted and later replayed
- Or the operation is absent
- Partial operations must never be visible

### 8.6 Device Crash During Sync Apply
If the app crashes during sync apply:
- On next startup, state must recover to the latest durable committed batch
- Incomplete batches must not be partially visible
- Re-syncing the same data must be safe

### 8.7 Data Corruption
If local storage corruption is detected:
- Corrupted operations must be isolated and rejected if invalid
- Valid operations must still be recoverable where possible
- The device may require household rebootstrap if irrecoverable
- Corruption on one device must not spread as accepted state

### 8.8 Version Mismatch
If two devices have incompatible protocol/schema versions:
- Sync must fail gracefully
- No partial state exchange shall be committed unless compatibility rules explicitly allow downgrade-safe transfer
- The app shall report incompatibility

### 8.9 Member Removal During Sync
If a member is removed while one of their devices is offline:
- That offline device may still hold historical data
- New operations created after effective removal must be rejected by other peers once removal is known
- Previously accepted operations remain valid history

### 8.10 Duplicate Imports
If the same snapshot/export is imported multiple times:
- Final state shall remain unchanged after the first successful import
- Operation log or snapshot coverage metadata must prevent duplication effects

## 9. Invariants

The following invariants must always hold.

### 9.1 Convergence
- Same set of valid operations implies same final materialized state on every device.

### 9.2 Idempotency
- Reapplying an already accepted operation never changes state.

### 9.3 Deterministic Resolution
- Every conflict resolves the same way on every device using only replicated data and deterministic tie-breakers.

### 9.4 Immutable Operations
- Accepted operations are never edited in place.

### 9.5 Unique Identity
- No two distinct live entities share the same entity ID.
- Entity IDs are never reused.

### 9.6 No Identity Duplication
- Sync duplication never creates duplicate entities with the same ID.
- Sync duplication never creates duplicate operations with the same `op_id`.

### 9.7 Delete Finality
- Deleted entities never reappear as the same entity ID.
- Non-create operations cannot resurrect tombstoned entities.

### 9.8 Parent Dominance
- A deleted list has no visible active items.
- Child visibility cannot exceed parent visibility constraints.

### 9.9 Validity Preservation
- Invalid operations are never partially applied.
- Invalid operations never change visible state.

### 9.10 Atomic Persistence
- A locally acknowledged operation has been durably persisted.
- A committed sync batch is durably persisted as an atomic unit.

### 9.11 Monotonic Device Clock Independence
- Correctness does not depend on synchronized wall clocks.
- Real-time timestamps never override logical ordering rules.

### 9.12 Transport Independence
- Transport choice does not affect final converged state.

### 9.13 Order Determinism
- Given the same order keys and entity IDs, list and item presentation order is identical on every device.

### 9.14 Household Isolation
- Operations from one household never affect another household.

### 9.15 Membership Safety
- Only valid household members/devices may produce accepted future operations for that household, subject to locally known membership state and later validation.

### 9.16 Snapshot Equivalence
- Applying a valid snapshot covering a set of operations is semantically equivalent to applying those operations directly.

## 10. Derived State Rules

The following state is derived, not primary:
- Visible lists
- Visible items
- Completion/acquired counts
- Archived views
- Last modified timestamps
- Sync status indicators
- Member/device last seen indicators

Derived state must be recomputable entirely from durable replicated state plus allowed local-only metadata.

## 11. Local-Only Metadata

The following may exist as local-only, non-replicated state:
- UI theme
- Sort/filter preferences
- Whether completed items are collapsed
- Last viewed list
- Per-device diagnostics
- Local notification preferences

Rules:
- Local-only metadata must not affect shared state convergence
- Loss of local-only metadata must not corrupt shared data

## 12. Acceptance Criteria

The specification is satisfied only if the resulting system demonstrates:
- Full offline usability for all primary list actions
- Eventual convergence across devices with no server
- Deterministic conflict resolution
- Idempotent sync and import behavior
- Delete finality via tombstones
- No duplicate entity identity after repeated sync/import
- Stable behavior under interrupted sync and device crashes
- Equivalent final state regardless of operation delivery order

## 13. Explicit Out of Scope

The following are not required by this spec unless later added:
- Central server sync
- User accounts with email/password
- Real-time presence guarantees
- Semantic item deduplication by text similarity
- Cross-list item move
- Undo/redo semantics
- Rich permissions model beyond household membership
- Attachment/file sharing
- Due dates, reminders, or calendars
- End-to-end encryption specifics

## 14. Summary of Architectural Contract

This app is defined as an offline-first, peer-replicated, operation-based CRDT system where:
- every user action becomes an immutable operation,
- deletions are tombstone-based,
- conflicts resolve deterministically,
- replay order does not affect converged state,
- and sync is only a transport for exchanging operations, never the authority over data.
