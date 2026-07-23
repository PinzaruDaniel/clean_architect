import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

enum ProjectStructure { featureFirst, layeredPackages, verticalPackages }

enum StateManagement { getx, bloc, provider, none }

enum NetworkClient { dio, abstract }

enum LocalStorage {
  secureStorage,
  sharedPreferences,
  hive,
  objectbox,
  abstract,
}

enum DependencyInjection { manual, injectable }

const currentConfigVersion = 1;

class CleanArchitectConfig {
  const CleanArchitectConfig({
    required this.structure,
    required this.stateManagement,
    required this.network,
    required this.localStorage,
    required this.dependencyInjection,
    required this.models,
    required this.paths,
    required this.useAssetGenerator,
    required this.useEitherFailure,
    required this.flutter,
    this.configVersion = currentConfigVersion,
  });

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
    );
  }

  factory CleanArchitectConfig.fromFile(File file) {
    if (!file.existsSync()) {
      return CleanArchitectConfig.defaults();
    }

    late final Object? document;
    try {
      document = loadYaml(file.readAsStringSync());
    } on FormatException catch (error) {
      throw FormatException('Invalid ${file.path}: ${error.message}');
    }
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
    final configVersion = _configVersion(root['config_version']);
    final models = _mapSection(root, 'models');
    final paths = _mapSection(root, 'paths');
    final flutter = _mapSection(root, 'flutter');

    final config = CleanArchitectConfig(
      configVersion: configVersion,
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
        useFreezed: _boolValue(
          models,
          'use_freezed',
          defaults.models.useFreezed,
        ),
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
        app: _stringValue(paths, 'app', defaults.paths.app),
        core: _stringValue(paths, 'core', defaults.paths.core),
        features: _stringValue(paths, 'features', defaults.paths.features),
      ),
    );
    config.validate();
    return config;
  }

  final int configVersion;
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
  config_version: $currentConfigVersion
  structure: layered_packages # layered_packages, feature_first, or vertical_packages
  state_management: getx # getx, bloc, provider, or none
  network: dio # dio or abstract
  local_storage: secure_storage # secure_storage, shared_preferences, hive, objectbox, or abstract
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
    app: app/lib
    core: packages/core/lib
    features: packages/features
''';
  }

  String get structureName => _structureName(structure);
  String get stateManagementName => _stateName(stateManagement);
  String get networkName => _networkName(network);
  String get localStorageName => _storageName(localStorage);
  String get dependencyInjectionName => _diName(dependencyInjection);

  void validate() {
    if (configVersion < 1 || configVersion > currentConfigVersion) {
      throw FormatException(
        'Unsupported config_version $configVersion. '
        'This CLI supports config_version $currentConfigVersion.',
      );
    }

    const supportedPlatforms = {
      'android',
      'ios',
      'web',
      'windows',
      'macos',
      'linux',
    };
    final invalidPlatforms = flutter.platforms
        .where((platform) => !supportedPlatforms.contains(platform))
        .toSet();
    if (invalidPlatforms.isNotEmpty) {
      throw FormatException(
        'Unsupported Flutter platform(s): ${invalidPlatforms.join(', ')}. '
        'Allowed values: ${supportedPlatforms.join(', ')}.',
      );
    }
    if (flutter.platforms.toSet().length != flutter.platforms.length) {
      throw const FormatException(
        'Flutter platforms must not contain duplicates.',
      );
    }

    if (structure == ProjectStructure.verticalPackages) {
      _validateLayerPath('app', paths.app);
      _validateLayerPath('core', paths.core);
      _validatePackageParentPath('features', paths.features);

      final appRoot = _packageRoot(paths.app);
      final coreRoot = _packageRoot(paths.core);
      final appName = p.basename(appRoot);
      final coreName = p.basename(coreRoot);
      _validatePackageName('app', appName);
      _validatePackageName('core', coreName);
      if (appName == coreName) {
        throw const FormatException(
          'Vertical app and core packages must have different package names.',
        );
      }
      if (appName == 'base_feature' || coreName == 'base_feature') {
        throw const FormatException(
          'Vertical app and core package names must not be "base_feature".',
        );
      }
      if (appRoot == coreRoot ||
          p.isWithin(appRoot, coreRoot) ||
          p.isWithin(coreRoot, appRoot)) {
        throw const FormatException(
          'Vertical app and core package roots must be distinct and not nested.',
        );
      }
      final featuresRoot = p.normalize(paths.features);
      if (_pathsOverlap(featuresRoot, appRoot) ||
          _pathsOverlap(featuresRoot, coreRoot)) {
        throw const FormatException(
          'Vertical app, core, and features roots must not be nested.',
        );
      }
      return;
    }

    final configuredPaths = {
      'domain': paths.domain,
      'data': paths.data,
      'presentation': paths.presentation,
      'di': paths.di,
    };
    for (final entry in configuredPaths.entries) {
      _validateLayerPath(entry.key, entry.value);
    }

    final packageRoots = configuredPaths.map(
      (name, path) => MapEntry(name, _packageRoot(path)),
    );
    final roots = <String, String>{};
    for (final entry in packageRoots.entries) {
      final previous = roots[entry.value];
      if (previous != null) {
        throw FormatException(
          'Paths "$previous" and "${entry.key}" resolve to the same package.',
        );
      }
      roots[entry.value] = entry.key;
    }
  }
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
    this.app = 'app/lib',
    this.core = 'packages/core/lib',
    this.features = 'packages/features',
  });

  final String domain;
  final String data;
  final String presentation;
  final String di;
  final String app;
  final String core;
  final String features;
}

YamlMap? _mapSection(YamlMap root, String key) {
  final value = root[key];
  if (value == null) return null;
  if (value is YamlMap) return value;
  throw FormatException('$key must contain a map.');
}

int _configVersion(Object? value) {
  if (value == null) return 1;
  if (value is int) return value;
  throw const FormatException('config_version must be an integer.');
}

void _validateLayerPath(String label, String value) {
  if (value.trim().isEmpty) {
    throw FormatException('$label path must not be empty.');
  }
  if (p.isAbsolute(value) || p.windows.isAbsolute(value)) {
    throw FormatException('$label path must be relative: "$value".');
  }

  final parts = p.split(value);
  if (parts.contains('..')) {
    throw FormatException('$label path must not contain "..": "$value".');
  }
  final libIndex = parts.indexOf('lib');
  if (libIndex <= 0) {
    throw FormatException(
      '$label path must point inside a package lib directory: "$value".',
    );
  }
  if (libIndex + 1 < parts.length && parts[libIndex + 1] == 'src') {
    throw FormatException(
      '$label path must not use the cross-package reserved lib/src directory: '
      '"$value". Use a public directory below lib instead.',
    );
  }
}

void _validatePackageParentPath(String label, String value) {
  if (value.trim().isEmpty) {
    throw FormatException('$label path must not be empty.');
  }
  if (p.isAbsolute(value) || p.windows.isAbsolute(value)) {
    throw FormatException('$label path must be relative: "$value".');
  }
  if (p.split(value).contains('..')) {
    throw FormatException('$label path must not contain "..": "$value".');
  }
  if (p.split(p.normalize(value)).contains('lib')) {
    throw FormatException(
      '$label path must point to a package parent, not a lib directory: '
      '"$value".',
    );
  }
}

void _validatePackageName(String label, String value) {
  final valid = RegExp(r'^[a-z][a-z0-9_]*$');
  if (!valid.hasMatch(value)) {
    throw FormatException(
      '$label package name "$value" is invalid. Use lowercase letters, '
      'numbers, and underscores, starting with a letter.',
    );
  }
}

bool _pathsOverlap(String left, String right) {
  return left == right || p.isWithin(left, right) || p.isWithin(right, left);
}

String _packageRoot(String path) {
  final parts = p.split(p.normalize(path));
  final libIndex = parts.indexOf('lib');
  return p.joinAll(parts.take(libIndex));
}

T _enumValue<T>(
  Object? value,
  List<T> values,
  String Function(T value) nameOf,
  T fallback,
) {
  if (value == null) return fallback;
  if (value is! String) {
    throw const FormatException('Configuration option values must be strings.');
  }
  final text = value;
  for (final item in values) {
    if (nameOf(item) == text) return item;
  }

  final allowed = values.map(nameOf).join(', ');
  throw FormatException('Unsupported value "$text". Allowed values: $allowed.');
}

bool _boolValue(Object? map, String key, bool fallback) {
  if (map is! YamlMap || map[key] == null) return fallback;
  final value = map[key];
  if (value is bool) return value;
  throw FormatException('$key must be true or false.');
}

String _stringValue(Object? map, String key, String fallback) {
  if (map is! YamlMap || map[key] == null) return fallback;
  final value = map[key];
  if (value is String) return value;
  throw FormatException('$key must be a string.');
}

List<String> _stringListValue(Object? map, String key, List<String> fallback) {
  if (map is! YamlMap || map[key] == null) return fallback;
  final value = map[key];
  if (value is YamlList) {
    if (value.any((item) => item is! String)) {
      throw FormatException('$key must contain only strings.');
    }
    return value.cast<String>().toList(growable: false);
  }
  if (value is! String) {
    throw FormatException('$key must be a list or comma-separated string.');
  }
  final text = value;
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
    ProjectStructure.verticalPackages => 'vertical_packages',
  };
}

String _stateName(StateManagement state) {
  return switch (state) {
    StateManagement.getx => 'getx',
    StateManagement.bloc => 'bloc',
    StateManagement.provider => 'provider',
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
    LocalStorage.hive => 'hive',
    LocalStorage.objectbox => 'objectbox',
    LocalStorage.abstract => 'abstract',
  };
}

String _diName(DependencyInjection dependencyInjection) {
  return switch (dependencyInjection) {
    DependencyInjection.manual => 'manual',
    DependencyInjection.injectable => 'injectable',
  };
}
