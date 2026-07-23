import 'dart:io';

import 'package:clean_architect/clean_architect.dart';
import 'package:clean_architect/src/cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory previousDirectory;
  late Directory project;

  setUp(() {
    previousDirectory = Directory.current;
    project = Directory.systemTemp.createTempSync(
      'clean_architect_data_layout_',
    );
    Directory.current = project;
    exitCode = 0;
  });

  tearDown(() {
    Directory.current = previousDirectory;
    if (project.existsSync()) project.deleteSync(recursive: true);
    exitCode = 0;
  });

  test('source_first remains the default and type_first parses from YAML', () {
    expect(CleanArchitectConfig.defaults().dataLayout, DataLayout.sourceFirst);

    File(CleanArchitectConfig.fileName).writeAsStringSync('''
clean_architect:
  data_layout: type_first
''');

    final config = CleanArchitectConfig.fromFile(
      File(CleanArchitectConfig.fileName),
    );
    expect(config.dataLayout, DataLayout.typeFirst);
    expect(config.dataLayoutName, 'type_first');
  });

  test('type_first separates models from data sources in every template', () {
    final generator = CleanArchitectGenerator(_typeFirstConfig());
    final architecture = _paths(generator.architecture());
    final feature = generator.feature('orders');
    final featurePaths = _paths(feature);
    final auth = generator.auth();
    final authPaths = _paths(auth);

    expect(
      architecture,
      contains(
        p.join(
          'data',
          'lib',
          'features',
          'base_feature',
          'data_sources',
          'remote',
          '.gitkeep',
        ),
      ),
    );
    expect(
      architecture,
      contains(
        p.join(
          'data',
          'lib',
          'features',
          'base_feature',
          'models',
          'local',
          '.gitkeep',
        ),
      ),
    );
    expect(
      featurePaths,
      contains(
        p.join(
          'data',
          'lib',
          'features',
          'orders',
          'data_sources',
          'remote',
          'orders_remote_data_source.dart',
        ),
      ),
    );
    expect(
      featurePaths,
      contains(
        p.join(
          'data',
          'lib',
          'features',
          'orders',
          'models',
          'remote',
          'orders_dto.dart',
        ),
      ),
    );
    expect(
      featurePaths,
      isNot(
        contains(
          p.join(
            'data',
            'lib',
            'features',
            'orders',
            'remote',
            'models',
            'orders_dto.dart',
          ),
        ),
      ),
    );
    expect(
      _content(feature, 'orders_remote_data_source.dart'),
      contains("import '../../models/remote/orders_dto.dart';"),
    );
    expect(
      _content(feature, 'orders_local_data_source.dart'),
      contains("import '../../models/local/orders_box.dart';"),
    );
    expect(
      _content(feature, 'orders_mapper.dart'),
      contains("import '../models/remote/orders_dto.dart';"),
    );
    expect(
      _content(feature, 'orders_repository_impl.dart'),
      contains(
        "import '../data_sources/remote/orders_remote_data_source.dart';",
      ),
    );
    expect(
      _content(feature, 'orders_di.dart'),
      contains(
        'package:data/features/orders/data_sources/local/'
        'orders_local_data_source.dart',
      ),
    );

    expect(
      authPaths,
      contains(
        p.join(
          'data',
          'lib',
          'features',
          'auth',
          'models',
          'remote',
          'auth_token_dto.dart',
        ),
      ),
    );
    expect(
      _content(auth, 'auth_remote_data_source.dart'),
      contains("import '../../models/remote/auth_token_dto.dart';"),
    );
    expect(
      _content(auth, 'auth_repository_impl.dart'),
      contains("import '../data_sources/local/auth_local_data_source.dart';"),
    );
  });

  test(
    'type_first operation commands patch the selected paths idempotently',
    () {
      File(CleanArchitectConfig.fileName).writeAsStringSync(_typeFirstYaml());
      final cli = CleanArchitectCli();

      cli.run(['create', 'feature', 'orders', '--no-flutter-create']);
      cli.run([
        'create',
        'cached-function',
        'syncCatalog',
        '--feature',
        'orders',
      ]);
      cli.run(['create', 'repository', 'billing']);
      expect(exitCode, 0);

      final remoteSource = File(
        p.join(
          'data',
          'lib',
          'features',
          'orders',
          'data_sources',
          'remote',
          'orders_remote_data_source.dart',
        ),
      );
      final localSource = File(
        p.join(
          'data',
          'lib',
          'features',
          'orders',
          'data_sources',
          'local',
          'orders_local_data_source.dart',
        ),
      );
      final dataModule = File(
        p.join('data', 'lib', 'data_module.dart'),
      ).readAsStringSync();

      expect(
        remoteSource.readAsStringSync(),
        contains("import '../../models/remote/sync_catalog_dto.dart';"),
      );
      expect(
        localSource.readAsStringSync(),
        contains("import '../../models/local/sync_catalog_box.dart';"),
      );
      expect(
        dataModule,
        contains(
          "import 'features/orders/models/local/sync_catalog_box.dart';",
        ),
      );
      expect(dataModule, isNot(contains('BillingBox')));
      expect(dataModule, isNot(contains('billing_box.dart')));
      expect(
        File(
          p.join(
            'data',
            'lib',
            'features',
            'orders',
            'models',
            'local',
            'sync_catalog_box.dart',
          ),
        ).existsSync(),
        isTrue,
      );

      final before = _snapshot(project);
      cli.run([
        'create',
        'cached-function',
        'syncCatalog',
        '--feature',
        'orders',
      ]);
      expect(exitCode, 0);
      expect(_snapshot(project), before);
    },
  );
}

CleanArchitectConfig _typeFirstConfig() {
  final defaults = CleanArchitectConfig.defaults();
  return CleanArchitectConfig(
    structure: defaults.structure,
    dataLayout: DataLayout.typeFirst,
    stateManagement: defaults.stateManagement,
    network: defaults.network,
    localStorage: defaults.localStorage,
    dependencyInjection: defaults.dependencyInjection,
    models: defaults.models,
    paths: defaults.paths,
    useAssetGenerator: defaults.useAssetGenerator,
    useEitherFailure: defaults.useEitherFailure,
    flutter: defaults.flutter,
  );
}

String _typeFirstYaml() {
  return '''
clean_architect:
  config_version: 1
  structure: layered_packages
  data_layout: type_first
  state_management: none
  network: dio
  local_storage: hive
  dependency_injection: injectable
  use_asset_generator: false
  use_either_failure: false
  flutter:
    create_presentation: false
    platforms: [android, ios]
  models:
    use_freezed: false
    use_json_serializable: false
  paths:
    domain: domain/lib
    data: data/lib/features
    presentation: presentation/lib
    di: di/lib
''';
}

Set<String> _paths(List<GeneratedFile> files) {
  return files.map((file) => p.normalize(file.path)).toSet();
}

String _content(List<GeneratedFile> files, String fileName) {
  return files.singleWhere((file) => p.basename(file.path) == fileName).content;
}

Map<String, String> _snapshot(Directory root) {
  final files = root.listSync(recursive: true).whereType<File>().toList()
    ..sort((left, right) => left.path.compareTo(right.path));
  return {
    for (final file in files)
      p.relative(file.path, from: root.path): file.readAsStringSync(),
  };
}
