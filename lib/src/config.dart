import 'dart:io';

import 'package:meta/meta.dart';
import 'package:yaml/yaml.dart';

enum ProjectStructure { featureFirst, layeredPackages }

enum StateManagement { getx, none }

enum NetworkClient { dio, abstract }

enum LocalStorage { secureStorage, sharedPreferences, abstract }

enum DependencyInjection { manual, injectable }

class CleanArchitectConfig {
  const CleanArchitectConfig(
      {required this.structure,
      required this.stateManagement,
      required this.network,
      required this.localStorage,
      required this.dependencyInjection,
      required this.models,
      required this.paths,
      required this.useAssetGenerator,
      required this.useEitherFailure,
      required this.flutter});

  factory CleanArchitectConfig.defaults() {
    return const CleanArchitectConfig(
      structure: ProjectStructure.layeredPackages,
      stateManagement: StateManagement.getx,
      network: NetworkClient.dio,
      localStorage: LocalStorage.secureStorage,
      dependencyInjection: DependencyInjection.manual,
      useAssetGenerator: true,
      useEitherFailure: false,
      flutter: FlutterConfig(
        createPresentation: false,
        platforms: ['android', 'ios'],
      ),
      models: ModelConfig(
        useFreezed: true,
        useJsonSerializable: true,
      ),
      paths: PathConfig(
        domain: 'domain/lib',
        data: 'data/lib/features',
        presentation: 'presentation/lib',
        di: 'di/lib',
      ),
    );
  }

  factory CleanArchitectConfig.fromFile(File file) {
    if (!file.existsSync()) {
      return CleanArchitectConfig.defaults();
    }

    final document = loadYaml(file.readAsStringSync());
    if (document is! YamlMap) {
      throw const FormatException('clean_architect.yaml must contain a map.');
    }

    final root = document['clean_architect'];
    if (root is! YamlMap) {
      throw const FormatException(
        'clean_architect.yaml must contain a clean_architect section.',
      );
    }

    final defaults = CleanArchitectConfig.defaults();
    final models = root['models'];
    final paths = root['paths'];
    final flutter = root['flutter'];

    return CleanArchitectConfig(
      structure: _enumValue(
        root['structure'],
        ProjectStructure.values,
        _structureName,
        defaults.structure,
      ),
      stateManagement: _enumValue(
        root['state_management'],
        StateManagement.values,
        _stateName,
        defaults.stateManagement,
      ),
      network: _enumValue(
        root['network'],
        NetworkClient.values,
        _networkName,
        defaults.network,
      ),
      localStorage: _enumValue(
        root['local_storage'],
        LocalStorage.values,
        _storageName,
        defaults.localStorage,
      ),
      dependencyInjection: _enumValue(
        root['dependency_injection'],
        DependencyInjection.values,
        _diName,
        defaults.dependencyInjection,
      ),
      useAssetGenerator: _boolValue(
        root,
        'use_asset_generator',
        defaults.useAssetGenerator,
      ),
      useEitherFailure: _boolValue(
        root,
        'use_either_failure',
        defaults.useEitherFailure,
      ),
      flutter: FlutterConfig(
        createPresentation: _boolValue(
          flutter,
          'create_presentation',
          defaults.flutter.createPresentation,
        ),
        platforms: _stringListValue(
          flutter,
          'platforms',
          defaults.flutter.platforms,
        ),
      ),
      models: ModelConfig(
        useFreezed:
            _boolValue(models, 'use_freezed', defaults.models.useFreezed),
        useJsonSerializable: _boolValue(
          models,
          'use_json_serializable',
          defaults.models.useJsonSerializable,
        ),
      ),
      paths: PathConfig(
        domain: _stringValue(paths, 'domain', defaults.paths.domain),
        data: _stringValue(paths, 'data', defaults.paths.data),
        presentation: _stringValue(
          paths,
          'presentation',
          defaults.paths.presentation,
        ),
        di: _stringValue(paths, 'di', defaults.paths.di),
      ),
    );
  }

  final ProjectStructure structure;
  final StateManagement stateManagement;
  final NetworkClient network;
  final LocalStorage localStorage;
  final DependencyInjection dependencyInjection;
  final ModelConfig models;
  final PathConfig paths;
  final bool useAssetGenerator;
  final bool useEitherFailure;
  final FlutterConfig flutter;

  static const fileName = 'clean_architect.yaml';

  static String defaultYaml() {
    return '''
clean_architect:
  structure: layered_packages # layered_packages or feature_first
  state_management: getx # getx or none
  network: dio # dio or abstract
  local_storage: secure_storage # secure_storage or abstract
  dependency_injection: manual # manual or injectable
  use_asset_generator: true
  use_either_failure: false
  flutter:
    create_presentation: false
    platforms:
      - android
      - ios
  models:
    use_freezed: true
    use_json_serializable: true
  paths:
    domain: domain/lib
    data: data/lib/features
    presentation: presentation/lib
    di: di/lib
''';
  }

  String get structureName => _structureName(structure);
  String get stateManagementName => _stateName(stateManagement);
  String get networkName => _networkName(network);
  String get localStorageName => _storageName(localStorage);
  String get dependencyInjectionName => _diName(dependencyInjection);
}

class FlutterConfig {
  const FlutterConfig({
    required this.createPresentation,
    required this.platforms,
  });

  final bool createPresentation;
  final List<String> platforms;
}

class ModelConfig {
  const ModelConfig({
    required this.useFreezed,
    required this.useJsonSerializable,
  });

  final bool useFreezed;
  final bool useJsonSerializable;
}

class PathConfig {
  const PathConfig({
    required this.domain,
    required this.data,
    required this.presentation,
    required this.di,
  });

  final String domain;
  final String data;
  final String presentation;
  final String di;
}

T _enumValue<T>(
  Object? value,
  List<T> values,
  String Function(T value) nameOf,
  T fallback,
) {
  if (value == null) return fallback;
  final text = value.toString();
  for (final item in values) {
    if (nameOf(item) == text) return item;
  }

  final allowed = values.map(nameOf).join(', ');
  throw FormatException('Unsupported value "$text". Allowed values: $allowed.');
}

bool _boolValue(Object? map, String key, bool fallback) {
  if (map is! YamlMap || map[key] == null) return fallback;
  return map[key] == true;
}

String _stringValue(Object? map, String key, String fallback) {
  if (map is! YamlMap || map[key] == null) return fallback;
  return map[key].toString();
}

List<String> _stringListValue(Object? map, String key, List<String> fallback) {
  if (map is! YamlMap || map[key] == null) return fallback;
  final value = map[key];
  if (value is YamlList) {
    return value.map((item) => item.toString()).toList(growable: false);
  }
  final text = value.toString();
  if (text.trim().isEmpty) return const [];
  return text
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

@visibleForTesting
String structureName(ProjectStructure structure) => _structureName(structure);

String _structureName(ProjectStructure structure) {
  return switch (structure) {
    ProjectStructure.featureFirst => 'feature_first',
    ProjectStructure.layeredPackages => 'layered_packages',
  };
}

String _stateName(StateManagement state) {
  return switch (state) {
    StateManagement.getx => 'getx',
    StateManagement.none => 'none',
  };
}

String _networkName(NetworkClient network) {
  return switch (network) {
    NetworkClient.dio => 'dio',
    NetworkClient.abstract => 'abstract',
  };
}

String _storageName(LocalStorage storage) {
  return switch (storage) {
    LocalStorage.secureStorage => 'secure_storage',
    LocalStorage.sharedPreferences => 'shared_preferences',
    LocalStorage.abstract => 'abstract',
  };
}

String _diName(DependencyInjection dependencyInjection) {
  return switch (dependencyInjection) {
    DependencyInjection.manual => 'manual',
    DependencyInjection.injectable => 'injectable',
  };
}
