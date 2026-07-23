import 'package:path/path.dart' as p;

import 'config.dart';

class DataPaths {
  const DataPaths({
    required this.root,
    required this.remoteDataSources,
    required this.localDataSources,
    required this.remoteModels,
    required this.localModels,
    required this.mappers,
    required this.repositories,
  });

  factory DataPaths.resolve(
    CleanArchitectConfig config,
    String featureDataRoot,
  ) {
    return switch (config.dataLayout) {
      DataLayout.sourceFirst => DataPaths(
        root: featureDataRoot,
        remoteDataSources: p.join(featureDataRoot, 'remote'),
        localDataSources: p.join(featureDataRoot, 'local'),
        remoteModels: p.join(featureDataRoot, 'remote', 'models'),
        localModels: p.join(featureDataRoot, 'local', 'models'),
        mappers: p.join(featureDataRoot, 'mappers'),
        repositories: p.join(featureDataRoot, 'repositories'),
      ),
      DataLayout.typeFirst => DataPaths(
        root: featureDataRoot,
        remoteDataSources: p.join(featureDataRoot, 'data_sources', 'remote'),
        localDataSources: p.join(featureDataRoot, 'data_sources', 'local'),
        remoteModels: p.join(featureDataRoot, 'models', 'remote'),
        localModels: p.join(featureDataRoot, 'models', 'local'),
        mappers: p.join(featureDataRoot, 'mappers'),
        repositories: p.join(featureDataRoot, 'repositories'),
      ),
    };
  }

  final String root;
  final String remoteDataSources;
  final String localDataSources;
  final String remoteModels;
  final String localModels;
  final String mappers;
  final String repositories;
}

String relativeDartImport({
  required String fromDirectory,
  required String targetPath,
}) {
  return p
      .relative(targetPath, from: fromDirectory)
      .split(p.separator)
      .join('/');
}
