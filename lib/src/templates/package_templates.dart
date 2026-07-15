import 'package:path/path.dart' as p;

import '../config.dart';
import '../generated_file.dart';
import '../generator.dart';

List<GeneratedFile> packageTemplates(
  TemplateContext context, {
  required bool includePresentation,
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
    ..._dataModuleFiles(context),
  ];

  if (includePresentation) {
    files.addAll([
      GeneratedFile(
        path: p.join(_packageRoot(context.paths.presentation), 'pubspec.yaml'),
        content: _presentationPubspec(context),
      ),
      GeneratedFile(
        path: p.join(
            _packageRoot(context.paths.presentation), 'assets', 'images'),
        content: '',
      ),
      GeneratedFile(
        path:
            p.join(_packageRoot(context.paths.presentation), 'assets', 'icons'),
        content: '',
      ),
      GeneratedFile(
        path: p.join(
            _packageRoot(context.paths.presentation), 'lib', 'main.dart'),
        content: _presentationMain(),
      ),
      GeneratedFile(
        path: p.join(_packageRoot(context.paths.presentation), 'lib', 'widgets',
            '.gitkeep'),
        content: '',
      ),
      GeneratedFile(
        path: p.join(_packageRoot(context.paths.presentation), 'lib', 'pages',
            '.gitkeep'),
        content: '',
      ),
      GeneratedFile(
        path: p.join(_packageRoot(context.paths.presentation), 'lib', 'utils',
            '.gitkeep'),
        content: '',
      ),
      GeneratedFile(
        path: p.join(_packageRoot(context.paths.presentation), 'lib',
            'controllers', '.gitkeep'),
        content: '',
      ),
      GeneratedFile(
        path: p.join(_packageRoot(context.paths.presentation), 'lib',
            'constants', '.gitkeep'),
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
      files.add(GeneratedFile(
        path: p.join(_packageRoot(context.paths.presentation),
            'asset_generator_kit.yaml'),
        content: _assetGeneratorKit(),
      ));
    }
  }

  return files;
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
      "import 'package:hive/hive.dart';",
    if (context.config.localStorage == LocalStorage.hive)
      "import 'package:hive_flutter/hive_flutter.dart';",
    if (context.config.localStorage == LocalStorage.objectbox)
      "import 'package:objectbox/objectbox.dart';",
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
  return '''
  @preResolve
  Future<void> initHive() async {
    await Hive.initFlutter();
  }

  @lazySingleton
  @preResolve
  Future<Box<$boxClass>> $boxName() {
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
  return get.init();
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
  if (context.config.useEitherFailure) {
    dependencies.add('  dartz: ^0.10.1');
  }
  if (context.config.models.useFreezed) {
    dependencies.add('  freezed: ^3.2.5');
    dependencies.add('  freezed_annotation: ^3.1.0');
  }
  if (context.config.dependencyInjection == DependencyInjection.injectable) {
    dependencies.add('  injectable: ^3.0.0');
    dependencies.add('  get_it: ^9.2.1');
  }
  final dependenciesBlock = dependencies.isEmpty
      ? ''
      : '\ndependencies:\n${dependencies.join('\n')}\n\ndev_dependencies:\n  build_runner: ^2.15.0\n  injectable_generator: \n';

  return '''
name: ${_packageName(context.paths.domain)}
description: Domain layer generated by clean_architect.
publish_to: none

environment:
  sdk: ^3.6.0
$dependenciesBlock''';
}

String _dataPubspec(TemplateContext context) {
  final dependencies = <String>[
    "  ${_packageName(context.paths.domain)}:",
    '    path: ../${_packageName(context.paths.domain)}',
  ];

  if (context.config.useEitherFailure) {
    dependencies.add('  dartz: ^0.10.1');
  }
  if (context.config.network == NetworkClient.dio) {
    dependencies.add('  dio: ^5.9.1');
    dependencies.add('  retrofit: ');
  }
  if (context.config.dependencyInjection == DependencyInjection.injectable) {
    dependencies.add('  injectable: ^3.0.0');
    dependencies.add('  get_it: ^9.2.1');
  }
  if (context.config.localStorage == LocalStorage.secureStorage) {
    dependencies.insert(0, '  flutter:\n    sdk: flutter');
    dependencies.add('  flutter_secure_storage: ^9.2.2');
  }
  if (context.config.localStorage == LocalStorage.sharedPreferences) {
    dependencies.insert(0, '  flutter:\n    sdk: flutter');
    dependencies.add('  shared_preferences: ^2.5.3');
  }
  if (context.config.localStorage == LocalStorage.hive) {
    dependencies.insert(0, '  flutter:\n    sdk: flutter');
    dependencies.add('  hive: ^2.2.3');
    dependencies.add('  hive_flutter: ^1.1.0');
  }
  if (context.config.localStorage == LocalStorage.objectbox) {
    dependencies.insert(0, '  flutter:\n    sdk: flutter');
    dependencies.add('  objectbox: ^4.1.0');
    dependencies.add('  objectbox_flutter_libs: ^4.1.0');
    dependencies.add('  path_provider: ^2.1.5');
  }
  if (context.config.models.useFreezed) {
    dependencies.add('  freezed: ^3.2.5');
    dependencies.add('  freezed_annotation: ^3.1.0');
  }
  if (context.config.models.useJsonSerializable ||
      context.config.models.useFreezed) {
    dependencies.add('  json_annotation: ^4.12.0');
  }

  return '''
name: ${_packageName(context.paths.data)}
description: Data layer generated by clean_architect.
publish_to: none

environment:
  sdk: ^3.6.0

dependencies:
${dependencies.join('\n')}

dev_dependencies:
  build_runner: ^2.15.0
  retrofit_generator:
  json_serializable: ^6.14.0
  injectable_generator: 
  objectbox_generator:
  hive_generator:
''';
}

String _diPubspec(TemplateContext context) {
  final dependencies = <String>[
    '  ${_packageName(context.paths.domain)}:',
    '    path: ../${_packageName(context.paths.domain)}',
    '  ${_packageName(context.paths.data)}:',
    '    path: ../${_packageName(context.paths.data)}',
  ];

  if (context.config.dependencyInjection == DependencyInjection.injectable) {
    dependencies.add('  injectable: ^3.0.0');
    dependencies.add('  get_it: ^9.2.0');
  }

  return '''
name: ${_packageName(context.paths.di)}
description: Dependency injection layer generated by clean_architect.
publish_to: none

environment:
  sdk: ^3.6.0

dependencies:
${dependencies.join('\n')}

dev_dependencies:
  build_runner: ^2.4.13
  retrofit_generator: 
  json_serializable: ^6.12.0
  freezed: ^2.5.7
  injectable_generator: ^2.6.2
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
  ];

  if (context.config.stateManagement == StateManagement.getx) {
    dependencies.add('  get: ^4.7.2');
  }
  if (context.config.stateManagement == StateManagement.bloc) {
    dependencies.add('  flutter_bloc: ^9.1.1');
    dependencies.add('  equatable: ^2.0.7');
  }
  if (context.config.stateManagement == StateManagement.provider) {
    dependencies.add('  provider: ^6.1.5');
  }
  if (context.config.dependencyInjection == DependencyInjection.injectable) {
    dependencies.add('  get_it:');
  }
  if (context.config.useAssetGenerator) {
    dependencies.add('  assets_generator_kit: ^0.1.0');
  }

  return '''
name: ${_packageName(context.paths.presentation)}
description: Flutter presentation layer generated by clean_architect.
publish_to: none

environment:
  sdk: ^3.6.0

dependencies:
${dependencies.join('\n')}

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  build_runner: ^2.15.1
flutter:
  uses-material-design: true
''';
}

String _assetGeneratorKit() {
  return '''
assetgeneratorkit:
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
