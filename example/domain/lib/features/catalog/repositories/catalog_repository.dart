import '../entities/catalog_entity.dart';

abstract interface class CatalogRepository {
  Future<List<CatalogEntity>> getCatalogList();
}
