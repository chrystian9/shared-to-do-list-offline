# TASKS.md

## Phase 1: Project Setup
- Create Flutter package manifest and analysis options
- Create application entrypoints
- Establish folder structure for application, domain, data, sync, and presentation layers

## Phase 2: Core Models and Operation System
- Define IDs, result types, and domain errors
- Define entity and operation enums
- Define CRDT operation schema
- Define materialized state records
- Define local operation factory and Lamport clock
- Define operation validation rules

## Phase 3: CRDT Engine
- Implement deterministic operation ordering
- Implement LWW register merge semantics
- Implement tombstone handling
- Implement parent delete dominance
- Implement rebuild/replay logic with deferred dependency handling
- Add invariant checking
- Add unit tests for determinism, idempotency, and delete dominance

## Phase 4: Local Storage
- Create SQLite schema for operations, snapshots, and local settings
- Implement operation repository
- Implement snapshot repository
- Implement state snapshot serialization
- Wire app service to persistent repositories

## Phase 5: Sync
- Define sync protocol models
- Define transport abstraction
- Implement manual JSON export/import transport
- Support deterministic import into the operation log

## Phase 6: UI
- Bootstrap app dependencies
- Implement household selection and creation flow
- Implement list creation, rename, archive, and delete flows
- Implement item creation, edit, check/uncheck, and delete flows
- Implement import/export dialogs

## Phase 7: Testing and Validation
- Add CRDT unit tests
- Perform static code sanity pass
- Run Flutter and Dart validation when SDK is available
