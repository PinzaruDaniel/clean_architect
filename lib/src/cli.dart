import 'dart:io';

import 'package:args/args.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import 'case_utils.dart';
import 'config.dart';
import 'file_writer.dart';
import 'generator.dart';
import 'generated_file.dart';
import 'operation_patcher.dart';
import 'templates/operation_templates.dart';

class CleanArchitectCli {
  CleanArchitectCli({Logger? logger}) : _logger = logger ?? Logger();

  final Logger _logger;

  void run(List<String> arguments) {
    final parser = _buildParser();
    late final ArgResults results;

    try {
      results = parser.parse(arguments);
    } on FormatException catch (error) {
      _logger.err(error.message);
      _logger.info(parser.usage);
      exitCode = 64;
      return;
    }

    if (results['help'] == true || results.command == null) {
      _logger.info(parser.usage);
      return;
    }

    switch (results.command!.name) {
      case 'init':
        _init(results.command!);
      case 'create':
        _create(results.command!);
      case 'doctor':
        _doctor();
      default:
        _logger.err('Unknown command: ${results.command!.name}');
        exitCode = 64;
    }
  }

  ArgParser _buildParser() {
    final parser = ArgParser()..addFlag('help', abbr: 'h', negatable: false);

    parser.addCommand(
      'init',
      ArgParser()
        ..addFlag('force', abbr: 'f', negatable: false)
        ..addFlag('dry-run', negatable: false),
    );

    parser.addCommand('doctor');

    parser.addCommand(
      'create',
      ArgParser()
        ..addFlag('dry-run', negatable: false)
        ..addFlag('overwrite', negatable: false)
        ..addFlag('force', abbr: 'f', negatable: false)
        ..addFlag('skip-presentation', negatable: false)
        ..addFlag('flutter-create', negatable: true)
        ..addOption('platforms')
        ..addOption('state', allowed: ['getx', 'bloc', 'provider', 'none'])
        ..addOption('network', allowed: ['dio', 'abstract'])
        ..addOption(
          'storage',
          allowed: [
            'secure_storage',
            'shared_preferences',
            'hive',
            'objectbox',
            'abstract',
          ],
        )
        ..addOption(
          'dependency-injection',
          abbr: 'd',
          allowed: ['manual', 'injectable'],
        )
        ..addOption('di', allowed: ['manual', 'injectable'])
        ..addOption('feature')
        ..addFlag('use-either-failure', negatable: true),
    );

    return parser;
  }

  void _init(ArgResults results) {
    final file = File(CleanArchitectConfig.fileName);
    final force = results['force'] == true;
    final dryRun = results['dry-run'] == true;

    if (dryRun) {
      _logger.info('create ${CleanArchitectConfig.fileName}');
      return;
    }

    if (file.existsSync() && !force) {
      _logger.warn('${CleanArchitectConfig.fileName} already exists');
      return;
    }

    file.writeAsStringSync(CleanArchitectConfig.defaultYaml());
    _logger.success('created ${CleanArchitectConfig.fileName}');
  }

  void _create(ArgResults results) {
    final args = results.rest;
    if (args.isEmpty) {
      _logger.err('Usage: clean_architect create architecture');
      _logger.err('Usage: clean_architect create auth');
      _logger.err('Usage: clean_architect create feature <name>');
      exitCode = 64;
      return;
    }

    final config = _configWithOverrides(results);
    final generator = CleanArchitectGenerator(config);
    final skipPresentation = results['skip-presentation'] == true;
    final operationKind = _operationKind(args);
    final featureOption = results['feature'] as String?;
    final files = _filesForCreate(
      args,
      generator,
      skipPresentation,
      featureOption,
      operationKind,
    );
    if (files == null) {
      exitCode = 64;
      return;
    }

    final writer = FileWriter(
      logger: _logger,
      dryRun: results['dry-run'] == true,
      overwrite: results['overwrite'] == true || results['force'] == true,
    );
    writer.writeAll(files);

    _patchFeatureDataModuleIfNeeded(
      args,
      config,
      dryRun: results['dry-run'] == true,
    );

    if (_shouldRunFlutterCreate(
      args,
      config,
      skipPresentation: skipPresentation,
      operationKind: operationKind,
    )) {
      _runFlutterCreate(config, dryRun: results['dry-run'] == true);
    }

    if (operationKind != null) {
      OperationPatcher(
        config: config,
        logger: _logger,
        dryRun: results['dry-run'] == true,
      ).apply(
        kind: operationKind,
        featureName: featureOption!,
        operationName: args[1],
      );
    }
  }

  List<GeneratedFile>? _filesForCreate(
    List<String> args,
    CleanArchitectGenerator generator,
    bool skipPresentation,
    String? featureOption,
    OperationKind? operationKind,
  ) {
    switch (args.first) {
      case 'architecture':
      case 'base':
        return generator.architecture(skipPresentation: skipPresentation);
      case 'auth':
        return generator.auth(skipPresentation: skipPresentation);
      case 'feature':
        if (args.length < 2) {
          _logger.err('Usage: clean_architect create feature <name>');
          return null;
        }
        return generator.feature(args[1], skipPresentation: skipPresentation);
      case 'usecase':
        final feature = featureOption;
        if (args.length < 2 || feature == null || feature.isEmpty) {
          _logger.err(
            'Usage: clean_architect create usecase <name> --feature <feature>',
          );
          return null;
        }
        return generator.useCase(args[1], feature: feature);
      case 'remote-function':
      case 'remote-method':
      case 'local-function':
      case 'local-method':
      case 'cached-function':
      case 'cached-method':
        final feature = featureOption;
        if (args.length < 2 || feature == null || feature.isEmpty) {
          _logger.err(
            'Usage: clean_architect create ${args.first} <name> --feature <feature>',
          );
          return null;
        }
        return generator.operation(
          args[1],
          feature: feature,
          kind: operationKind!,
        );
      case 'repository':
        if (args.length < 2) {
          _logger.err('Usage: clean_architect create repository <feature>');
          return null;
        }
        return generator.repository(args[1]);
      default:
        _logger.err('Unknown create target: ${args.first}');
        return null;
    }
  }

  OperationKind? _operationKind(List<String> args) {
    if (args.isEmpty) return null;
    return switch (args.first) {
      'remote-function' || 'remote-method' => OperationKind.remote,
      'local-function' || 'local-method' => OperationKind.local,
      'cached-function' || 'cached-method' => OperationKind.cached,
      _ => null,
    };
  }

  CleanArchitectConfig _configWithOverrides(ArgResults results) {
    final config = CleanArchitectConfig.fromFile(
      File(CleanArchitectConfig.fileName),
    );

    return CleanArchitectConfig(
      structure: config.structure,
      stateManagement:
          _stateOverride(results['state'] as String?) ?? config.stateManagement,
      network:
          _networkOverride(results['network'] as String?) ?? config.network,
      localStorage:
          _storageOverride(results['storage'] as String?) ??
          config.localStorage,
      useAssetGenerator: config.useAssetGenerator,
      useEitherFailure: results.wasParsed('use-either-failure')
          ? results['use-either-failure'] == true
          : config.useEitherFailure,
      flutter: FlutterConfig(
        createPresentation: results.wasParsed('flutter-create')
            ? results['flutter-create'] == true
            : config.flutter.createPresentation,
        platforms:
            _platformsOverride(results['platforms'] as String?) ??
            config.flutter.platforms,
      ),
      dependencyInjection:
          _dependencyInjectionOverride(
            results['dependency-injection'] as String? ??
                results['di'] as String?,
          ) ??
          config.dependencyInjection,
      models: config.models,
      paths: config.paths,
    );
  }

  List<String>? _platformsOverride(String? value) {
    if (value == null) return null;
    return value
        .split(',')
        .map((platform) => platform.trim())
        .where((platform) => platform.isNotEmpty)
        .toList(growable: false);
  }

  bool _shouldRunFlutterCreate(
    List<String> args,
    CleanArchitectConfig config, {
    required bool skipPresentation,
    required OperationKind? operationKind,
  }) {
    if (skipPresentation || !config.flutter.createPresentation) return false;
    if (operationKind != null || args.isEmpty) return false;
    return switch (args.first) {
      'architecture' || 'base' || 'auth' || 'feature' => true,
      _ => false,
    };
  }

  void _patchFeatureDataModuleIfNeeded(
    List<String> args,
    CleanArchitectConfig config, {
    required bool dryRun,
  }) {
    if (args.isEmpty) return;
    if (config.dependencyInjection != DependencyInjection.injectable) return;
    if (config.localStorage != LocalStorage.hive &&
        config.localStorage != LocalStorage.objectbox) {
      return;
    }

    final featureName = switch (args.first) {
      'auth' => 'auth',
      'feature' when args.length >= 2 => args[1],
      'architecture' || 'base' => 'base_feature',
      _ => null,
    };
    if (featureName == null || featureName.isEmpty) return;

    final feature = NameCases(featureName);
    final dataRoot = _packageRoot(config.paths.data);
    final dataLib = p.join(dataRoot, 'lib');
    final modulePath = p.join(dataLib, 'data_module.dart');
    final moduleFile = File(modulePath);
    if (!moduleFile.existsSync()) return;

    final boxClass = '${feature.pascal}Box';
    final methodName = '${feature.camel}Box';
    var content = moduleFile.readAsStringSync();
    if (content.contains(' $methodName(')) return;

    final featureDataPath = p.join(config.paths.data, feature.snake);
    final boxPath = p.join(
      featureDataPath,
      'local',
      'models',
      '${feature.snake}_box.dart',
    );
    final boxImportPath = p
        .relative(boxPath, from: dataLib)
        .split(p.separator)
        .join('/');

    final imports = <String>["import '$boxImportPath';"];
    final snippet = config.localStorage == LocalStorage.hive
        ? '''
  @lazySingleton
  @preResolve
  Future<Box<$boxClass>> $methodName() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(${stableHiveTypeId(feature.snake)})) {
      Hive.registerAdapter(${boxClass}Adapter());
    }
    return Hive.openBox<$boxClass>('${feature.snake}_box');
  }
'''
        : '''
  @lazySingleton
  Box<$boxClass> $methodName(Store store) => Box<$boxClass>(store);
''';

    if (dryRun) {
      _logger.info('update $modulePath');
      return;
    }

    content = _ensureImports(content, imports);
    content = _insertBeforeClassEnd(
      content,
      'abstract class DataModule',
      snippet,
    );
    moduleFile.writeAsStringSync(_withTrailingNewline(content));
    _logger.success('updated $modulePath');
  }

  String _ensureImports(String content, List<String> imports) {
    var result = content;
    for (final import in imports.toSet()) {
      if (result.contains(import)) continue;
      final lastImport = RegExp(
        r'''import '[^']+';|import "[^"]+";''',
      ).allMatches(result).lastOrNull;
      if (lastImport == null) {
        result = '$import\n\n$result';
      } else {
        result = result.replaceRange(
          lastImport.end,
          lastImport.end,
          '\n$import',
        );
      }
    }
    return result;
  }

  String _insertBeforeClassEnd(
    String content,
    String classNeedle,
    String snippet,
  ) {
    final classIndex = content.indexOf(classNeedle);
    if (classIndex == -1) return _insertBeforeLastBrace(content, snippet);
    final openBrace = content.indexOf('{', classIndex);
    if (openBrace == -1) return _insertBeforeLastBrace(content, snippet);

    var depth = 0;
    for (var index = openBrace; index < content.length; index++) {
      final char = content[index];
      if (char == '{') depth++;
      if (char == '}') depth--;
      if (depth == 0) {
        return '${content.substring(0, index)}$snippet${content.substring(index)}';
      }
    }

    return _insertBeforeLastBrace(content, snippet);
  }

  String _insertBeforeLastBrace(String content, String snippet) {
    final index = content.lastIndexOf('}');
    if (index == -1) return '$content$snippet';
    return '${content.substring(0, index)}$snippet${content.substring(index)}';
  }

  String _withTrailingNewline(String content) {
    return content.endsWith('\n') ? content : '$content\n';
  }

  void _runFlutterCreate(CleanArchitectConfig config, {required bool dryRun}) {
    final presentationRoot = _packageRoot(config.paths.presentation);
    final platforms = config.flutter.platforms;
    final args = [
      'create',
      '.',
      if (platforms.isNotEmpty) '--platforms=${platforms.join(',')}',
    ];

    if (dryRun) {
      _logger.info('run (cd $presentationRoot && flutter ${args.join(' ')})');
      return;
    }

    try {
      final result = Process.runSync(
        'flutter',
        args,
        workingDirectory: presentationRoot,
      );
      if (result.exitCode == 0) {
        _logger.success('ran flutter ${args.join(' ')} in $presentationRoot');
        return;
      }

      _logger.warn('flutter create failed in $presentationRoot');
      if (result.stderr.toString().trim().isNotEmpty) {
        _logger.err(result.stderr.toString().trim());
      }
      exitCode = result.exitCode;
    } on ProcessException catch (error) {
      _logger.warn(
        'flutter executable not found. Install Flutter or run manually:',
      );
      _logger.info('cd $presentationRoot && flutter ${args.join(' ')}');
      _logger.detail(error.message);
    }
  }

  String _packageRoot(String libPath) {
    final parts = p.split(p.normalize(libPath));
    final libIndex = parts.indexOf('lib');
    if (libIndex == -1) return libPath;
    return p.joinAll(parts.take(libIndex));
  }

  StateManagement? _stateOverride(String? value) {
    return switch (value) {
      'getx' => StateManagement.getx,
      'bloc' => StateManagement.bloc,
      'provider' => StateManagement.provider,
      'none' => StateManagement.none,
      _ => null,
    };
  }

  NetworkClient? _networkOverride(String? value) {
    return switch (value) {
      'dio' => NetworkClient.dio,
      'abstract' => NetworkClient.abstract,
      _ => null,
    };
  }

  LocalStorage? _storageOverride(String? value) {
    return switch (value) {
      'secure_storage' => LocalStorage.secureStorage,
      'shared_preferences' => LocalStorage.sharedPreferences,
      'hive' => LocalStorage.hive,
      'objectbox' => LocalStorage.objectbox,
      'abstract' => LocalStorage.abstract,
      _ => null,
    };
  }

  DependencyInjection? _dependencyInjectionOverride(String? value) {
    return switch (value) {
      'manual' => DependencyInjection.manual,
      'injectable' => DependencyInjection.injectable,
      _ => null,
    };
  }

  void _doctor() {
    final configFile = File(CleanArchitectConfig.fileName);
    if (!configFile.existsSync()) {
      _logger.warn('clean_architect.yaml not found. Run clean_architect init.');
      return;
    }

    final config = CleanArchitectConfig.fromFile(configFile);
    _logger.success('config loaded');
    _checkPath('domain', config.paths.domain);
    _checkPath('data', config.paths.data);
    _checkPath('presentation', config.paths.presentation);
    _checkPath('di', config.paths.di);

    if (config.network == NetworkClient.dio) {
      _logger.info('dependency check: add dio to the target project');
    }
    if (config.localStorage == LocalStorage.secureStorage) {
      _logger.info(
        'dependency check: add flutter_secure_storage to the target project',
      );
    }
    if (config.stateManagement == StateManagement.getx) {
      _logger.info('dependency check: add get to the target project');
    }
  }

  void _checkPath(String label, String path) {
    if (Directory(path).existsSync()) {
      _logger.success('$label path exists: $path');
    } else {
      _logger.warn('$label path does not exist yet: $path');
    }
  }
}
