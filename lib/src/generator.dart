import 'package:path/path.dart' as p;

import 'case_utils.dart';
import 'config.dart';
import 'generated_file.dart';
import 'path_resolver.dart';
import 'templates/auth_templates.dart';
import 'templates/feature_templates.dart';
import 'templates/package_templates.dart';
import 'templates/architecture_templates.dart';

class CleanArchitectGenerator {
  CleanArchitectGenerator(this.config) : _paths = PathResolver(config);

  final CleanArchitectConfig config;
  final PathResolver _paths;

  List<GeneratedFile> architecture({bool skipPresentation = false}) {
    final cases = NameCases('base_feature');
    final paths = _paths.resolve(cases.snake);
    final context = TemplateContext(
      config: config,
      cases: cases,
      paths: paths,
      skipPresentation: skipPresentation,
    );

    return [
      ...packageTemplates(context, includePresentation: !skipPresentation),
      ...architectureTemplates(context),
    ];
  }

  List<GeneratedFile> auth({bool skipPresentation = false}) {
    final cases = NameCases('auth');
    final paths = _paths.resolve(cases.snake);
    final context = TemplateContext(
      config: config,
      cases: cases,
      paths: paths,
      skipPresentation: skipPresentation,
    );

    return [
      ...packageTemplates(context, includePresentation: !skipPresentation),
      ...authTemplates(context),
    ];
  }

  List<GeneratedFile> feature(
    String name, {
    bool skipPresentation = false,
  }) {
    final cases = NameCases(name);
    final paths = _paths.resolve(cases.snake);
    final context = TemplateContext(
      config: config,
      cases: cases,
      paths: paths,
      skipPresentation: skipPresentation,
    );

    return [
      ...packageTemplates(context, includePresentation: !skipPresentation),
      ...featureTemplates(context),
    ];
  }

  List<GeneratedFile> useCase(String name, {required String feature}) {
    final featureCases = NameCases(feature);
    final useCaseCases = NameCases(name);
    final paths = _paths.resolve(featureCases.snake);

    return [
      GeneratedFile(
        path: p.join(
          paths.domain,
          'usecases',
          '${useCaseCases.snake}_use_case.dart',
        ),
        content: '''
class ${useCaseCases.pascal}UseCase {
  const ${useCaseCases.pascal}UseCase();

  Future<void> call() async {
    // TODO: Implement ${useCaseCases.title.toLowerCase()}.
  }
}
''',
      ),
    ];
  }

  List<GeneratedFile> repository(String feature) {
    final cases = NameCases(feature);
    final paths = _paths.resolve(cases.snake);

    return [
      GeneratedFile(
        path: p.join(
            paths.domain, 'repositories', '${cases.snake}_repository.dart'),
        content: '''
abstract interface class ${cases.pascal}Repository {
  Future<void> execute();
}
''',
      ),
      GeneratedFile(
        path: p.join(
          paths.data,
          'repositories',
          '${cases.snake}_repository_impl.dart',
        ),
        content: '''
import '${_packageImport(paths.domain, 'repositories/${cases.snake}_repository.dart')}';

class ${cases.pascal}RepositoryImpl implements ${cases.pascal}Repository {
  const ${cases.pascal}RepositoryImpl();

  @override
  Future<void> execute() async {
    // TODO: Implement ${cases.title.toLowerCase()} repository behavior.
  }
}
''',
      ),
    ];
  }
}

class TemplateContext {
  const TemplateContext({
    required this.config,
    required this.cases,
    required this.paths,
    required this.skipPresentation,
  });

  final CleanArchitectConfig config;
  final NameCases cases;
  final FeaturePaths paths;
  final bool skipPresentation;
}

String _packageImport(String basePath, String path) {
  final parts = p.split(p.normalize(basePath));
  final libIndex = parts.indexOf('lib');
  if (libIndex <= 0) return path;

  final packageName = parts[libIndex - 1];
  final libPath = p.url.joinAll(parts.skip(libIndex + 1).followedBy([path]));
  return 'package:$packageName/$libPath';
}
