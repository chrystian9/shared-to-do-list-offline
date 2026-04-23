enum EntityType {
  household,
  member,
  list,
  item,
}

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

enum ListType {
  todo,
  shopping,
}
