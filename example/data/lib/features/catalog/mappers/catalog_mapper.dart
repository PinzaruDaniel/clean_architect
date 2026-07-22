import 'package:domain/features/catalog/entities/catalog_entity.dart';
import '../local/models/catalog_box.dart';
import '../remote/models/catalog_dto.dart';

extension CatalogDtoMapper on CatalogDto {
  CatalogEntity toEntity() {
    return CatalogEntity(remoteId: id);
  }

  CatalogBox toBox() {
    return CatalogBox(remoteId: id);
  }
}

extension CatalogBoxMapper on CatalogBox {
  CatalogEntity toEntity() {
    return CatalogEntity(remoteId: remoteId);
  }
}
