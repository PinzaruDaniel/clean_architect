class CatalogDto {
  const CatalogDto({
    required this.id,
  });

  factory CatalogDto.fromJson(Map<String, dynamic> json) {
    return CatalogDto(id: json['id'] as String);
  }

  final String id;

  Map<String, dynamic> toJson() {
    return {'id': id};
  }
}
