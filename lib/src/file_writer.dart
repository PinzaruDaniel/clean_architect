import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import 'generated_file.dart';

class FileWriter {
  const FileWriter({
    required this.logger,
    required this.dryRun,
    required this.overwrite,
  });

  final Logger logger;
  final bool dryRun;
  final bool overwrite;

  bool writeAll(List<GeneratedFile> files) {
    final plan = _preflight(files);
    if (plan == null) return false;

    for (final change in plan) {
      if (dryRun) {
        logger.info(
          '${change.exists ? 'update' : 'create'} ${change.file.path}',
        );
        continue;
      }

      final target = File(change.file.path);
      target.parent.createSync(recursive: true);
      target.writeAsStringSync(_withTrailingNewline(change.file.content));
      logger.success(
        '${change.exists ? 'updated' : 'created'} ${change.file.path}',
      );
    }
    return true;
  }

  bool hasConflicts(List<GeneratedFile> files) => _preflight(files) == null;

  List<_PlannedWrite>? _preflight(List<GeneratedFile> files) {
    final byPath = <String, GeneratedFile>{};
    final duplicateConflicts = <String>[];

    for (final file in files) {
      final path = p.normalize(file.path);
      final normalized = GeneratedFile(
        path: path,
        content: file.content,
        skipIfExists: file.skipIfExists,
        allowUpdate: file.allowUpdate,
      );
      final previous = byPath[path];
      if (previous == null) {
        byPath[path] = normalized;
        continue;
      }
      if (_withTrailingNewline(previous.content) ==
          _withTrailingNewline(normalized.content)) {
        byPath[path] = GeneratedFile(
          path: path,
          content: normalized.content,
          skipIfExists: previous.skipIfExists && normalized.skipIfExists,
          allowUpdate: previous.allowUpdate || normalized.allowUpdate,
        );
        continue;
      }
      if (previous.allowUpdate != normalized.allowUpdate) {
        byPath[path] = previous.allowUpdate ? previous : normalized;
        continue;
      }
      if (previous.skipIfExists != normalized.skipIfExists) {
        byPath[path] = previous.skipIfExists ? normalized : previous;
        continue;
      }
      duplicateConflicts.add(path);
    }

    final conflicts = <String>[...duplicateConflicts];
    final plan = <_PlannedWrite>[];
    for (final file in byPath.values) {
      final target = File(file.path);
      final exists = target.existsSync();
      if (!exists) {
        plan.add(_PlannedWrite(file, exists: false));
        continue;
      }

      final current = target.readAsStringSync();
      if (_withTrailingNewline(current) == _withTrailingNewline(file.content)) {
        continue;
      }
      if (file.skipIfExists) {
        logger.warn('skip ${file.path} already exists');
        continue;
      }
      if (file.allowUpdate) {
        plan.add(_PlannedWrite(file, exists: true));
        continue;
      }
      if (!overwrite) {
        conflicts.add(file.path);
        continue;
      }
      plan.add(_PlannedWrite(file, exists: true));
    }

    if (conflicts.isNotEmpty) {
      logger.err('Generation aborted. Conflicting files:');
      for (final path in conflicts.toSet()) {
        logger.err('  $path');
      }
      logger.info('Use --force or --overwrite to replace conflicting files.');
      return null;
    }

    return plan;
  }
}

class _PlannedWrite {
  const _PlannedWrite(this.file, {required this.exists});

  final GeneratedFile file;
  final bool exists;
}

String _withTrailingNewline(String content) {
  return content.endsWith('\n') ? content : '$content\n';
}
