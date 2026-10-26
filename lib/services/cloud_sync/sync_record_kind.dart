/// Kinds of records tracked by the cloud-sync bookkeeping collections.
///
/// Lives in its own leaf file so both the Isar schema (`global_db.dart`) and
/// the pure sync models can reference it without creating a dependency
/// between them.
enum SyncRecordKind {
  playlist,
  entry,
  favourite,
  setting,
}
