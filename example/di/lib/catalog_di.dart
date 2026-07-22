import 'package:data/features/catalog/repositories/catalog_repository_impl.dart';
import 'package:data/features/catalog/local/catalog_local_data_source.dart';
import 'package:data/features/catalog/remote/catalog_remote_data_source.dart';
import 'package:domain/features/catalog/repositories/catalog_repository.dart';
import 'package:domain/features/catalog/usecases/get_catalog_list_use_case.dart';

class CatalogDependencies {
  const CatalogDependencies({
    required this.repository,
    required this.getCatalogListUseCase,
  });

  final CatalogRepository repository;
  final GetCatalogListUseCase getCatalogListUseCase;
}

CatalogDependencies buildCatalogDependencies({
  required CatalogRemoteDataSource remoteDataSource,
  required CatalogLocalDataSource localDataSource,
}) {
  final repository = CatalogRepositoryImpl(
    remoteDataSource: remoteDataSource,
    localDataSource: localDataSource,
  );

  return CatalogDependencies(
    repository: repository,
    getCatalogListUseCase: GetCatalogListUseCase(repository),
  );
}
