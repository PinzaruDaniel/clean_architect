import 'package:path/path.dart' as p;

import '../data_paths.dart';
import '../generated_file.dart';
import '../generator.dart';

List<GeneratedFile> architectureTemplates(TemplateContext context) {
  final files = <GeneratedFile>[
    ..._domainFolders(context),
    ..._dataFolders(context),
    GeneratedFile(path: p.join(context.paths.di, '.gitkeep'), content: ''),
  ];

  return files;
}

List<GeneratedFile> _domainFolders(TemplateContext context) {
  return [
    GeneratedFile(
      path: p.join(context.paths.domain, 'entities', '.gitkeep'),
      content: '',
    ),
    GeneratedFile(
      path: p.join(context.paths.domain, 'repositories', '.gitkeep'),
      content: '',
    ),
    GeneratedFile(
      path: p.join(context.paths.domain, 'usecases', '.gitkeep'),
      content: '',
    ),
  ];
}

List<GeneratedFile> _dataFolders(TemplateContext context) {
  final paths = DataPaths.resolve(context.config, context.paths.data);
  return [
    GeneratedFile(path: p.join(paths.remoteModels, '.gitkeep'), content: ''),
    GeneratedFile(
      path: p.join(paths.remoteDataSources, '.gitkeep'),
      content: '',
    ),
    GeneratedFile(path: p.join(paths.localModels, '.gitkeep'), content: ''),
    GeneratedFile(
      path: p.join(paths.localDataSources, '.gitkeep'),
      content: '',
    ),
    GeneratedFile(path: p.join(paths.mappers, '.gitkeep'), content: ''),
    GeneratedFile(path: p.join(paths.repositories, '.gitkeep'), content: ''),
  ];
}
