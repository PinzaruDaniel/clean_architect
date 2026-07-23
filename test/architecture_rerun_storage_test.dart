import 'dart:io';

import 'package:clean_architect/src/cli.dart';
import 'package:clean_architect/src/config.dart';
import 'package:test/test.dart';

void main() {
  late Directory previousDirectory;
  late Directory project;

  setUp(() {
    previousDirectory = Directory.current;
    project = Directory.systemTemp.createTempSync(
      'clean_architect_architecture_rerun_',
    );
    Directory.current = project;
    exitCode = 0;
  });

  tearDown(() {
    Directory.current = previousDirectory;
    if (project.existsSync()) project.deleteSync(recursive: true);
    exitCode = 0;
  });

  test('architecture rerun does not register a base feature box', () {
    File(CleanArchitectConfig.fileName).writeAsStringSync('''
clean_architect:
  structure: layered_packages
  state_management: none
  network: abstract
  local_storage: hive
  dependency_injection: injectable
  use_asset_generator: false
  use_either_failure: false
  flutter:
    create_presentation: false
    platforms: []
  models:
    use_freezed: false
    use_json_serializable: false
  paths:
    domain: domain/lib
    data: data/lib/features
    presentation: presentation/lib
    di: di/lib
''');

    final cli = CleanArchitectCli();
    cli.run(['create', 'architecture', '--skip-presentation']);
    cli.run(['create', 'feature', 'orders', '--skip-presentation']);
    expect(exitCode, 0);

    final module = File('data/lib/data_module.dart');
    final before = module.readAsStringSync();

    cli.run(['create', 'architecture', '--skip-presentation']);

    expect(exitCode, 0);
    expect(module.readAsStringSync(), before);
    expect(before, isNot(contains('BaseFeatureBox')));
    expect(
      File(
        'data/lib/features/base_feature/local/models/base_feature_box.dart',
      ).existsSync(),
      isFalse,
    );
  });
}
