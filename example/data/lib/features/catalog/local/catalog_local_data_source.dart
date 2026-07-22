import 'models/catalog_box.dart';

abstract class CatalogLocalDataSource {
  Future<void> cacheItems(List<Object> items);
}


class CatalogLocalDataSourceImpl implements CatalogLocalDataSource {
  const CatalogLocalDataSourceImpl();

  static Future<CatalogLocalDataSource> init() async {
    return const CatalogLocalDataSourceImpl();
  }

  @override
  Future<void> cacheItems(List<Object> items) async {
    final placeholder = const CatalogBox();
    // TODO: Cache catalog items using your local storage. Remove placeholder when implemented.
    placeholder.id;
  }
}
