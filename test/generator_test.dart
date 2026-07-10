import 'package:clean_architect/src/config.dart';
import 'package:clean_architect/src/generator.dart';
import 'package:test/test.dart';

void main() {
  test('generates default clean architecture folders only', () {
    final files = CleanArchitectGenerator(
      CleanArchitectConfig.defaults(),
    ).architecture();
    final paths = files.map((file) => file.path).toSet();

    expect(paths, contains('domain/pubspec.yaml'));
    expect(paths, contains('data/pubspec.yaml'));
    expect(paths, contains('di/pubspec.yaml'));
    expect(paths, contains('presentation/pubspec.yaml'));
    expect(paths, contains('presentation/lib/main.dart'));
    expect(
        paths, contains('domain/lib/features/base_feature/entities/.gitkeep'));
    expect(paths,
        contains('domain/lib/features/base_feature/repositories/.gitkeep'));
    expect(
        paths, contains('domain/lib/features/base_feature/usecases/.gitkeep'));
    expect(paths,
        contains('data/lib/features/base_feature/remote/models/.gitkeep'));
    expect(paths,
        contains('data/lib/features/base_feature/local/models/.gitkeep'));
    expect(paths,
        contains('data/lib/features/base_feature/repositories/.gitkeep'));
    expect(paths, contains('di/lib/.gitkeep'));
    expect(paths, isNot(contains('di/lib/auth_di.dart')));
    expect(
        paths,
        isNot(contains(
            'domain/lib/features/auth/entities/auth_token_entity.dart')));
  });

  test('generates auth module files', () {
    final files =
        CleanArchitectGenerator(CleanArchitectConfig.defaults()).auth();
    final paths = files.map((file) => file.path).toSet();

    expect(paths, contains('domain/pubspec.yaml'));
    expect(paths, contains('data/pubspec.yaml'));
    expect(paths, contains('di/pubspec.yaml'));
    expect(paths, contains('presentation/pubspec.yaml'));
    expect(paths, contains('presentation/lib/main.dart'));
    expect(paths,
        contains('domain/lib/features/auth/entities/auth_token_entity.dart'));
    expect(paths,
        contains('domain/lib/features/auth/usecases/login_use_case.dart'));
    expect(paths,
        contains('data/lib/features/auth/remote/auth_remote_data_source.dart'));
    expect(paths, contains('presentation/lib/pages/login_page.dart'));
    expect(paths, contains('data/lib/features/auth/local/models/.gitkeep'));
    expect(paths, contains('di/lib/auth_di.dart'));

    final presentationPubspec = files.singleWhere(
      (file) => file.path == 'presentation/pubspec.yaml',
    );
    expect(presentationPubspec.content, contains('flutter:'));
    expect(presentationPubspec.content, contains('path: ../domain'));
    expect(presentationPubspec.content, contains('path: ../data'));
    expect(presentationPubspec.content, contains('path: ../di'));
  });

  test('skips presentation files when requested', () {
    final files = CleanArchitectGenerator(
      CleanArchitectConfig.defaults(),
    ).feature('orders', skipPresentation: true);

    final paths = files.map((file) => file.path);

    expect(paths, contains('domain/pubspec.yaml'));
    expect(paths, contains('data/pubspec.yaml'));
    expect(paths, contains('di/pubspec.yaml'));
    expect(paths, isNot(contains('presentation/pubspec.yaml')));
    expect(paths, isNot(contains('presentation/lib/pages/orders_page.dart')));
  });

  test('generic feature uses configured network style', () {
    const config = CleanArchitectConfig(
      structure: ProjectStructure.featureFirst,
      stateManagement: StateManagement.none,
      network: NetworkClient.abstract,
      localStorage: LocalStorage.abstract,
      dependencyInjection: DependencyInjection.manual,
      models: ModelConfig(
        useFreezed: false,
        useJsonSerializable: false,
      ),
      paths: PathConfig(
        domain: 'domain/lib',
        data: 'data/lib/features',
        presentation: 'presentation/lib',
        di: 'di/lib',
      ),
    );

    final files = CleanArchitectGenerator(config).feature('profile');
    final remoteSource = files.singleWhere(
      (file) => file.path.endsWith('profile_remote_data_source.dart'),
    );

    expect(remoteSource.content, isNot(contains('package:dio/dio.dart')));
    expect(remoteSource.content, contains('TODO: Fetch profile items'));
  });
}
