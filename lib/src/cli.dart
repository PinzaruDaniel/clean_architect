import 'dart:io';

import 'package:args/args.dart';
import 'package:mason_logger/mason_logger.dart';

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
          ..addFlag('dry-run', negatable: false));

    parser.addCommand('doctor');

    parser.addCommand(
      'create',
      ArgParser()
        ..addFlag('dry-run', negatable: false)
        ..addFlag('overwrite', negatable: false)
        ..addFlag('force', abbr: 'f', negatable: false)
        ..addFlag('skip-presentation', negatable: false)
        ..addOption('state', allowed: ['getx', 'none'])
        ..addOption('network', allowed: ['dio', 'abstract'])
        ..addOption('storage', allowed: ['secure_storage', 'abstract'])
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
              'Usage: clean_architect create usecase <name> --feature <feature>');
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
      localStorage: _storageOverride(results['storage'] as String?) ??
          config.localStorage,
      useAssetGenerator: config.useAssetGenerator,
      useEitherFailure: results.wasParsed('use-either-failure')
          ? results['use-either-failure'] == true
          : config.useEitherFailure,
      dependencyInjection: _dependencyInjectionOverride(
            results['dependency-injection'] as String? ??
                results['di'] as String?,
          ) ??
          config.dependencyInjection,
      models: config.models,
      paths: config.paths,
    );
  }

  StateManagement? _stateOverride(String? value) {
    return switch (value) {
      'getx' => StateManagement.getx,
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
