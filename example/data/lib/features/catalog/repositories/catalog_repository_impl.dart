import 'package:domain/features/catalog/entities/catalog_entity.dart';
import 'package:domain/features/catalog/repositories/catalog_repository.dart';
import '../mappers/catalog_mapper.dart';
import '../local/catalog_local_data_source.dart';
import '../remote/catalog_remote_data_source.dart';


class CatalogRepositoryImpl implements CatalogRepository {
  const CatalogRepositoryImpl({
    required CatalogRemoteDataSource remoteDataSource,
    required CatalogLocalDataSource localDataSource,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource;

  final CatalogRemoteDataSource _remoteDataSource;
  final CatalogLocalDataSource _localDataSource;

  @override
  Future<List<CatalogEntity>> getCatalogList() async {
    final items = await _remoteDataSource.getItems();
    await _localDataSource.cacheItems(items);
    return items.map((item) => item.toEntity()).toList(growable: false);
  }
}
