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
    expect(
        paths, contains('data/lib/features/auth/remote/auth_api_service.dart'));
    expect(paths, contains('presentation/lib/pages/login_page.dart'));
    expect(paths, contains('data/lib/features/auth/local/models/.gitkeep'));
    expect(paths, contains('di/lib/auth_di.dart'));

    final tokenEntity = files.singleWhere(
      (file) => file.path.endsWith('auth_token_entity.dart'),
    );
    expect(tokenEntity.content, contains('@freezed'));
    expect(tokenEntity.content,
        contains("part 'auth_token_entity.freezed.dart';"));

    final tokenDto = files.singleWhere(
      (file) => file.path.endsWith('auth_token_dto.dart'),
    );
    expect(tokenDto.content, contains('@freezed'));
    expect(tokenDto.content, contains("part 'auth_token_dto.g.dart';"));

    final apiService = files.singleWhere(
      (file) => file.path.endsWith('auth_api_service.dart'),
    );
    expect(apiService.content, contains('@RestApi(baseUrl:'));
    expect(apiService.content, contains("@POST('/authorization/token/')"));
    expect(apiService.content, contains('@Named("auth_dio") Dio dio'));

    final localDataSource = files.singleWhere(
      (file) => file.path.endsWith('auth_local_data_source.dart'),
    );
    expect(localDataSource.content,
        contains('abstract class AuthLocalDataSource'));
    expect(localDataSource.content,
        contains('@LazySingleton(as: AuthLocalDataSource)'));
    expect(
      localDataSource.content,
      contains('class AuthLocalDataSourceImpl implements AuthLocalDataSource'),
    );

    final authController = files.singleWhere(
      (file) =>
          file.path == 'presentation/lib/controllers/auth_controller.dart',
    );
    expect(
        authController.content, contains('GetIt.instance.get<LoginUseCase>()'));

    final loginPage = files.singleWhere(
      (file) => file.path == 'presentation/lib/pages/login_page.dart',
    );
    expect(loginPage.content, contains('void initState()'));
    expect(loginPage.content, contains('Get.put(AuthController())'));
    expect(loginPage.content, contains('Get.find<AuthController>()'));

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

  test('generic feature generates retrofit api service and freezed dto', () {
    const config = CleanArchitectConfig(
      structure: ProjectStructure.featureFirst,
      stateManagement: StateManagement.getx,
      network: NetworkClient.dio,
      localStorage: LocalStorage.abstract,
      dependencyInjection: DependencyInjection.manual,
      useAssetGenerator: true,
      models: ModelConfig(
        useFreezed: true,
        useJsonSerializable: true,
      ),
      paths: PathConfig(
        domain: 'domain/lib',
        data: 'data/lib/features',
        presentation: 'presentation/lib',
        di: 'di/lib',
      ),
    );

    final files = CleanArchitectGenerator(config).feature('profile');
    final apiService = files.singleWhere(
      (file) => file.path.endsWith('profile_api_service.dart'),
    );
    final dto = files.singleWhere(
      (file) => file.path.endsWith('profile_dto.dart'),
    );
    final page = files.singleWhere(
      (file) => file.path == 'presentation/lib/pages/profile_page.dart',
    );

    expect(apiService.content, contains('package:retrofit/retrofit.dart'));
    expect(apiService.content, contains("@GET('/profile')"));
    expect(dto.content, contains('@freezed'));
    expect(page.content, contains('Get.find<ProfileController>()'));
    expect(page.content, contains('controller.load();'));
  });
  test('injectable mode generates injector files and skips manual feature di',
      () {
    const config = CleanArchitectConfig(
      structure: ProjectStructure.layeredPackages,
      stateManagement: StateManagement.getx,
      network: NetworkClient.dio,
      localStorage: LocalStorage.secureStorage,
      dependencyInjection: DependencyInjection.injectable,
      useAssetGenerator: true,
      models: ModelConfig(
        useFreezed: true,
        useJsonSerializable: true,
      ),
      paths: PathConfig(
        domain: 'domain/lib',
        data: 'data/lib/features',
        presentation: 'presentation/lib',
        di: 'di/lib',
      ),
    );

    final files = CleanArchitectGenerator(config).auth();
    final paths = files.map((file) => file.path).toSet();

    expect(paths, contains('domain/lib/injector.dart'));
    expect(paths, contains('data/lib/injector.dart'));
    expect(paths, contains('di/lib/di.dart'));
    expect(paths, isNot(contains('di/lib/auth_di.dart')));

    final repository = files.singleWhere(
      (file) => file.path.endsWith('auth_repository_impl.dart'),
    );
    expect(repository.content, contains('@lazySingleton'));
  });
}
