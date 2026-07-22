import 'package:path/path.dart' as p;

import '../case_utils.dart';
import '../config.dart';
import '../generated_file.dart';
import '../generator.dart';

List<GeneratedFile> operationTemplates(
  TemplateContext context, {
  required NameCases operation,
  required OperationKind kind,
}) {
  final files = <GeneratedFile>[];

  if (context.config.useEitherFailure) {
    files.add(_failure(context));
  }

  files.add(_entity(context, operation));

  if (kind.includesRemote) {
    files
      ..add(_dto(context, operation))
      ..add(_remoteMapper(context, operation, kind));
  }

  if (kind.includesLocal) {
    files
      ..add(_box(context, operation))
      ..add(_localMapper(context, operation, kind));
  }

  if (kind == OperationKind.cached) {
    final remoteMethodName = _cachedRemoteMethodName(operation);
    final localMethodName = _cachedLocalMethodName(operation);
    files
      ..add(
        _useCase(
          context,
          operation,
          useCaseName: NameCases(remoteMethodName),
          repositoryMethodName: remoteMethodName,
        ),
      )
      ..add(
        _useCase(
          context,
          operation,
          useCaseName: NameCases(localMethodName),
          repositoryMethodName: localMethodName,
        ),
      );
  } else {
    files.add(_useCase(context, operation));
  }

  return files;
}

enum OperationKind {
  remote,
  local,
  cached;

  bool get includesRemote => this == remote || this == cached;
  bool get includesLocal => this == local || this == cached;
}

GeneratedFile _failure(TemplateContext context) {
  return GeneratedFile(
    path: p.join(
      _packageRoot(context.paths.domain),
      'lib',
      'failures',
      'failure.dart',
    ),
    content: '''
class Failure {
  const Failure(this.message);

  final String message;
}
''',
  );
}

GeneratedFile _entity(TemplateContext context, NameCases operation) {
  return GeneratedFile(
    path: p.join(
      context.paths.domain,
      'entities',
      '${operation.snake}_entity.dart',
    ),
    content: context.config.models.useFreezed
        ? '''
import 'package:freezed_annotation/freezed_annotation.dart';

part '${operation.snake}_entity.freezed.dart';

@freezed
abstract class ${operation.pascal}Entity with _\$${operation.pascal}Entity {
  const factory ${operation.pascal}Entity({
    required String id,
  }) = _${operation.pascal}Entity;
}
'''
        : '''
class ${operation.pascal}Entity {
  const ${operation.pascal}Entity({
    this.id = 0,
  });

  final int id;
}
''',
  );
}

GeneratedFile _dto(TemplateContext context, NameCases operation) {
  return GeneratedFile(
    path: p.join(
      context.paths.data,
      'remote',
      'models',
      '${operation.snake}_dto.dart',
    ),
    content: context.config.models.useFreezed
        ? '''
import 'package:freezed_annotation/freezed_annotation.dart';

part '${operation.snake}_dto.freezed.dart';
part '${operation.snake}_dto.g.dart';

@freezed
abstract class ${operation.pascal}Dto with _\$${operation.pascal}Dto {
  const factory ${operation.pascal}Dto({
    required String id,
  }) = _${operation.pascal}Dto;

  factory ${operation.pascal}Dto.fromJson(Map<String, dynamic> json) =>
      _\$${operation.pascal}DtoFromJson(json);
}
'''
        : '''
class ${operation.pascal}Dto {
  const ${operation.pascal}Dto({
    required this.id,
  });

  factory ${operation.pascal}Dto.fromJson(Map<String, dynamic> json) {
    return ${operation.pascal}Dto(id: json['id'] as String);
  }

  final String id;

  Map<String, dynamic> toJson() {
    return {'id': id};
  }
}
''',
  );
}

GeneratedFile _box(TemplateContext context, NameCases operation) {
  return GeneratedFile(
    path: p.join(
      context.paths.data,
      'local',
      'models',
      '${operation.snake}_box.dart',
    ),
    content: switch (context.config.localStorage) {
      LocalStorage.hive =>
        '''
import 'package:hive_ce/hive.dart';

part '${operation.snake}_box.g.dart';

@HiveType(typeId: ${stableHiveTypeId('${context.cases.snake}_${operation.snake}')})
class ${operation.pascal}Box extends HiveObject {
  ${operation.pascal}Box({
    this.id = 0,
  });

  @HiveField(0)
  int id;
}
''',
      LocalStorage.objectbox =>
        '''
import 'package:objectbox/objectbox.dart';

@Entity()
class ${operation.pascal}Box {
  ${operation.pascal}Box({
    this.id = 0,
  });

  @Id()
  int id;
}
''',
      _ =>
        '''
class ${operation.pascal}Box {
  const ${operation.pascal}Box({
    this.id = 0,
  });

  final int id;
}
''',
    },
  );
}

GeneratedFile _remoteMapper(
  TemplateContext context,
  NameCases operation,
  OperationKind kind,
) {
  final dtoToBox = kind == OperationKind.cached
      ? '''

  ${operation.pascal}Box toBox() {
    return ${operation.pascal}Box(id: int.tryParse(id) ?? 0);
  }
'''
      : '';
  final boxImport = kind == OperationKind.cached
      ? "import '../local/models/${operation.snake}_box.dart';\n"
      : '';

  return GeneratedFile(
    path: p.join(
      context.paths.data,
      'mappers',
      '${operation.snake}_mapper.dart',
    ),
    content:
        '''
import '${_domainImport(context, 'entities/${operation.snake}_entity.dart')}';
${boxImport}import '../remote/models/${operation.snake}_dto.dart';

extension ${operation.pascal}DtoMapper on ${operation.pascal}Dto {
  ${operation.pascal}Entity toEntity() {
    return ${operation.pascal}Entity(id: id);
  }$dtoToBox
}
''',
  );
}

GeneratedFile _localMapper(
  TemplateContext context,
  NameCases operation,
  OperationKind kind,
) {
  if (kind == OperationKind.cached) {
    return GeneratedFile(
      path: p.join(
        context.paths.data,
        'mappers',
        '${operation.snake}_box_mapper.dart',
      ),
      content:
          '''
import '${_domainImport(context, 'entities/${operation.snake}_entity.dart')}';
import '../local/models/${operation.snake}_box.dart';

extension ${operation.pascal}BoxMapper on ${operation.pascal}Box {
  ${operation.pascal}Entity toEntity() {
    return ${operation.pascal}Entity(id: id.toString());
  }
}
''',
    );
  }

  return GeneratedFile(
    path: p.join(
      context.paths.data,
      'mappers',
      '${operation.snake}_mapper.dart',
    ),
    content:
        '''
import '${_domainImport(context, 'entities/${operation.snake}_entity.dart')}';
import '../local/models/${operation.snake}_box.dart';

extension ${operation.pascal}BoxMapper on ${operation.pascal}Box {
  ${operation.pascal}Entity toEntity() {
    return ${operation.pascal}Entity(id: id.toString());
  }
}
''',
  );
}

GeneratedFile _useCase(
  TemplateContext context,
  NameCases operation, {
  NameCases? useCaseName,
  String? repositoryMethodName,
}) {
  final name = useCaseName ?? operation;
  final className = '${name.pascal}UseCase';
  final fileName = '${name.snake}_use_case.dart';
  final methodName = repositoryMethodName ?? operation.camel;
  final returnType = _returnType(context, '${operation.pascal}Entity');
  final eitherImport = context.config.useEitherFailure
      ? "import 'package:dartz/dartz.dart';\n\nimport '../failures/failure.dart';\n"
      : '';

  return GeneratedFile(
    path: p.join(context.paths.domain, 'usecases', fileName),
    content:
        '''
${eitherImport}import '../entities/${operation.snake}_entity.dart';
import '../repositories/${context.cases.snake}_repository.dart';

class $className {
  const $className(this._repository);

  final ${context.cases.pascal}Repository _repository;

  $returnType call() {
    return _repository.$methodName();
  }
}
''',
  );
}

String _cachedRemoteMethodName(NameCases operation) {
  return 'sync${_cachedSubject(operation)}';
}

String _cachedLocalMethodName(NameCases operation) {
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

String _returnType(TemplateContext context, String valueType) {
  if (context.config.useEitherFailure) {
    return 'Future<Either<Failure, $valueType>>';
  }
  return 'Future<$valueType>';
}

String _domainImport(TemplateContext context, String path) {
  return _packageImport(context.paths.domain, path);
}

String _packageImport(String basePath, String path) {
  final parts = p.split(p.normalize(basePath));
  final libIndex = parts.indexOf('lib');
  if (libIndex <= 0) return path;

  final packageName = parts[libIndex - 1];
  final libPath = p.url.joinAll(parts.skip(libIndex + 1).followedBy([path]));
  return 'package:$packageName/$libPath';
}

String _packageRoot(String libPath) {
  final parts = p.split(p.normalize(libPath));
  final libIndex = parts.indexOf('lib');
  if (libIndex == -1) return libPath;
  return p.joinAll(parts.take(libIndex));
}
