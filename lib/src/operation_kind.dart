enum OperationKind {
  remote,
  local,
  cached;

  bool get includesRemote => this == remote || this == cached;
  bool get includesLocal => this == local || this == cached;
}
