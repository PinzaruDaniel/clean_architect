import 'package:path/path.dart' as p;

import '../config.dart';
import '../generated_file.dart';
import '../generator.dart';

List<GeneratedFile> featureTemplates(TemplateContext context) {
  final feature = context.cases;
  final files = <GeneratedFile>[
    GeneratedFile(
      path: p.join(
          context.paths.domain, 'entities', '${feature.snake}_entity.dart'),
      content: '''
class ${feature.pascal}Entity {
  const ${feature.pascal}Entity({
    required this.id,
  });

  final String id;
}
''',
    ),
    GeneratedFile(
      path: p.join(
        context.paths.domain,
        'repositories',
        '${feature.snake}_repository.dart',
      ),
      content: '''
import '../entities/${feature.snake}_entity.dart';

abstract interface class ${feature.pascal}Repository {
  Future<List<${feature.pascal}Entity>> get${feature.pascal}List();
}
''',
    ),
    GeneratedFile(
      path: p.join(
        context.paths.domain,
        'usecases',
        'get_${feature.snake}_list_use_case.dart',
      ),
      content: '''
import '../entities/${feature.snake}_entity.dart';
import '../repositories/${feature.snake}_repository.dart';

class Get${feature.pascal}ListUseCase {
  const Get${feature.pascal}ListUseCase(this._repository);

  final ${feature.pascal}Repository _repository;

  Future<List<${feature.pascal}Entity>> call() {
    return _repository.get${feature.pascal}List();
  }
}
''',
    ),
    GeneratedFile(
      path: p.join(
          context.paths.data, 'remote', 'models', '${feature.snake}_dto.dart'),
      content: _dto(context),
    ),
    GeneratedFile(
      path:
          p.join(context.paths.data, 'mappers', '${feature.snake}_mapper.dart'),
      content: _mapper(context),
    ),
    GeneratedFile(
      path: p.join(
        context.paths.data,
        'remote',
        '${feature.snake}_remote_data_source.dart',
      ),
      content: _remoteSource(context),
    ),
    GeneratedFile(
      path: p.join(context.paths.data, 'local', 'models', '.gitkeep'),
      content: '',
    ),
    GeneratedFile(
      path: p.join(
        context.paths.data,
        'local',
        '${feature.snake}_local_data_source.dart',
      ),
      content: '''
class ${feature.pascal}LocalDataSource {
  const ${feature.pascal}LocalDataSource();

  Future<void> cacheItems(List<Object> items) async {
    // TODO: Cache ${feature.title.toLowerCase()} items.
  }
}
''',
    ),
    GeneratedFile(
      path: p.join(
        context.paths.data,
        'repositories',
        '${feature.snake}_repository_impl.dart',
      ),
      content: _repositoryImpl(context),
    ),
    _di(context),
  ];

  if (!context.skipPresentation) {
    files.addAll(_presentation(context));
  }

  return files;
}

String _dto(TemplateContext context) {
  final feature = context.cases;
  if (context.config.models.useJsonSerializable) {
    return '''
import 'package:json_annotation/json_annotation.dart';

part '${feature.snake}_dto.g.dart';

@JsonSerializable()
class ${feature.pascal}Dto {
  const ${feature.pascal}Dto({
    required this.id,
  });

  factory ${feature.pascal}Dto.fromJson(Map<String, dynamic> json) {
    return _\$${feature.pascal}DtoFromJson(json);
  }

  final String id;

  Map<String, dynamic> toJson() => _\$${feature.pascal}DtoToJson(this);
}
''';
  }

  return '''
class ${feature.pascal}Dto {
  const ${feature.pascal}Dto({
    required this.id,
  });

  factory ${feature.pascal}Dto.fromJson(Map<String, dynamic> json) {
    return ${feature.pascal}Dto(id: json['id'] as String);
  }

  final String id;

  Map<String, dynamic> toJson() {
    return {'id': id};
  }
}
''';
}

String _mapper(TemplateContext context) {
  final feature = context.cases;
  final entityImport = _domainImport(
    context,
    'entities/${feature.snake}_entity.dart',
  );

  return '''
import '$entityImport';
import '../remote/models/${feature.snake}_dto.dart';

extension ${feature.pascal}DtoMapper on ${feature.pascal}Dto {
  ${feature.pascal}Entity toEntity() {
    return ${feature.pascal}Entity(id: id);
  }
}
''';
}

String _remoteSource(TemplateContext context) {
  final feature = context.cases;
  final dioImport = context.config.network == NetworkClient.dio
      ? "import 'package:dio/dio.dart';\n"
      : '';
  final constructor = context.config.network == NetworkClient.dio
      ? '''
  ${feature.pascal}RemoteDataSource(this._dio);

  final Dio _dio;
'''
      : '''
  const ${feature.pascal}RemoteDataSource();
''';
  final fetch = context.config.network == NetworkClient.dio
      ? '''
    final response = await _dio.get<List<dynamic>>('/${feature.snake}');
    return (response.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(${feature.pascal}Dto.fromJson)
        .toList(growable: false);
'''
      : '''
    // TODO: Fetch ${feature.title.toLowerCase()} items from your API.
    return const [];
''';

  return '''
${dioImport}import '../remote/models/${feature.snake}_dto.dart';

class ${feature.pascal}RemoteDataSource {
$constructor
  Future<List<${feature.pascal}Dto>> getItems() async {
$fetch  }
}
''';
}

String _repositoryImpl(TemplateContext context) {
  final feature = context.cases;
  final entityImport = _domainImport(
    context,
    'entities/${feature.snake}_entity.dart',
  );
  final repositoryImport = _domainImport(
    context,
    'repositories/${feature.snake}_repository.dart',
  );

  return '''
import '$entityImport';
import '$repositoryImport';
import '../mappers/${feature.snake}_mapper.dart';
import '../local/${feature.snake}_local_data_source.dart';
import '../remote/${feature.snake}_remote_data_source.dart';

class ${feature.pascal}RepositoryImpl implements ${feature.pascal}Repository {
  const ${feature.pascal}RepositoryImpl({
    required ${feature.pascal}RemoteDataSource remoteDataSource,
    required ${feature.pascal}LocalDataSource localDataSource,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource;

  final ${feature.pascal}RemoteDataSource _remoteDataSource;
  final ${feature.pascal}LocalDataSource _localDataSource;

  @override
  Future<List<${feature.pascal}Entity>> get${feature.pascal}List() async {
    final items = await _remoteDataSource.getItems();
    await _localDataSource.cacheItems(items);
    return items.map((item) => item.toEntity()).toList(growable: false);
  }
}
''';
}

GeneratedFile _di(TemplateContext context) {
  final feature = context.cases;

  return GeneratedFile(
    path: p.join(context.paths.di, '${feature.snake}_di.dart'),
    content: '''
import '${_dataImport(context, 'repositories/${feature.snake}_repository_impl.dart')}';
import '${_dataImport(context, 'local/${feature.snake}_local_data_source.dart')}';
import '${_dataImport(context, 'remote/${feature.snake}_remote_data_source.dart')}';
import '${_domainImport(context, 'repositories/${feature.snake}_repository.dart')}';
import '${_domainImport(context, 'usecases/get_${feature.snake}_list_use_case.dart')}';

class ${feature.pascal}Dependencies {
  const ${feature.pascal}Dependencies({
    required this.repository,
    required this.get${feature.pascal}ListUseCase,
  });

  final ${feature.pascal}Repository repository;
  final Get${feature.pascal}ListUseCase get${feature.pascal}ListUseCase;
}

${feature.pascal}Dependencies build${feature.pascal}Dependencies({
  required ${feature.pascal}RemoteDataSource remoteDataSource,
  required ${feature.pascal}LocalDataSource localDataSource,
}) {
  final repository = ${feature.pascal}RepositoryImpl(
    remoteDataSource: remoteDataSource,
    localDataSource: localDataSource,
  );

  return ${feature.pascal}Dependencies(
    repository: repository,
    get${feature.pascal}ListUseCase: Get${feature.pascal}ListUseCase(repository),
  );
}
''',
  );
}

List<GeneratedFile> _presentation(TemplateContext context) {
  final feature = context.cases;

  return [
    GeneratedFile(
      path: p.join(context.paths.presentation, 'widgets',
          '${feature.snake}_view_item.dart'),
      content: '''
class ${feature.pascal}ViewItem {
  const ${feature.pascal}ViewItem({
    required this.id,
  });

  final String id;
}
''',
    ),
    GeneratedFile(
      path: p.join(context.paths.presentation, 'controllers',
          '${feature.snake}_controller.dart'),
      content: _controller(context),
    ),
    GeneratedFile(
      path: p.join(
          context.paths.presentation, 'pages', '${feature.snake}_page.dart'),
      content: _page(context),
    ),
  ];
}

String _controller(TemplateContext context) {
  final feature = context.cases;
  final getxImport = context.config.stateManagement == StateManagement.getx
      ? "import 'package:get/get.dart';\n"
      : '';
  final baseClass = context.config.stateManagement == StateManagement.getx
      ? ' extends GetxController'
      : '';

  return '''
${getxImport}import '${_domainPresentationImport(context, 'usecases/get_${feature.snake}_list_use_case.dart')}';
import '../widgets/${feature.snake}_view_item.dart';

class ${feature.pascal}Controller$baseClass {
  ${feature.pascal}Controller(this._get${feature.pascal}ListUseCase);

  final Get${feature.pascal}ListUseCase _get${feature.pascal}ListUseCase;
  var items = const <${feature.pascal}ViewItem>[];

  Future<void> load() async {
    final entities = await _get${feature.pascal}ListUseCase();
    items = entities
        .map((entity) => ${feature.pascal}ViewItem(id: entity.id))
        .toList(growable: false);
  }
}
''';
}

String _page(TemplateContext context) {
  final feature = context.cases;
  if (context.config.stateManagement == StateManagement.getx) {
    return '''
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/${feature.snake}_controller.dart';

class ${feature.pascal}Page extends GetView<${feature.pascal}Controller> {
  const ${feature.pascal}Page({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('${feature.title}')),
      body: const Center(child: Text('${feature.title}')),
    );
  }
}
''';
  }

  return '''
import 'package:flutter/material.dart';

class ${feature.pascal}Page extends StatelessWidget {
  const ${feature.pascal}Page({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('${feature.title}')),
      body: const Center(child: Text('${feature.title}')),
    );
  }
}
''';
}

String _domainImport(TemplateContext context, String path) {
  return _packageImport(context.paths.domain, path);
}

String _dataImport(TemplateContext context, String path) {
  return _packageImport(context.paths.data, path);
}

String _domainPresentationImport(TemplateContext context, String path) {
  return _domainImport(context, path);
}

String _packageImport(String basePath, String path) {
  final parts = p.split(p.normalize(basePath));
  final libIndex = parts.indexOf('lib');
  if (libIndex <= 0) return path;

  final packageName = parts[libIndex - 1];
  final libPath = p.url.joinAll(parts.skip(libIndex + 1).followedBy([path]));
  return 'package:$packageName/$libPath';
}
