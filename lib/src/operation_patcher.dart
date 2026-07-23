import 'dart:io';

import 'package:path/path.dart' as p;

import 'case_utils.dart';
import 'config.dart';
import 'generated_file.dart';
import 'operation_kind.dart';
import 'path_resolver.dart';

class OperationPatcher {
  OperationPatcher({required this.config});

  final CleanArchitectConfig config;
  final List<GeneratedFile> _files = [];

  List<GeneratedFile> plan({
    required OperationKind kind,
    required String featureName,
    required String operationName,
  }) {
    _files.clear();
    final feature = NameCases(featureName);
    final operation = NameCases(operationName);
    final paths = PathResolver(config).resolve(feature.snake);

    if (kind.includesRemote) {
      _patchRemoteSource(paths.data, feature, operation, kind);
    }
    if (kind.includesLocal) {
      _patchLocalSource(paths.data, feature, operation, kind);
      _patchDataModule(paths.data, feature, operation);
    }

    _patchRepository(paths.domain, feature, operation, kind);
    _patchRepositoryImpl(paths.data, paths.domain, feature, operation, kind);
    _patchController(
      paths.presentation,
      paths.domain,
      feature,
      operation,
      kind,
    );
    _patchPublicLibrary(paths.domain, feature, operation, kind);
    return List<GeneratedFile>.unmodifiable(_files);
  }

  void _patchPublicLibrary(
    String domainPath,
    NameCases feature,
    NameCases operation,
    OperationKind kind,
  ) {
    if (config.structure != ProjectStructure.verticalPackages) return;
    final path = p.join(
      _packageRoot(domainPath),
      'lib',
      '${feature.snake}.dart',
    );
    final file = File(path);
    if (!file.existsSync()) return;

    final useCaseNames = kind == OperationKind.cached
        ? [
            NameCases(_remoteMethodName(operation, kind)).snake,
            NameCases(_localMethodName(operation)).snake,
          ]
        : [operation.snake];
    final exports = <String>[
      "export 'src/domain/entities/${operation.snake}_entity.dart';",
      for (final useCaseName in useCaseNames)
        "export 'src/domain/usecases/${useCaseName}_use_case.dart';",
    ];
    var content = file.readAsStringSync();
    var changed = false;
    for (final export in exports) {
      if (content.contains(export)) continue;
      content = '${content.trimRight()}\n$export\n';
      changed = true;
    }
    if (changed) _write(path, content);
  }

  void _patchRemoteSource(
    String dataPath,
    NameCases feature,
    NameCases operation,
    OperationKind kind,
  ) {
    final path = p.join(
      dataPath,
      'remote',
      '${feature.snake}_remote_data_source.dart',
    );
    final importLine = "import 'models/${operation.snake}_dto.dart';";
    final methodName = _remoteMethodName(operation, kind);
    final annotation = config.network == NetworkClient.dio
        ? "  @GET('/${feature.snake}/${operation.snake}')\n"
        : '';
    final snippet =
        '''

$annotation  Future<${operation.pascal}Dto> $methodName();
''';
    final injectableImport =
        config.dependencyInjection == DependencyInjection.injectable
        ? "import 'package:injectable/injectable.dart';\n"
        : '';
    final classAnnotation =
        config.dependencyInjection == DependencyInjection.injectable
        ? '@lazySingleton\n'
        : '';
    final factoryAnnotation =
        config.dependencyInjection == DependencyInjection.injectable
        ? '  @factoryMethod\n'
        : '';
    final createContent = config.network == NetworkClient.abstract
        ? '''
$importLine

abstract interface class ${feature.pascal}RemoteDataSource {$snippet}
'''
        : '''
import 'package:dio/dio.dart';
${injectableImport}import 'package:retrofit/retrofit.dart';

$importLine

part '${feature.snake}_remote_data_source.g.dart';

$classAnnotation@RestApi(baseUrl: '')
abstract class ${feature.pascal}RemoteDataSource {
$factoryAnnotation  factory ${feature.pascal}RemoteDataSource(${config.dependencyInjection == DependencyInjection.injectable ? '@Named("main_dio") ' : ''}Dio dio) = _${feature.pascal}RemoteDataSource;
$snippet}
''';
    _patchClassFile(
      path: path,
      createContent: createContent,
      imports: [importLine],
      duplicateNeedle: 'Future<${operation.pascal}Dto> $methodName()',
      snippet: snippet,
    );
  }

  void _patchLocalSource(
    String dataPath,
    NameCases feature,
    NameCases operation,
    OperationKind kind,
  ) {
    final path = p.join(
      dataPath,
      'local',
      '${feature.snake}_local_data_source.dart',
    );
    final importLine = "import 'models/${operation.snake}_box.dart';";
    final methodName = kind == OperationKind.cached
        ? _localMethodName(operation)
        : operation.camel;
    final boxConstructor =
        config.localStorage == LocalStorage.hive ||
            config.localStorage == LocalStorage.objectbox
        ? '${operation.pascal}Box()'
        : 'const ${operation.pascal}Box()';

    final abstractSnippet =
        '''

  Future<${operation.pascal}Box> $methodName();
''';
    final implSnippet =
        '''

  @override
  Future<${operation.pascal}Box> $methodName() async {
    // TODO: Read ${operation.title.toLowerCase()} from local storage.
    return $boxConstructor;
  }
''';

    final file = File(path);
    if (!file.existsSync()) {
      final injectableImport =
          config.dependencyInjection == DependencyInjection.injectable
          ? "import 'package:injectable/injectable.dart';\n\n"
          : '';
      final implementationAnnotation =
          config.dependencyInjection == DependencyInjection.injectable
          ? '@LazySingleton(as: ${feature.pascal}LocalDataSource)\n'
          : '';
      _write(path, '''
$injectableImport$importLine

abstract class ${feature.pascal}LocalDataSource {$abstractSnippet}

${implementationAnnotation}class ${feature.pascal}LocalDataSourceImpl implements ${feature.pascal}LocalDataSource {
  const ${feature.pascal}LocalDataSourceImpl();$implSnippet}
''');
      return;
    }

    var content = file.readAsStringSync();
    if (content.contains('Future<${operation.pascal}Box> $methodName()')) {
      return;
    }

    content = _ensureImports(content, [importLine]);
    content = _insertBeforeClassEnd(
      content,
      'abstract class ${feature.pascal}LocalDataSource',
      abstractSnippet,
    );
    content = _insertBeforeClassEnd(
      content,
      'class ${feature.pascal}LocalDataSourceImpl',
      implSnippet,
    );
    _write(path, content);
  }

  void _patchDataModule(
    String dataPath,
    NameCases feature,
    NameCases operation,
  ) {
    if (config.dependencyInjection != DependencyInjection.injectable) return;
    if (config.localStorage != LocalStorage.hive &&
        config.localStorage != LocalStorage.objectbox) {
      return;
    }

    final isVertical = config.structure == ProjectStructure.verticalPackages;
    final path = isVertical
        ? p.join(_packageRoot(dataPath), 'lib', 'src', 'di', 'data_module.dart')
        : p.join(_packageRoot(dataPath), 'lib', 'data_module.dart');
    final importLine = isVertical
        ? "import '../data/local/models/${operation.snake}_box.dart';"
        : "import 'features/${feature.snake}/local/models/${operation.snake}_box.dart';";
    final methodName = '${operation.camel}Box';
    final boxClass = '${operation.pascal}Box';
    final snippet = config.localStorage == LocalStorage.hive
        ? '''
  @lazySingleton
  @preResolve
  Future<Box<$boxClass>> $methodName() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(${stableHiveTypeId('${feature.snake}_${operation.snake}')})) {
      Hive.registerAdapter(${boxClass}Adapter());
    }
    return Hive.openBox<$boxClass>('${operation.snake}_box');
  }
'''
        : '''
  @lazySingleton
  Box<$boxClass> $methodName(Store store) => Box<$boxClass>(store);
''';

    final file = File(path);
    if (!file.existsSync()) {
      _write(path, _createDataModule(importLine, snippet, isVertical));
      return;
    }

    var content = file.readAsStringSync();
    if (content.contains(' $methodName(')) {
      return;
    }

    content = _ensureImports(content, [importLine]);
    content = _insertBeforeClassEnd(
      content,
      'abstract class DataModule',
      snippet,
    );
    _write(path, content);
  }

  String _createDataModule(
    String featureImport,
    String boxSnippet,
    bool isVertical,
  ) {
    final imports = <String>[
      "import 'package:injectable/injectable.dart';",
      if (config.network == NetworkClient.dio) "import 'package:dio/dio.dart';",
      if (config.localStorage == LocalStorage.hive)
        "import 'package:hive_ce_flutter/hive_flutter.dart';",
      if (config.localStorage == LocalStorage.objectbox)
        "import 'package:path/path.dart' as p;",
      if (config.localStorage == LocalStorage.objectbox)
        "import 'package:path_provider/path_provider.dart';",
      featureImport,
      if (config.localStorage == LocalStorage.objectbox)
        isVertical
            ? "import '../../objectbox.g.dart';"
            : "import 'objectbox.g.dart';",
    ];
    final dio = config.network == NetworkClient.dio
        ? '''
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
'''
        : '';
    final init = config.localStorage == LocalStorage.hive
        ? ''
        : '''
  @lazySingleton
  @factoryMethod
  @preResolve
  Future<Store> asyncCreateStore() async {
    final directory = await getApplicationDocumentsDirectory();
    return openStore(directory: p.join(directory.path, 'objectbox'));
  }
''';

    return '''
${imports.toSet().join('\n')}

@module
abstract class DataModule {
$dio$init$boxSnippet
}
''';
  }

  void _patchRepository(
    String domainPath,
    NameCases feature,
    NameCases operation,
    OperationKind kind,
  ) {
    final path = p.join(
      domainPath,
      'repositories',
      '${feature.snake}_repository.dart',
    );
    final returnType = _returnType(operation);
    final imports = <String>[
      "import '../entities/${operation.snake}_entity.dart';",
      if (config.useEitherFailure) "import 'package:dartz/dartz.dart';",
      if (config.useEitherFailure) "import '${_failureImport(domainPath)}';",
    ];
    final methods = _repositoryMethodNames(
      operation,
      kind,
    ).map((method) => '\n  $returnType $method();\n').join();

    _patchClassFile(
      path: path,
      createContent:
          '''
${imports.join('\n')}

abstract interface class ${feature.pascal}Repository {$methods}
''',
      imports: imports,
      duplicateNeedle: _repositoryMethodNames(operation, kind).first,
      snippet: methods,
    );
  }

  void _patchRepositoryImpl(
    String dataPath,
    String domainPath,
    NameCases feature,
    NameCases operation,
    OperationKind kind,
  ) {
    final path = p.join(
      dataPath,
      'repositories',
      '${feature.snake}_repository_impl.dart',
    );
    final returnType = _returnType(operation);
    final imports = <String>[
      "import '${_packageImport(domainPath, 'entities/${operation.snake}_entity.dart')}';",
      "import '${_packageImport(domainPath, 'repositories/${feature.snake}_repository.dart')}';",
      if (config.useEitherFailure) "import 'package:dartz/dartz.dart';",
      if (config.useEitherFailure) "import '${_failureImport(domainPath)}';",
      if (kind.includesRemote)
        "import '../mappers/${operation.snake}_mapper.dart';",
      if (kind == OperationKind.local)
        "import '../mappers/${operation.snake}_mapper.dart';",
      if (kind == OperationKind.cached)
        "import '../mappers/${operation.snake}_box_mapper.dart';",
      if (kind.includesRemote)
        "import '../remote/${feature.snake}_remote_data_source.dart';",
      if (kind.includesLocal)
        "import '../local/${feature.snake}_local_data_source.dart';",
    ];
    final methods = _repositoryImplMethods(operation, kind, returnType);

    _patchClassFile(
      path: path,
      createContent:
          '''
${imports.toSet().join('\n')}

class ${feature.pascal}RepositoryImpl implements ${feature.pascal}Repository {
  const ${feature.pascal}RepositoryImpl({
    ${kind.includesRemote ? 'required ${feature.pascal}RemoteDataSource remoteDataSource,' : ''}
    ${kind.includesLocal ? 'required ${feature.pascal}LocalDataSource localDataSource,' : ''}
  })  ${kind.includesRemote ? ': _remoteDataSource = remoteDataSource' : ''}${kind.includesRemote && kind.includesLocal ? ',' : ''}
        ${kind.includesLocal ? '_localDataSource = localDataSource' : ''};

  ${kind.includesRemote ? 'final ${feature.pascal}RemoteDataSource _remoteDataSource;' : ''}
  ${kind.includesLocal ? 'final ${feature.pascal}LocalDataSource _localDataSource;' : ''}$methods}
''',
      imports: imports,
      duplicateNeedle: '${_repositoryMethodNames(operation, kind).first}()',
      snippet: methods,
    );
  }

  void _patchController(
    String presentationPath,
    String domainPath,
    NameCases feature,
    NameCases operation,
    OperationKind kind,
  ) {
    final path = p.join(
      presentationPath,
      'controllers',
      '${feature.snake}_controller.dart',
    );
    final remoteMethodName = _remoteMethodName(operation, kind);
    final localMethodName = _localMethodName(operation);
    final remoteUseCase = NameCases(remoteMethodName);
    final localUseCase = NameCases(localMethodName);
    final useCases = kind == OperationKind.cached
        ? [
            _UseCaseInfo(
              fileName: '${remoteUseCase.snake}_use_case.dart',
              className: '${remoteUseCase.pascal}UseCase',
              fieldName: '_${remoteUseCase.camel}UseCase',
              methodName: remoteMethodName,
            ),
            _UseCaseInfo(
              fileName: '${localUseCase.snake}_use_case.dart',
              className: '${localUseCase.pascal}UseCase',
              fieldName: '_${localUseCase.camel}UseCase',
              methodName: localMethodName,
            ),
          ]
        : [
            _UseCaseInfo(
              fileName: '${operation.snake}_use_case.dart',
              className: '${operation.pascal}UseCase',
              fieldName: '_${operation.camel}UseCase',
              methodName: operation.camel,
            ),
          ];
    final imports = <String>[
      "import 'package:get_it/get_it.dart';",
      for (final useCase in useCases)
        "import '${_packageImport(domainPath, 'usecases/${useCase.fileName}')}';",
    ];
    final fields = useCases
        .map(
          (useCase) =>
              '  final ${useCase.fieldName} = GetIt.instance.get<${useCase.className}>();',
        )
        .join('\n');
    final methods = useCases
        .map(
          (useCase) =>
              '''

  Future<void> ${useCase.methodName}() async {
    await ${useCase.fieldName}();
  }
''',
        )
        .join();

    _patchClassFile(
      path: path,
      createContent:
          '''
${imports.join('\n')}

class ${feature.pascal}Controller {
$fields$methods}
''',
      imports: imports,
      duplicateNeedle: 'Future<void> ${useCases.first.methodName}()',
      snippet: '\n$fields$methods',
    );
  }

  List<String> _repositoryMethodNames(NameCases operation, OperationKind kind) {
    return switch (kind) {
      OperationKind.remote => [operation.camel],
      OperationKind.local => [operation.camel],
      OperationKind.cached => [
        _remoteMethodName(operation, kind),
        _localMethodName(operation),
      ],
    };
  }

  String _repositoryImplMethods(
    NameCases operation,
    OperationKind kind,
    String returnType,
  ) {
    final methods = StringBuffer();
    if (kind.includesRemote) {
      final methodName = kind == OperationKind.cached
          ? _remoteMethodName(operation, kind)
          : operation.camel;
      methods.write('''

  @override
  $returnType $methodName() async {
${_wrapReturn('final dto = await _remoteDataSource.${_remoteMethodName(operation, kind)}();', 'dto.toEntity()')}
  }
''');
    }
    if (kind.includesLocal) {
      final methodName = kind == OperationKind.cached
          ? _localMethodName(operation)
          : operation.camel;
      final sourceMethod = kind == OperationKind.cached
          ? _localMethodName(operation)
          : operation.camel;
      methods.write('''

  @override
  $returnType $methodName() async {
${_wrapReturn('final box = await _localDataSource.$sourceMethod();', 'box.toEntity()')}
  }
''');
    }
    return methods.toString();
  }

  String _wrapReturn(String loadLine, String value) {
    if (!config.useEitherFailure) {
      return '''    $loadLine
    return $value;''';
    }

    return '''    try {
      $loadLine
      return right($value);
    } catch (error) {
      return left(Failure(error.toString()));
    }''';
  }

  String _returnType(NameCases operation) {
    final valueType = '${operation.pascal}Entity';
    if (config.useEitherFailure) {
      return 'Future<Either<Failure, $valueType>>';
    }
    return 'Future<$valueType>';
  }

  String _failureImport(String domainPath) {
    if (config.structure == ProjectStructure.verticalPackages) {
      return 'package:${_packageName(config.paths.core)}/core.dart';
    }
    return _packageRootImport(domainPath, 'failures/failure.dart');
  }

  String _remoteMethodName(NameCases operation, OperationKind kind) {
    if (kind != OperationKind.cached) return operation.camel;
    return 'sync${_cachedSubject(operation)}';
  }

  String _localMethodName(NameCases operation) {
    return 'stream${_cachedSubject(operation)}';
  }

  String _cachedSubject(NameCases operation) {
    final name = operation.pascal;
    if (name.startsWith('Sync') && name.length > 4) {
      return name.substring(4);
    }
    if (name.startsWith('Stream') && name.length > 6) {
      return name.substring(6);
    }
    return name;
  }

  void _patchClassFile({
    required String path,
    required String createContent,
    required List<String> imports,
    required String duplicateNeedle,
    required String snippet,
  }) {
    final file = File(path);
    if (!file.existsSync()) {
      _write(path, createContent);
      return;
    }

    var content = file.readAsStringSync();
    if (content.contains(duplicateNeedle)) {
      return;
    }

    content = _ensureImports(content, imports);
    content = _insertBeforeLastBrace(content, snippet);
    _write(path, content);
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

  void _write(String path, String content) {
    final index = _files.indexWhere(
      (file) => p.normalize(file.path) == p.normalize(path),
    );
    final generated = GeneratedFile(
      path: path,
      content: content,
      allowUpdate: File(path).existsSync(),
    );
    if (index == -1) {
      _files.add(generated);
    } else {
      _files[index] = generated;
    }
  }
}

class _UseCaseInfo {
  const _UseCaseInfo({
    required this.fileName,
    required this.className,
    required this.fieldName,
    required this.methodName,
  });

  final String fileName;
  final String className;
  final String fieldName;
  final String methodName;
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

String _packageRootImport(String basePath, String path) {
  final packageLib = p.join(_packageRoot(basePath), 'lib');
  return _packageImport(packageLib, path);
}

String _packageImport(String basePath, String path) {
  final parts = p.split(p.normalize(basePath));
  final libIndex = parts.indexOf('lib');
  if (libIndex <= 0) return path;

  final packageName = parts[libIndex - 1];
  final libPath = p.url.joinAll(parts.skip(libIndex + 1).followedBy([path]));
  return 'package:$packageName/$libPath';
}
