import '../entities/catalog_entity.dart';
import '../repositories/catalog_repository.dart';

class GetCatalogListUseCase {
  const GetCatalogListUseCase(this._repository);

  final CatalogRepository _repository;

  Future<List<CatalogEntity>> call() {
    return _repository.getCatalogList();
  }
}
