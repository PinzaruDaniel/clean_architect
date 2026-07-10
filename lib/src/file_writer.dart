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

  void writeAll(List<GeneratedFile> files) {
    for (final file in files) {
      final target = File(file.path);

      if (dryRun) {
        logger.info('create ${file.path}');
        continue;
      }

      if (target.existsSync() && !overwrite) {
        logger.warn('skip ${file.path} already exists');
        continue;
      }

      target.parent.createSync(recursive: true);
      target.writeAsStringSync(_withTrailingNewline(file.content));
      logger
          .success('${target.existsSync() ? 'wrote' : 'created'} ${file.path}');
    }
  }

  bool hasConflicts(List<GeneratedFile> files) {
    return files.any((file) => File(p.normalize(file.path)).existsSync());
  }
}

String _withTrailingNewline(String content) {
  return content.endsWith('\n') ? content : '$content\n';
}
