import 'models/catalog_dto.dart';

abstract interface class CatalogRemoteDataSource {
  Future<List<CatalogDto>> getItems();
}
