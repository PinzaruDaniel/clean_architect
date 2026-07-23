import 'package:path/path.dart' as p;

import 'case_utils.dart';
import 'config.dart';

class FeaturePaths {
  const FeaturePaths({
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

class PathResolver {
  const PathResolver(this.config);

  final CleanArchitectConfig config;

  FeaturePaths resolve(String featureName) {
    final feature = NameCases(featureName).snake;

    return switch (config.structure) {
      ProjectStructure.featureFirst => FeaturePaths(
        domain: p.join(config.paths.domain, 'features', feature),
        data: p.join(config.paths.data, feature),
        presentation: p.join(config.paths.presentation, 'features', feature),
        di: p.join(config.paths.di, 'features', feature),
      ),
      ProjectStructure.layeredPackages => FeaturePaths(
        domain: p.join(config.paths.domain, 'features', feature),
        data: p.join(config.paths.data, feature),
        presentation: config.paths.presentation,
        di: config.paths.di,
      ),
      ProjectStructure.verticalPackages => FeaturePaths(
        domain: p.join(config.paths.features, feature, 'lib', 'src', 'domain'),
        data: p.join(config.paths.features, feature, 'lib', 'src', 'data'),
        presentation: p.join(
          config.paths.features,
          feature,
          'lib',
          'src',
          'presentation',
        ),
        di: p.join(config.paths.features, feature, 'lib', 'src', 'di'),
      ),
    };
  }
}
