import 'dart:io';

import 'package:clean_architect/src/cli.dart';
import 'package:clean_architect/src/config.dart';
import 'package:clean_architect/src/generator.dart';
import 'package:clean_architect/src/templates/operation_templates.dart';
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
      paths,
      contains('domain/lib/features/base_feature/entities/.gitkeep'),
    );
    expect(
      paths,
      contains('domain/lib/features/base_feature/repositories/.gitkeep'),
    );
    expect(
      paths,
      contains('domain/lib/features/base_feature/usecases/.gitkeep'),
    );
    expect(
      paths,
      contains('data/lib/features/base_feature/remote/models/.gitkeep'),
    );
    expect(
      paths,
      contains('data/lib/features/base_feature/local/models/.gitkeep'),
    );
    expect(
      paths,
      contains('data/lib/features/base_feature/repositories/.gitkeep'),
    );
    expect(paths, contains('di/lib/.gitkeep'));
    expect(paths, isNot(contains('di/lib/auth_di.dart')));
    expect(
      paths,
      isNot(
        contains('domain/lib/features/auth/entities/auth_token_entity.dart'),
      ),
    );
  });

  test('generates auth module files', () {
    final files = CleanArchitectGenerator(
      CleanArchitectConfig.defaults(),
    ).auth();
    final paths = files.map((file) => file.path).toSet();

    expect(paths, contains('domain/pubspec.yaml'));
    expect(paths, contains('data/pubspec.yaml'));
    expect(paths, contains('di/pubspec.yaml'));
    expect(paths, contains('presentation/pubspec.yaml'));
    expect(paths, contains('presentation/lib/main.dart'));
    expect(
      paths,
      contains('domain/lib/features/auth/entities/auth_token_entity.dart'),
    );
    expect(
      paths,
      contains('domain/lib/features/auth/usecases/login_use_case.dart'),
    );
    expect(
      paths,
      contains('data/lib/features/auth/remote/auth_remote_data_source.dart'),
    );
    expect(paths, contains('presentation/lib/pages/login_page.dart'));
    expect(
      paths,
      isNot(contains('presentation/lib/widgets/login_view_item.dart')),
    );
    expect(
      paths,
      contains('data/lib/features/auth/local/models/auth_box.dart'),
    );
    expect(paths, contains('di/lib/auth_di.dart'));

    final tokenEntity = files.singleWhere(
      (file) => file.path.endsWith('auth_token_entity.dart'),
    );
    expect(tokenEntity.content, contains('@freezed'));
    expect(tokenEntity.content, contains('abstract class AuthTokenEntity'));
    expect(
      tokenEntity.content,
      contains("part 'auth_token_entity.freezed.dart';"),
    );

    final tokenDto = files.singleWhere(
      (file) => file.path.endsWith('auth_token_dto.dart'),
    );
    expect(tokenDto.content, contains('@freezed'));
    expect(tokenDto.content, contains('abstract class AuthTokenDto'));
    expect(tokenDto.content, contains("part 'auth_token_dto.g.dart';"));

    final remoteDataSource = files.singleWhere(
      (file) => file.path.endsWith('auth_remote_data_source.dart'),
    );
    expect(remoteDataSource.content, contains('@RestApi(baseUrl:'));
    expect(
      remoteDataSource.content,
      contains("@POST('/authorization/token/')"),
    );
    expect(
      remoteDataSource.content,
      contains('factory AuthRemoteDataSource(Dio dio)'),
    );
    expect(remoteDataSource.content, isNot(contains('package:injectable')));

    final authRemoteDataSource = remoteDataSource;
    expect(
      authRemoteDataSource.content,
      contains('abstract class AuthRemoteDataSource'),
    );

    final localDataSource = files.singleWhere(
      (file) => file.path.endsWith('auth_local_data_source.dart'),
    );
    expect(
      localDataSource.content,
      contains('abstract class AuthLocalDataSource'),
    );
    expect(
      localDataSource.content,
      contains('static Future<AuthLocalDataSource> init()'),
    );
    expect(
      localDataSource.content,
      contains('class AuthLocalDataSourceImpl implements AuthLocalDataSource'),
    );

    final authController = files.singleWhere(
      (file) =>
          file.path == 'presentation/lib/controllers/auth_controller.dart',
    );
    expect(
      authController.content,
      contains('GetIt.instance.get<LoginUseCase>()'),
    );
    expect(authController.content, contains('class LoginState'));
    expect(authController.content, isNot(contains('LoginViewItem')));

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

  test(
    'generic feature generates retrofit remote data source and freezed dto',
    () {
      const config = CleanArchitectConfig(
        structure: ProjectStructure.featureFirst,
        stateManagement: StateManagement.getx,
        network: NetworkClient.dio,
        localStorage: LocalStorage.abstract,
        dependencyInjection: DependencyInjection.manual,
        useAssetGenerator: true,
        useEitherFailure: false,
        flutter: FlutterConfig(
          createPresentation: false,
          platforms: ['android', 'ios'],
        ),
        models: ModelConfig(useFreezed: true, useJsonSerializable: true),
        paths: PathConfig(
          domain: 'domain/lib',
          data: 'data/lib/features',
          presentation: 'presentation/lib',
          di: 'di/lib',
        ),
      );

      final files = CleanArchitectGenerator(config).feature('profile');
      final remoteDataSource = files.singleWhere(
        (file) => file.path.endsWith('profile_remote_data_source.dart'),
      );
      final dto = files.singleWhere(
        (file) => file.path.endsWith('profile_dto.dart'),
      );
      final page = files.singleWhere(
        (file) =>
            file.path ==
            'presentation/lib/features/profile/pages/profile_page.dart',
      );

      expect(
        remoteDataSource.content,
        contains('package:retrofit/retrofit.dart'),
      );
      expect(remoteDataSource.content, contains("@GET('/profile')"));
      expect(dto.content, contains('@freezed'));
      expect(page.content, contains('Get.find<ProfileController>()'));
      expect(page.content, contains('controller.load();'));
    },
  );
  test(
    'injectable mode generates injector files and skips manual feature di',
    () {
      const config = CleanArchitectConfig(
        structure: ProjectStructure.layeredPackages,
        stateManagement: StateManagement.getx,
        network: NetworkClient.dio,
        localStorage: LocalStorage.secureStorage,
        dependencyInjection: DependencyInjection.injectable,
        useAssetGenerator: true,
        useEitherFailure: false,
        flutter: FlutterConfig(
          createPresentation: false,
          platforms: ['android', 'ios'],
        ),
        models: ModelConfig(useFreezed: true, useJsonSerializable: true),
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
      expect(
        repository.content,
        contains('@LazySingleton(as: AuthRepository)'),
      );

      final localDataSource = files.singleWhere(
        (file) => file.path.endsWith('auth_local_data_source.dart'),
      );
      expect(
        localDataSource.content,
        contains('@LazySingleton(as: AuthLocalDataSource)'),
      );
    },
  );
  test('remote operation generates dto entity mapper and either usecase', () {
    const config = CleanArchitectConfig(
      structure: ProjectStructure.layeredPackages,
      stateManagement: StateManagement.getx,
      network: NetworkClient.dio,
      localStorage: LocalStorage.secureStorage,
      dependencyInjection: DependencyInjection.manual,
      useAssetGenerator: true,
      useEitherFailure: true,
      flutter: FlutterConfig(
        createPresentation: false,
        platforms: ['android', 'ios'],
      ),
      models: ModelConfig(useFreezed: true, useJsonSerializable: true),
      paths: PathConfig(
        domain: 'domain/lib',
        data: 'data/lib/features',
        presentation: 'presentation/lib',
        di: 'di/lib',
      ),
    );

    final files = CleanArchitectGenerator(
      config,
    ).operation('loadDetails', feature: 'orders', kind: OperationKind.remote);
    final paths = files.map((file) => file.path).toSet();

    expect(paths, contains('domain/lib/failures/failure.dart'));
    expect(
      paths,
      contains('domain/lib/features/orders/entities/load_details_entity.dart'),
    );
    expect(
      paths,
      contains('data/lib/features/orders/remote/models/load_details_dto.dart'),
    );
    expect(
      paths,
      contains(
        'domain/lib/features/orders/usecases/load_details_use_case.dart',
      ),
    );

    final useCase = files.singleWhere(
      (file) => file.path.endsWith('load_details_use_case.dart'),
    );
    expect(
      useCase.content,
      contains('Future<Either<Failure, LoadDetailsEntity>> call()'),
    );
    expect(useCase.content, contains('package:domain/failures/failure.dart'));
  });

  test('feature templates use Either Failure when configured', () {
    const config = CleanArchitectConfig(
      structure: ProjectStructure.layeredPackages,
      stateManagement: StateManagement.getx,
      network: NetworkClient.dio,
      localStorage: LocalStorage.secureStorage,
      dependencyInjection: DependencyInjection.manual,
      useAssetGenerator: true,
      useEitherFailure: true,
      flutter: FlutterConfig(
        createPresentation: false,
        platforms: ['android', 'ios'],
      ),
      models: ModelConfig(useFreezed: true, useJsonSerializable: true),
      paths: PathConfig(
        domain: 'domain/lib',
        data: 'data/lib/features',
        presentation: 'presentation/lib',
        di: 'di/lib',
      ),
    );

    final files = CleanArchitectGenerator(config).feature('orders');
    final repository = files.singleWhere(
      (file) => file.path.endsWith('orders_repository.dart'),
    );
    final repositoryImpl = files.singleWhere(
      (file) => file.path.endsWith('orders_repository_impl.dart'),
    );
    final useCase = files.singleWhere(
      (file) => file.path.endsWith('get_orders_list_use_case.dart'),
    );
    final controller = files.singleWhere(
      (file) => file.path.endsWith('orders_controller.dart'),
    );

    expect(
      repository.content,
      contains('Future<Either<Failure, List<OrdersEntity>>>'),
    );
    expect(
      repository.content,
      contains('package:domain/failures/failure.dart'),
    );
    expect(repositoryImpl.content, contains('return right('));
    expect(
      repositoryImpl.content,
      contains('return left(Failure(error.toString()))'),
    );
    expect(
      useCase.content,
      contains('Future<Either<Failure, List<OrdersEntity>>> call()'),
    );
    expect(controller.content, contains('result.fold('));
    expect(controller.content, isNot(contains(');,')));
  });
  test('config parses flutter create presentation settings', () {
    final directory = Directory.systemTemp.createTempSync(
      'clean_architect_config_',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/clean_architect.yaml')
      ..writeAsStringSync('''
clean_architect:
  flutter:
    create_presentation: true
    platforms:
      - android
      - web
''');

    final config = CleanArchitectConfig.fromFile(file);

    expect(config.flutter.createPresentation, isTrue);
    expect(config.flutter.platforms, ['android', 'web']);
  });
  test('feature templates support bloc and provider state management', () {
    const basePaths = PathConfig(
      domain: 'domain/lib',
      data: 'data/lib/features',
      presentation: 'presentation/lib',
      di: 'di/lib',
    );

    const blocConfig = CleanArchitectConfig(
      structure: ProjectStructure.layeredPackages,
      stateManagement: StateManagement.bloc,
      network: NetworkClient.dio,
      localStorage: LocalStorage.secureStorage,
      dependencyInjection: DependencyInjection.manual,
      useAssetGenerator: true,
      useEitherFailure: false,
      flutter: FlutterConfig(
        createPresentation: false,
        platforms: ['android', 'ios'],
      ),
      models: ModelConfig(useFreezed: true, useJsonSerializable: true),
      paths: basePaths,
    );

    final blocFiles = CleanArchitectGenerator(blocConfig).feature('orders');
    final blocController = blocFiles.singleWhere(
      (file) =>
          file.path == 'presentation/lib/controllers/orders_controller.dart',
    );
    final blocPage = blocFiles.singleWhere(
      (file) => file.path == 'presentation/lib/pages/orders_page.dart',
    );
    final blocPubspec = blocFiles.singleWhere(
      (file) => file.path == 'presentation/pubspec.yaml',
    );

    expect(
      blocController.content,
      contains('extends Bloc<OrdersEvent, OrdersState>'),
    );
    expect(blocPage.content, contains('BlocProvider'));
    expect(
      blocPage.content,
      contains('class OrdersViewItem extends StatelessWidget'),
    );
    expect(
      blocFiles.map((file) => file.path),
      isNot(contains('presentation/lib/widgets/orders_view_item.dart')),
    );
    expect(blocPubspec.content, contains('flutter_bloc:'));

    const providerConfig = CleanArchitectConfig(
      structure: ProjectStructure.layeredPackages,
      stateManagement: StateManagement.provider,
      network: NetworkClient.dio,
      localStorage: LocalStorage.secureStorage,
      dependencyInjection: DependencyInjection.manual,
      useAssetGenerator: true,
      useEitherFailure: false,
      flutter: FlutterConfig(
        createPresentation: false,
        platforms: ['android', 'ios'],
      ),
      models: ModelConfig(useFreezed: true, useJsonSerializable: true),
      paths: basePaths,
    );

    final providerFiles = CleanArchitectGenerator(
      providerConfig,
    ).feature('orders');
    final providerController = providerFiles.singleWhere(
      (file) =>
          file.path == 'presentation/lib/controllers/orders_controller.dart',
    );
    final providerPage = providerFiles.singleWhere(
      (file) => file.path == 'presentation/lib/pages/orders_page.dart',
    );
    final providerPubspec = providerFiles.singleWhere(
      (file) => file.path == 'presentation/pubspec.yaml',
    );

    expect(providerController.content, contains('extends ChangeNotifier'));
    expect(providerPage.content, contains('ChangeNotifierProvider'));
    expect(
      providerPage.content,
      contains('class OrdersViewItem extends StatelessWidget'),
    );
    expect(providerPubspec.content, contains('provider:'));
  });

  test('hive and objectbox storage generate box models and data modules', () {
    const basePaths = PathConfig(
      domain: 'domain/lib',
      data: 'data/lib/features',
      presentation: 'presentation/lib',
      di: 'di/lib',
    );

    const hiveConfig = CleanArchitectConfig(
      structure: ProjectStructure.layeredPackages,
      stateManagement: StateManagement.getx,
      network: NetworkClient.dio,
      localStorage: LocalStorage.hive,
      dependencyInjection: DependencyInjection.injectable,
      useAssetGenerator: true,
      useEitherFailure: false,
      flutter: FlutterConfig(
        createPresentation: false,
        platforms: ['android', 'ios'],
      ),
      models: ModelConfig(useFreezed: true, useJsonSerializable: true),
      paths: basePaths,
    );

    final hiveFiles = CleanArchitectGenerator(hiveConfig).feature('orders');
    final hiveArchitectureFiles = CleanArchitectGenerator(
      hiveConfig,
    ).architecture();

    final hiveBox = hiveFiles.singleWhere(
      (file) =>
          file.path == 'data/lib/features/orders/local/models/orders_box.dart',
    );
    final hiveLocalSource = hiveFiles.singleWhere(
      (file) =>
          file.path ==
          'data/lib/features/orders/local/orders_local_data_source.dart',
    );
    final hivePubspec = hiveFiles.singleWhere(
      (file) => file.path == 'data/pubspec.yaml',
    );
    final hiveDataModule = hiveFiles.singleWhere(
      (file) => file.path == 'data/lib/data_module.dart',
    );
    final hiveDataInjector = hiveFiles.singleWhere(
      (file) => file.path == 'data/lib/injector.dart',
    );
    final hiveEntity = hiveFiles.singleWhere(
      (file) =>
          file.path == 'domain/lib/features/orders/entities/orders_entity.dart',
    );
    final hiveMapper = hiveFiles.singleWhere(
      (file) =>
          file.path == 'data/lib/features/orders/mappers/orders_mapper.dart',
    );

    expect(hiveBox.content, contains('int id'));
    expect(hiveBox.content, contains('@HiveField(1)'));
    expect(hiveBox.content, contains('String remoteId'));
    expect(hiveEntity.content, contains('required String remoteId'));
    expect(hiveMapper.content, contains('OrdersEntity(remoteId: id)'));
    expect(hiveMapper.content, contains('OrdersBox(remoteId: id)'));
    expect(hiveMapper.content, contains('OrdersEntity(remoteId: remoteId)'));
    expect(
      hiveArchitectureFiles.map((file) => file.path),
      isNot(contains('data/lib/data_module.dart')),
    );
    expect(hiveLocalSource.content, contains('Hive.openBox<OrdersBox>'));
    expect(hivePubspec.content, contains('hive_ce_flutter: ^2.3.4'));
    expect(hivePubspec.content, contains('hive_ce: ^2.19.3'));
    expect(hivePubspec.content, contains('hive_ce_generator: 1.11.1'));
    expect(hivePubspec.content, contains('build_runner: ^2.15.1'));
    expect(hivePubspec.content, contains('injectable_generator: ^3.0.2'));
    expect(hivePubspec.content, isNot(contains('flutter_secure_storage:')));
    expect(hiveDataModule.content, contains('await Hive.initFlutter();'));
    expect(hiveDataModule.content, contains('OrdersBoxAdapter()'));
    expect(hiveDataModule.content, isNot(contains('Future<void> initHive()')));
    expect(hiveDataInjector.content, contains('await get.init();'));
    expect(
      hiveFiles.map((file) => file.path),
      isNot(contains('data/lib/core/local_storage.dart')),
    );

    const objectBoxInjectableConfig = CleanArchitectConfig(
      structure: ProjectStructure.layeredPackages,
      stateManagement: StateManagement.getx,
      network: NetworkClient.dio,
      localStorage: LocalStorage.objectbox,
      dependencyInjection: DependencyInjection.injectable,
      useAssetGenerator: true,
      useEitherFailure: false,
      flutter: FlutterConfig(
        createPresentation: false,
        platforms: ['android', 'ios'],
      ),
      models: ModelConfig(useFreezed: true, useJsonSerializable: true),
      paths: basePaths,
    );

    final objectBoxFiles = CleanArchitectGenerator(
      objectBoxInjectableConfig,
    ).feature('orders');
    final objectBoxBox = objectBoxFiles.singleWhere(
      (file) =>
          file.path == 'data/lib/features/orders/local/models/orders_box.dart',
    );
    final dataModule = objectBoxFiles.singleWhere(
      (file) => file.path == 'data/lib/data_module.dart',
    );
    final objectBoxPubspec = objectBoxFiles.singleWhere(
      (file) => file.path == 'data/pubspec.yaml',
    );

    expect(objectBoxBox.content, contains('@Id()'));
    expect(objectBoxBox.content, contains('int id'));
    expect(objectBoxBox.content, contains('String remoteId'));
    expect(dataModule.content, contains('@module'));
    expect(dataModule.content, contains("@Named('auth_dio')"));
    expect(dataModule.content, contains("@Named('main_dio')"));
    expect(dataModule.content, contains('Future<Store> asyncCreateStore()'));
    expect(
      dataModule.content,
      contains('Box<OrdersBox> ordersBox(Store store)'),
    );
    expect(objectBoxPubspec.content, contains('objectbox_flutter_libs:'));
  });

  test('cli patches data module when adding another injectable feature', () {
    final directory = Directory.systemTemp.createTempSync(
      'clean_architect_cli_patch_',
    );
    final previousDirectory = Directory.current;
    addTearDown(() {
      Directory.current = previousDirectory;
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
      exitCode = 0;
    });

    Directory.current = directory;
    File(CleanArchitectConfig.fileName).writeAsStringSync('''
clean_architect:
  structure: layered_packages
  state_management: getx
  network: dio
  local_storage: hive
  dependency_injection: injectable
  use_asset_generator: true
  use_either_failure: false
  flutter:
    create_presentation: false
    platforms:
      - android
      - ios
  models:
    use_freezed: true
    use_json_serializable: true
  paths:
    domain: domain/lib
    data: data/lib/features
    presentation: presentation/lib
    di: di/lib
''');

    final cli = CleanArchitectCli();
    cli.run(['create', 'feature', 'orders', '--skip-presentation']);
    cli.run(['create', 'feature', 'auth', '--skip-presentation']);

    final dataModule = File('data/lib/data_module.dart').readAsStringSync();

    expect(
      dataModule,
      contains("import 'features/orders/local/models/orders_box.dart';"),
    );
    expect(
      dataModule,
      contains("import 'features/auth/local/models/auth_box.dart';"),
    );
    expect(dataModule, contains('Future<Box<OrdersBox>> ordersBox() async'));
    expect(dataModule, contains('Future<Box<AuthBox>> authBox() async'));
    expect(dataModule, contains('OrdersBoxAdapter()'));
    expect(dataModule, contains('AuthBoxAdapter()'));
    expect('Hive.initFlutter'.allMatches(dataModule), hasLength(2));
    expect(dataModule, isNot(contains('Future<void> initHive()')));
  });

  test('cached function uses sync remote and stream local method names', () {
    final directory = Directory.systemTemp.createTempSync(
      'clean_architect_cached_names_',
    );
    final previousDirectory = Directory.current;
    addTearDown(() {
      Directory.current = previousDirectory;
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
      exitCode = 0;
    });

    Directory.current = directory;
    File(CleanArchitectConfig.fileName).writeAsStringSync('''
clean_architect:
  structure: layered_packages
  state_management: getx
  network: dio
  local_storage: objectbox
  dependency_injection: injectable
  use_asset_generator: true
  use_either_failure: false
  flutter:
    create_presentation: false
    platforms:
      - android
      - ios
  models:
    use_freezed: true
    use_json_serializable: true
  paths:
    domain: domain/lib
    data: data/lib/features
    presentation: presentation/lib
    di: di/lib
''');

    final cli = CleanArchitectCli();
    cli.run(['create', 'feature', 'orders']);
    cli.run([
      'create',
      'cached-function',
      'syncDetails',
      '--feature',
      'orders',
    ]);

    final remoteSource = File(
      'data/lib/features/orders/remote/orders_remote_data_source.dart',
    ).readAsStringSync();
    final localSource = File(
      'data/lib/features/orders/local/orders_local_data_source.dart',
    ).readAsStringSync();
    final repository = File(
      'domain/lib/features/orders/repositories/orders_repository.dart',
    ).readAsStringSync();
    final repositoryImpl = File(
      'data/lib/features/orders/repositories/orders_repository_impl.dart',
    ).readAsStringSync();
    final controller = File(
      'presentation/lib/controllers/orders_controller.dart',
    ).readAsStringSync();
    final remoteUseCase = File(
      'domain/lib/features/orders/usecases/sync_details_use_case.dart',
    ).readAsStringSync();
    final cacheUseCase = File(
      'domain/lib/features/orders/usecases/stream_details_use_case.dart',
    ).readAsStringSync();

    final entity = File(
      'domain/lib/features/orders/entities/sync_details_entity.dart',
    ).readAsStringSync();
    final dto = File(
      'data/lib/features/orders/remote/models/sync_details_dto.dart',
    ).readAsStringSync();
    final box = File(
      'data/lib/features/orders/local/models/sync_details_box.dart',
    ).readAsStringSync();
    final remoteMapper = File(
      'data/lib/features/orders/mappers/sync_details_mapper.dart',
    ).readAsStringSync();
    final localMapper = File(
      'data/lib/features/orders/mappers/sync_details_box_mapper.dart',
    ).readAsStringSync();

    for (final content in [
      remoteSource,
      repository,
      repositoryImpl,
      controller,
    ]) {
      expect(content, contains('syncDetails()'));
    }
    for (final content in [
      localSource,
      repository,
      repositoryImpl,
      controller,
    ]) {
      expect(content, contains('streamDetails()'));
    }
    expect(localSource, contains('return SyncDetailsBox();'));
    expect(remoteUseCase, contains('_repository.syncDetails()'));
    expect(cacheUseCase, contains('_repository.streamDetails()'));
    expect(remoteUseCase, contains('class SyncDetailsUseCase'));
    expect(cacheUseCase, contains('class StreamDetailsUseCase'));
    expect(controller, contains('final _syncDetailsUseCase'));
    expect(controller, contains('final _streamDetailsUseCase'));
    expect(entity, contains('required String remoteId'));
    expect(dto, contains('required String id'));
    expect(box, contains('int id'));
    expect(box, contains('String remoteId'));
    expect(remoteMapper, contains('SyncDetailsEntity(remoteId: id)'));
    expect(remoteMapper, contains('SyncDetailsBox(remoteId: id)'));
    expect(localMapper, contains('SyncDetailsEntity(remoteId: remoteId)'));
    expect(repository, isNot(contains('syncDetailsRemote()')));
    expect(repository, isNot(contains('syncDetailsCache()')));
  });
}
