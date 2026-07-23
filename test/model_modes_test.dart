import 'package:clean_architect/clean_architect.dart';
import 'package:test/test.dart';

void main() {
  test('Freezed-only models use manual JSON without JSON code generation', () {
    final generator = CleanArchitectGenerator(
      _config(useFreezed: true, useJsonSerializable: false),
    );
    final files = [
      ...generator.auth(),
      ...generator.feature('orders'),
      ...generator.operation(
        'loadDetails',
        feature: 'orders',
        kind: OperationKind.remote,
      ),
    ];

    final dtos = files.where((file) => file.path.endsWith('_dto.dart'));
    expect(dtos, isNotEmpty);
    for (final dto in dtos) {
      expect(dto.content, contains('.freezed.dart'));
      expect(dto.content, isNot(contains('.g.dart')));
      expect(dto.content, contains('fromJson(Map<String, dynamic> json)'));
      expect(dto.content, contains('Map<String, dynamic> toJson()'));
    }

    final dataPubspec = generator
        .feature('orders')
        .singleWhere((file) => file.path == 'data/pubspec.yaml')
        .content;
    expect(dataPubspec, contains('freezed:'));
    expect(dataPubspec, isNot(contains('json_annotation:')));
    expect(dataPubspec, isNot(contains('json_serializable:')));
  });

  test('JSON-only models use json_serializable without Freezed', () {
    final generator = CleanArchitectGenerator(
      _config(useFreezed: false, useJsonSerializable: true),
    );
    final files = [
      ...generator.auth(),
      ...generator.feature('orders'),
      ...generator.operation(
        'loadDetails',
        feature: 'orders',
        kind: OperationKind.remote,
      ),
    ];

    final dtos = files.where((file) => file.path.endsWith('_dto.dart'));
    expect(dtos, isNotEmpty);
    for (final dto in dtos) {
      expect(dto.content, contains('@JsonSerializable()'));
      expect(dto.content, contains('.g.dart'));
      expect(dto.content, isNot(contains('.freezed.dart')));
    }

    final dataPubspec = generator
        .feature('orders')
        .singleWhere((file) => file.path == 'data/pubspec.yaml')
        .content;
    expect(dataPubspec, contains('json_annotation:'));
    expect(dataPubspec, contains('json_serializable:'));
    expect(dataPubspec, isNot(contains('freezed:')));
  });
}

CleanArchitectConfig _config({
  required bool useFreezed,
  required bool useJsonSerializable,
}) {
  final defaults = CleanArchitectConfig.defaults();
  return CleanArchitectConfig(
    structure: defaults.structure,
    stateManagement: defaults.stateManagement,
    network: defaults.network,
    localStorage: defaults.localStorage,
    dependencyInjection: defaults.dependencyInjection,
    models: ModelConfig(
      useFreezed: useFreezed,
      useJsonSerializable: useJsonSerializable,
    ),
    paths: defaults.paths,
    useAssetGenerator: defaults.useAssetGenerator,
    useEitherFailure: defaults.useEitherFailure,
    flutter: defaults.flutter,
  );
}
