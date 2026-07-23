import 'dart:io';

import 'package:clean_architect/src/cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory previousDirectory;
  late Directory project;

  setUp(() {
    previousDirectory = Directory.current;
    project = Directory.systemTemp.createTempSync(
      'clean_architect_all_commands_',
    );
    Directory.current = project;
    exitCode = 0;
  });

  tearDown(() {
    Directory.current = previousDirectory;
    if (project.existsSync()) project.deleteSync(recursive: true);
    exitCode = 0;
  });

  test('every supported command is safe to rerun', () {
    final cli = CleanArchitectCli();
    final commands = <List<String>>[
      ['create', 'architecture', '--no-flutter-create'],
      ['create', 'auth', '--no-flutter-create'],
      ['create', 'feature', 'orders', '--no-flutter-create'],
      ['create', 'usecase', 'refreshSession', '--feature', 'orders'],
      ['create', 'repository', 'billing'],
      ['create', 'remote-function', 'fetchReceipt', '--feature', 'orders'],
      ['create', 'local-function', 'readDraft', '--feature', 'orders'],
      ['create', 'cached-function', 'syncCatalog', '--feature', 'orders'],
    ];

    cli.run(['init']);
    expect(exitCode, 0);
    for (final command in commands) {
      cli.run(command);
      expect(
        exitCode,
        0,
        reason: 'Initial command failed: ${command.join(' ')}',
      );
    }

    final before = _snapshot(project);

    cli.run(['init']);
    expect(exitCode, 0);
    for (final command in commands) {
      cli.run(command);
      expect(exitCode, 0, reason: 'Rerun failed: ${command.join(' ')}');
    }

    final aliases = <List<String>>[
      ['create', 'base', '--no-flutter-create'],
      ['create', 'feature', 'orders', '--di', 'manual', '--no-flutter-create'],
      ['create', 'remote-method', 'fetchReceipt', '--feature', 'orders'],
      ['create', 'local-method', 'readDraft', '--feature', 'orders'],
      ['create', 'cached-method', 'syncCatalog', '--feature', 'orders'],
    ];
    for (final command in aliases) {
      cli.run(command);
      expect(exitCode, 0, reason: 'Alias failed: ${command.join(' ')}');
    }

    expect(_snapshot(project), before);

    cli.run(['doctor']);
    expect(exitCode, 1);
    expect(_snapshot(project), before);
  });
}

Map<String, ({String content, int modified})> _snapshot(Directory root) {
  final files = root.listSync(recursive: true).whereType<File>().toList()
    ..sort((left, right) => left.path.compareTo(right.path));

  return {
    for (final file in files)
      p.relative(file.path, from: root.path): (
        content: file.readAsStringSync(),
        modified: file.lastModifiedSync().microsecondsSinceEpoch,
      ),
  };
}
