import 'package:domain/features/catalog/usecases/get_catalog_list_use_case.dart';
import 'package:get_it/get_it.dart';

class CatalogController {
  final _getCatalogListUseCase = GetIt.instance.get<GetCatalogListUseCase>();

  var items = const <String>[];

  Future<void> load() async {
    final entities = await _getCatalogListUseCase();
    items = entities.map((entity) => entity.remoteId).toList(growable: false);
  }
}
