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
    project = Directory.systemTemp.createTempSync('clean_architect_vertical_');
    Directory.current = project;
    exitCode = 0;
  });

  tearDown(() {
    Directory.current = previousDirectory;
    if (project.existsSync()) project.deleteSync(recursive: true);
    exitCode = 0;
  });

  test('resolves every layer inside one vertical feature package', () {
    final paths = PathResolver(_config()).resolve('user_profile');

    expect(
      paths.domain,
      p.join('packages', 'features', 'user_profile', 'lib', 'src', 'domain'),
    );
    expect(
      paths.data,
      p.join('packages', 'features', 'user_profile', 'lib', 'src', 'data'),
    );
    expect(
      paths.presentation,
      p.join(
        'packages',
        'features',
        'user_profile',
        'lib',
        'src',
        'presentation',
      ),
    );
    expect(
      paths.di,
      p.join('packages', 'features', 'user_profile', 'lib', 'src', 'di'),
    );
  });

  test(
    'architecture creates a runnable app, core, and base feature package',
    () {
      final files = CleanArchitectGenerator(_config()).architecture();
      final paths = files.map((file) => p.normalize(file.path)).toSet();

      expect(paths, contains(p.join('app', 'pubspec.yaml')));
      expect(paths, contains(p.join('app', 'lib', 'main.dart')));
      expect(paths, contains(p.join('app', 'lib', 'app.dart')));
      expect(paths, contains(p.join('app', 'test', 'app_smoke_test.dart')));
      expect(paths, contains(p.join('packages', 'core', 'pubspec.yaml')));
      expect(paths, contains(p.join('packages', 'core', 'lib', 'core.dart')));
      expect(
        paths,
        contains(
          p.join('packages', 'features', 'base_feature', 'pubspec.yaml'),
        ),
      );
      expect(
        paths,
        contains(
          p.join(
            'packages',
            'features',
            'base_feature',
            'lib',
            'src',
            'domain',
            'entities',
            '.gitkeep',
          ),
        ),
      );
      expect(
        paths,
        contains(
          p.join(
            'packages',
            'features',
            'base_feature',
            'lib',
            'src',
            'data',
            'data_sources',
            'remote',
            '.gitkeep',
          ),
        ),
      );
    },
  );

  test('CLI updates app and feature DI idempotently', () {
    File(CleanArchitectConfig.fileName).writeAsStringSync(_yaml());
    final cli = CleanArchitectCli();

    cli.run(['create', 'architecture', '--no-flutter-create']);
    cli.run(['create', 'feature', 'orders', '--no-flutter-create']);
    cli.run(['create', 'auth', '--no-flutter-create']);
    cli.run([
      'create',
      'cached-function',
      'syncCatalog',
      '--feature',
      'orders',
    ]);
    expect(exitCode, 0);

    final appPubspec = File(p.join('app', 'pubspec.yaml')).readAsStringSync();
    expect('  base_feature:'.allMatches(appPubspec), hasLength(1));
    expect('  orders:'.allMatches(appPubspec), hasLength(1));
    expect('  auth:'.allMatches(appPubspec), hasLength(1));
    expect(appPubspec, contains('path: ../packages/features/orders'));

    final ordersRoot = p.join('packages', 'features', 'orders');
    expect(File(p.join(ordersRoot, 'pubspec.yaml')).existsSync(), isTrue);
    expect(
      File(
        p.join(
          ordersRoot,
          'lib',
          'src',
          'domain',
          'entities',
          'orders_entity.dart',
        ),
      ).existsSync(),
      isTrue,
    );
    final dataModule = File(
      p.join(ordersRoot, 'lib', 'src', 'di', 'data_module.dart'),
    ).readAsStringSync();
    expect(dataModule, contains("../data/models/local/orders_box.dart"));
    expect(dataModule, contains("../data/models/local/sync_catalog_box.dart"));
    expect(dataModule, contains('Future<Box<OrdersBox>> ordersBox()'));
    expect(
      dataModule,
      contains('Future<Box<SyncCatalogBox>> syncCatalogBox()'),
    );
    final ordersLibrary = File(
      p.join(ordersRoot, 'lib', 'orders.dart'),
    ).readAsStringSync();
    expect(
      ordersLibrary,
      contains("export 'src/presentation/pages/orders_page.dart';"),
    );
    expect(
      ordersLibrary,
      contains("export 'src/domain/usecases/sync_catalog_use_case.dart';"),
    );
    expect(
      ordersLibrary,
      contains("export 'src/domain/usecases/stream_catalog_use_case.dart';"),
    );
    final authLibrary = File(
      p.join('packages', 'features', 'auth', 'lib', 'auth.dart'),
    ).readAsStringSync();
    expect(
      authLibrary,
      contains("export 'src/presentation/pages/login_page.dart';"),
    );

    final before = _snapshot(project);
    cli.run(['create', 'feature', 'orders', '--no-flutter-create']);
    cli.run([
      'create',
      'cached-function',
      'syncCatalog',
      '--feature',
      'orders',
    ]);
    expect(exitCode, 0);
    expect(_snapshot(project), before);
  });
}

CleanArchitectConfig _config() {
  return const CleanArchitectConfig(
    structure: ProjectStructure.verticalPackages,
    dataLayout: DataLayout.typeFirst,
    stateManagement: StateManagement.bloc,
    network: NetworkClient.dio,
    localStorage: LocalStorage.hive,
    dependencyInjection: DependencyInjection.injectable,
    models: ModelConfig(useFreezed: true, useJsonSerializable: true),
    paths: PathConfig(
      domain: 'domain/lib',
      data: 'data/lib/features',
      presentation: 'presentation/lib',
      di: 'di/lib',
      app: 'app/lib',
      core: 'packages/core/lib',
      features: 'packages/features',
    ),
    useAssetGenerator: false,
    useEitherFailure: true,
    flutter: FlutterConfig(
      createPresentation: false,
      platforms: ['android', 'ios'],
    ),
  );
}

String _yaml() {
  return '''
clean_architect:
  config_version: 1
  structure: vertical_packages
  data_layout: type_first
  state_management: bloc
  network: dio
  local_storage: hive
  dependency_injection: injectable
  use_asset_generator: false
  use_either_failure: true
  flutter:
    create_presentation: false
    platforms: [android, ios]
  models:
    use_freezed: true
    use_json_serializable: true
  paths:
    app: app/lib
    core: packages/core/lib
    features: packages/features
''';
}

Map<String, String> _snapshot(Directory root) {
  final files = root.listSync(recursive: true).whereType<File>().toList()
    ..sort((left, right) => left.path.compareTo(right.path));
  return {
    for (final file in files)
      p.relative(file.path, from: root.path): file.readAsStringSync(),
  };
}
