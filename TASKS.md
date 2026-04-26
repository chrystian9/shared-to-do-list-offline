# TASKS.md

## Phase 1: Project Setup
- [x] Create Flutter package manifest and analysis options
- [x] Create application entrypoints
- [x] Establish folder structure for application, domain, data, sync, and presentation layers

## Phase 2: Core Models and Operation System
- [x] Define IDs, result types, and domain errors
- [x] Define entity and operation enums
- [x] Define CRDT operation schema
- [x] Define materialized state records
- [x] Define local operation factory and Lamport clock
- [x] Define operation validation rules

## Phase 3: CRDT Engine
- [x] Implement deterministic operation ordering
- [x] Implement LWW register merge semantics
- [x] Implement tombstone handling
- [x] Implement parent delete dominance
- [x] Implement rebuild/replay logic with deferred dependency handling
- [x] Add invariant checking
- [x] Add unit tests for determinism, idempotency, and delete dominance

## Phase 4: Local Storage
- [x] Create SQLite schema for operations, snapshots, and local settings
- [x] Implement operation repository
- [x] Implement snapshot repository
- [x] Implement state snapshot serialization
- [x] Wire app service to persistent repositories

## Phase 5: Sync
- [x] Define sync protocol models
- [x] Define transport abstraction
- [x] Implement manual JSON export/import transport
- [x] Support deterministic import into the operation log
- [x] Add import UX feedback (success/error and duplicate/new counts)
- [ ] Add compatibility checks (schema/protocol) at import boundary

## Phase 6: UI
- [x] Bootstrap app dependencies
- [x] Implement household selection and creation flow
- [x] Implement list creation, rename, archive, and delete flows
- [x] Implement item creation, edit, check/uncheck, and delete flows
- [x] Implement import/export dialogs
- [ ] Add clipboard helpers for export/import flow

## Phase 7: Testing and Validation
- [x] Add CRDT unit tests
- [x] Perform static code sanity pass
- [x] Run Flutter and Dart validation when SDK is available
- [ ] Add end-to-end two-device import/export convergence test script

## Phase 8: Wi-Fi Sync (Next)
- [ ] Add LAN transport dependency set and platform permissions
- [ ] Implement peer discovery on local network
- [ ] Implement direct device-to-device session handshake
- [ ] Exchange replica summaries and request missing ops only
- [ ] Implement chunked payload transfer with retry/idempotency
- [ ] Add per-session progress and error states in UI
- [ ] Add two-device Android emulator/manual device validation plan
