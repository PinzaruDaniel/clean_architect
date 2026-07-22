import 'package:path/path.dart' as p;

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
  return [
    GeneratedFile(
      path: p.join(context.paths.data, 'remote', 'models', '.gitkeep'),
      content: '',
    ),
    GeneratedFile(
      path: p.join(context.paths.data, 'remote', '.gitkeep'),
      content: '',
    ),
    GeneratedFile(
      path: p.join(context.paths.data, 'local', 'models', '.gitkeep'),
      content: '',
    ),
    GeneratedFile(
      path: p.join(context.paths.data, 'local', '.gitkeep'),
      content: '',
    ),
    GeneratedFile(
      path: p.join(context.paths.data, 'mappers', '.gitkeep'),
      content: '',
    ),
    GeneratedFile(
      path: p.join(context.paths.data, 'repositories', '.gitkeep'),
      content: '',
    ),
  ];
}
