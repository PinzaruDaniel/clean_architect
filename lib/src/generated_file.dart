class GeneratedFile {
  const GeneratedFile({
    required this.path,
    required this.content,
    this.skipIfExists = false,
    this.allowUpdate = false,
  });

  final String path;
  final String content;
  final bool skipIfExists;
  final bool allowUpdate;
}
