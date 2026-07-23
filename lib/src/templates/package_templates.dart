import 'package:path/path.dart' as p;

import '../case_utils.dart';
import '../config.dart';
import '../generated_file.dart';
import '../generator.dart';

const _sdkConstraint = '^3.11.0';
const _flutterConstraint = '>=3.27.0';
const _buildRunnerVersion = '^2.15.1';
const _freezedVersion = '^3.2.5';
const _freezedAnnotationVersion = '^3.1.0';
const _jsonAnnotationVersion = '^4.12.0';
const _jsonSerializableVersion = '^6.14.0';
const _injectableVersion = '^3.0.0';
const _injectableGeneratorVersion = '^3.0.2';
const _getItVersion = '^9.2.1';

List<GeneratedFile> packageTemplates(
  TemplateContext context, {
  required bool includePresentation,
  bool includeDataModule = true,
}) {
  final files = <GeneratedFile>[
    GeneratedFile(
      path: p.join(_packageRoot(context.paths.domain), 'pubspec.yaml'),
      content: _domainPubspec(context),
    ),
    GeneratedFile(
      path: p.join(_packageRoot(context.paths.data), 'pubspec.yaml'),
      content: _dataPubspec(context),
    ),
    GeneratedFile(
      path: p.join(_packageRoot(context.paths.di), 'pubspec.yaml'),
      content: _diPubspec(context),
    ),
    ..._injectableFiles(context),
    if (includeDataModule) ..._dataModuleFiles(context),
  ];

  if (includePresentation) {
    files.addAll([
      GeneratedFile(
        path: p.join(_packageRoot(context.paths.presentation), 'pubspec.yaml'),
        content: _presentationPubspec(context),
      ),
      GeneratedFile(
        path: p.join(
          _packageRoot(context.paths.presentation),
          'assets',
          'images',
          '.gitkeep',
        ),
        content: '',
      ),
      GeneratedFile(
        path: p.join(
          _packageRoot(context.paths.presentation),
          'assets',
          'icons',
          '.gitkeep',
        ),
        content: '',
      ),
      GeneratedFile(
        path: p.join(
          _packageRoot(context.paths.presentation),
          'lib',
          'main.dart',
        ),
        content: _presentationMain(),
      ),
      GeneratedFile(
        path: p.join(
          _packageRoot(context.paths.presentation),
          'lib',
          'widgets',
          '.gitkeep',
        ),
        content: '',
      ),
      GeneratedFile(
        path: p.join(
          _packageRoot(context.paths.presentation),
          'lib',
          'pages',
          '.gitkeep',
        ),
        content: '',
      ),
      GeneratedFile(
        path: p.join(
          _packageRoot(context.paths.presentation),
          'lib',
          'utils',
          '.gitkeep',
        ),
        content: '',
      ),
      GeneratedFile(
        path: p.join(
          _packageRoot(context.paths.presentation),
          'lib',
          'controllers',
          '.gitkeep',
        ),
        content: '',
      ),
      GeneratedFile(
        path: p.join(
          _packageRoot(context.paths.presentation),
          'lib',
          'constants',
          '.gitkeep',
        ),
        content: '',
      ),
      GeneratedFile(
        path: p.join(
          _packageRoot(context.paths.presentation),
          'analysis_options.yaml',
        ),
        content: '''
include: package:flutter_lints/flutter.yaml
''',
      ),
    ]);
    if (context.config.useAssetGenerator) {
      files.add(
        GeneratedFile(
          path: p.join(
            _packageRoot(context.paths.presentation),
            'asset_generator_kit.yaml',
          ),
          content: _assetGeneratorKit(),
        ),
      );
    }
  }

  return files
      .map(
        (file) => GeneratedFile(
          path: file.path,
          content: file.content,
          skipIfExists: true,
        ),
      )
      .toList(growable: false);
}

List<GeneratedFile> _dataModuleFiles(TemplateContext context) {
  if (context.config.dependencyInjection != DependencyInjection.injectable) {
    return const [];
  }
  if (context.config.network != NetworkClient.dio &&
      context.config.localStorage != LocalStorage.hive &&
      context.config.localStorage != LocalStorage.objectbox &&
      context.config.localStorage != LocalStorage.sharedPreferences) {
    return const [];
  }

  return [
    GeneratedFile(
      path: p.join(_packageRoot(context.paths.data), 'lib', 'data_module.dart'),
      content: _dataModule(context),
    ),
  ];
}

String _dataModule(TemplateContext context) {
  final imports = <String>[
    "import 'package:injectable/injectable.dart';",
    if (context.config.network == NetworkClient.dio)
      "import 'package:dio/dio.dart';",
    if (context.config.localStorage == LocalStorage.hive)
      "import 'package:hive_ce_flutter/hive_flutter.dart';",
    if (context.config.localStorage == LocalStorage.objectbox)
      "import 'package:path/path.dart' as p;",
    if (context.config.localStorage == LocalStorage.objectbox)
      "import 'package:path_provider/path_provider.dart';",
    if (context.config.localStorage == LocalStorage.sharedPreferences)
      "import 'package:shared_preferences/shared_preferences.dart';",
    if (context.config.localStorage == LocalStorage.hive ||
        context.config.localStorage == LocalStorage.objectbox)
      "import 'features/${context.cases.snake}/local/models/${context.cases.snake}_box.dart';",
    if (context.config.localStorage == LocalStorage.objectbox)
      "import 'objectbox.g.dart';",
  ];
  final body = <String>[
    if (context.config.network == NetworkClient.dio) _dioProviders(),
    if (context.config.localStorage == LocalStorage.sharedPreferences)
      _sharedPreferencesProvider(),
    if (context.config.localStorage == LocalStorage.hive)
      _hiveProviders(context),
    if (context.config.localStorage == LocalStorage.objectbox)
      _objectBoxProviders(context),
  ].where((item) => item.trim().isNotEmpty).join('\n');

  return '''
${imports.toSet().join('\n')}

@module
abstract class DataModule {
$body
}
''';
}

String _dioProviders() {
  return '''
  @Named('auth_dio')
  @lazySingleton
  Dio authDio() {
    return Dio(BaseOptions(baseUrl: ''));
  }

  @Named('main_dio')
  @lazySingleton
  Dio mainDio() {
    return Dio(BaseOptions(baseUrl: ''));
  }
''';
}

String _sharedPreferencesProvider() {
  return '''
  @lazySingleton
  @preResolve
  Future<SharedPreferences> sharedPreferences() {
    return SharedPreferences.getInstance();
  }
''';
}

String _hiveProviders(TemplateContext context) {
  final boxClass = '${context.cases.pascal}Box';
  final boxName = '${context.cases.camel}Box';
  final typeId = stableHiveTypeId(context.cases.snake);
  return '''
  @lazySingleton
  @preResolve
  Future<Box<$boxClass>> $boxName() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered($typeId)) {
      Hive.registerAdapter(${boxClass}Adapter());
    }
    return Hive.openBox<$boxClass>('${context.cases.snake}_box');
  }
''';
}

String _objectBoxProviders(TemplateContext context) {
  final boxClass = '${context.cases.pascal}Box';
  final boxName = '${context.cases.camel}Box';
  return '''
  @lazySingleton
  @factoryMethod
  @preResolve
  Future<Store> asyncCreateStore() async {
    final directory = await getApplicationDocumentsDirectory();
    return openStore(directory: p.join(directory.path, 'objectbox'));
  }

  @lazySingleton
  Box<$boxClass> $boxName(Store store) => Box<$boxClass>(store);
''';
}

List<GeneratedFile> _injectableFiles(TemplateContext context) {
  if (context.config.dependencyInjection != DependencyInjection.injectable) {
    return const [];
  }

  return [
    GeneratedFile(
      path: p.join(_packageRoot(context.paths.domain), 'lib', 'injector.dart'),
      content: '''
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'injector.config.dart';

@InjectableInit()
void configureDependencies(GetIt get) => get.init();
''',
    ),
    GeneratedFile(
      path: p.join(_packageRoot(context.paths.data), 'lib', 'injector.dart'),
      content: '''
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'injector.config.dart';

@InjectableInit()
Future<void> configureDependencies(GetIt get) async {
  await get.init();
}
''',
    ),
    GeneratedFile(
      path: p.join(_packageRoot(context.paths.di), 'lib', 'di.dart'),
      content: '''
import 'package:data/injector.dart' as data;
import 'package:domain/injector.dart' as domain;
import 'package:get_it/get_it.dart';

Future<void> initDi({required GetIt get}) async {
  await data.configureDependencies(get);
  domain.configureDependencies(get);
}
''',
    ),
  ];
}

String _domainPubspec(TemplateContext context) {
  final dependencies = <String>[];
  final devDependencies = <String>[];
  if (context.config.useEitherFailure) {
    dependencies.add('  dartz: ^0.10.1');
  }
  if (context.config.models.useFreezed) {
    dependencies.add('  freezed_annotation: $_freezedAnnotationVersion');
    devDependencies.add('  build_runner: $_buildRunnerVersion');
    devDependencies.add('  freezed: $_freezedVersion');
  }
  if (context.config.dependencyInjection == DependencyInjection.injectable) {
    dependencies.add('  injectable: $_injectableVersion');
    dependencies.add('  get_it: $_getItVersion');
    devDependencies.add('  build_runner: $_buildRunnerVersion');
    devDependencies.add('  injectable_generator: $_injectableGeneratorVersion');
  }

  return '''
name: ${_packageName(context.paths.domain)}
description: Domain layer generated by clean_architect.
publish_to: none

environment:
  sdk: $_sdkConstraint
${_section('dependencies', dependencies)}${_section('dev_dependencies', devDependencies)}''';
}

String _dataPubspec(TemplateContext context) {
  final dependencies = <String>[
    "  ${_packageName(context.paths.domain)}:",
    '    path: ../${_packageName(context.paths.domain)}',
  ];
  final devDependencies = <String>[];
  final requiresFlutter = context.config.localStorage != LocalStorage.abstract;
  final requiresBuildRunner =
      context.config.network == NetworkClient.dio ||
      context.config.models.useFreezed ||
      context.config.models.useJsonSerializable ||
      context.config.dependencyInjection == DependencyInjection.injectable ||
      context.config.localStorage == LocalStorage.hive ||
      context.config.localStorage == LocalStorage.objectbox;

  if (requiresFlutter) {
    dependencies.insert(0, '  flutter:\n    sdk: flutter');
  }

  if (context.config.useEitherFailure) {
    dependencies.add('  dartz: ^0.10.1');
  }
  if (context.config.network == NetworkClient.dio) {
    dependencies.add('  dio: ^5.10.0');
    dependencies.add('  retrofit: ^4.9.2');
    devDependencies.add('  retrofit_generator: ^10.2.8');
  }
  if (context.config.dependencyInjection == DependencyInjection.injectable) {
    dependencies.add('  injectable: $_injectableVersion');
    dependencies.add('  get_it: $_getItVersion');
    devDependencies.add('  injectable_generator: $_injectableGeneratorVersion');
  }
  if (context.config.localStorage == LocalStorage.secureStorage) {
    dependencies.add('  flutter_secure_storage: ^10.3.1');
  }
  if (context.config.localStorage == LocalStorage.sharedPreferences) {
    dependencies.add('  shared_preferences: ^2.5.5');
  }
  if (context.config.localStorage == LocalStorage.hive) {
    dependencies.add('  hive_ce: ^2.19.3');
    dependencies.add('  hive_ce_flutter: ^2.3.4');
    devDependencies.add('  hive_ce_generator: 1.11.1');
  }
  if (context.config.localStorage == LocalStorage.objectbox) {
    dependencies.add('  objectbox: ^5.3.2');
    dependencies.add('  objectbox_flutter_libs: ^5.3.2');
    dependencies.add('  path_provider: ^2.1.6');
    devDependencies.add('  objectbox_generator: ^5.3.2');
  }
  if (context.config.models.useFreezed) {
    dependencies.add('  freezed_annotation: $_freezedAnnotationVersion');
    devDependencies.add('  freezed: $_freezedVersion');
  }
  if (context.config.models.useJsonSerializable) {
    dependencies.add('  json_annotation: $_jsonAnnotationVersion');
    devDependencies.add('  json_serializable: $_jsonSerializableVersion');
  }
  if (requiresBuildRunner) {
    devDependencies.insert(0, '  build_runner: $_buildRunnerVersion');
  }

  return '''
name: ${_packageName(context.paths.data)}
description: Data layer generated by clean_architect.
publish_to: none

environment:
  sdk: $_sdkConstraint
${requiresFlutter ? "  flutter: '$_flutterConstraint'\n" : ''}

dependencies:
${dependencies.join('\n')}

${_section('dev_dependencies', devDependencies)}
''';
}

String _diPubspec(TemplateContext context) {
  final dependencies = <String>[
    '  ${_packageName(context.paths.domain)}:',
    '    path: ../${_packageName(context.paths.domain)}',
    '  ${_packageName(context.paths.data)}:',
    '    path: ../${_packageName(context.paths.data)}',
    '  get_it: $_getItVersion',
  ];

  return '''
name: ${_packageName(context.paths.di)}
description: Dependency injection layer generated by clean_architect.
publish_to: none

environment:
  sdk: $_sdkConstraint

dependencies:
${dependencies.join('\n')}
''';
}

String _presentationPubspec(TemplateContext context) {
  final dependencies = <String>[
    '  flutter:',
    '    sdk: flutter',
    "  ${_packageName(context.paths.domain)}:",
    '    path: ../${_packageName(context.paths.domain)}',
    "  ${_packageName(context.paths.data)}:",
    '    path: ../${_packageName(context.paths.data)}',
    "  ${_packageName(context.paths.di)}:",
    '    path: ../${_packageName(context.paths.di)}',
    '  get_it: $_getItVersion',
  ];

  if (context.config.stateManagement == StateManagement.getx) {
    dependencies.add('  get: ^4.7.3');
  }
  if (context.config.stateManagement == StateManagement.bloc) {
    dependencies.add('  flutter_bloc: ^9.1.1');
    dependencies.add('  equatable: ^2.1.0');
  }
  if (context.config.stateManagement == StateManagement.provider) {
    dependencies.add('  provider: ^6.1.5+1');
  }
  final devDependencies = <String>[
    '  flutter_test:\n    sdk: flutter',
    '  flutter_lints: ^6.0.0',
    if (context.config.useAssetGenerator)
      '  build_runner: $_buildRunnerVersion',
    if (context.config.useAssetGenerator) '  assets_generator_kit: ^0.1.0',
  ];

  return '''
name: ${_packageName(context.paths.presentation)}
description: Flutter presentation layer generated by clean_architect.
publish_to: none

environment:
  sdk: $_sdkConstraint
  flutter: '$_flutterConstraint'

dependencies:
${dependencies.join('\n')}

dev_dependencies:
${devDependencies.join('\n')}
flutter:
  uses-material-design: true
''';
}

String _assetGeneratorKit() {
  return '''
assets_generator_kit:
  input:
    - assets/images
    - assets/icons

  output: lib/generated/assets.dart

  integrations:
    svg: true
    lottie: false
   ''';
}

String _presentationMain() {
  return '''
import 'package:flutter/material.dart';

void main() {
  runApp(const CleanArchitectApp());
}

class CleanArchitectApp extends StatelessWidget {
  const CleanArchitectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clean Architect',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(child: Text('Clean Architect')),
      ),
    );
  }
}
''';
}

String _packageRoot(String libPath) {
  final parts = p.split(p.normalize(libPath));
  final libIndex = parts.indexOf('lib');
  if (libIndex == -1) return libPath;
  return p.joinAll(parts.take(libIndex));
}

String _packageName(String libPath) {
  final parts = p.split(p.normalize(libPath));
  final libIndex = parts.indexOf('lib');
  if (libIndex > 0) return parts[libIndex - 1];
  return p.basename(libPath);
}

String _section(String name, Iterable<String> entries) {
  final uniqueEntries = entries.toSet();
  if (uniqueEntries.isEmpty) return '';
  return '\n$name:\n${uniqueEntries.join('\n')}\n';
}
