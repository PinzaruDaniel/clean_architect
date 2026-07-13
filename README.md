# clean_architect

A configurable Dart CLI generator for Clean Architecture Flutter/Dart projects.

`clean_architect` generates boring, predictable architecture files that you can edit immediately. The generator does not try to hide your app behind runtime abstractions. The flexibility lives in `clean_architect.yaml`: paths, layer layout, state management, network client, local storage, model style, and dependency injection style.

## Install

```sh
dart pub global activate clean_architect
```

After global activation you can run the executable from any folder:

```sh
clean_architect init
clean_architect create architecture
clean_architect create auth
clean_architect create feature orders
```

## Empty Folder Usage

Use the global executable when generating into an empty folder:

```sh
mkdir my_app
cd my_app
clean_architect create architecture
```

Do not use `dart run clean_architect ...` in an empty folder. `dart run` needs a local `pubspec.yaml` before the CLI can start. Use `dart run clean_architect ...` only when developing this package from its own checkout or from another Dart project that already has a `pubspec.yaml`.

## Commands

```sh
clean_architect init
clean_architect doctor
clean_architect create architecture
clean_architect create base
clean_architect create auth
clean_architect create feature <name>
clean_architect create usecase <name> --feature <feature>
clean_architect create repository <feature>
clean_architect create remote-function <name> --feature <feature>
clean_architect create local-function <name> --feature <feature>
clean_architect create cached-function <name> --feature <feature>
```

Examples:

```sh
clean_architect init
clean_architect create architecture
clean_architect create feature orders
clean_architect create auth
clean_architect create usecase login --feature auth
clean_architect create repository auth
clean_architect create remote-function loadDetails --feature orders
clean_architect create local-function readDraft --feature orders
clean_architect create cached-function syncDetails --feature orders
clean_architect doctor
```

Useful flags:

```sh
clean_architect init --dry-run
clean_architect init --force

clean_architect create architecture --dry-run
clean_architect create auth --dry-run
clean_architect create auth --overwrite
clean_architect create auth --force
clean_architect create feature profile --skip-presentation

clean_architect create auth --state getx
clean_architect create auth --state none
clean_architect create auth --network dio
clean_architect create auth --network abstract
clean_architect create auth --storage secure_storage
clean_architect create auth --storage abstract
clean_architect create auth --di injectable
clean_architect create auth --dependency-injection manual
clean_architect create feature orders --use-either-failure
clean_architect create feature orders --no-use-either-failure
```

`--overwrite` and `--force` are required before existing generated files are replaced.

## Configuration File

Run:

```sh
clean_architect init
```

This creates `clean_architect.yaml`:

```yaml
clean_architect:
  structure: layered_packages # layered_packages or feature_first
  state_management: getx # getx or none
  network: dio # dio or abstract
  local_storage: secure_storage # secure_storage or abstract
  dependency_injection: manual # manual or injectable
  use_asset_generator: true
  use_either_failure: false
  models:
    use_freezed: true
    use_json_serializable: true
  paths:
    domain: domain/lib
    data: data/lib/features
    presentation: presentation/lib
    di: di/lib
```

### Configuration Reference

| Key | Values | Default | What it controls |
| --- | --- | --- | --- |
| `structure` | `layered_packages`, `feature_first` | `layered_packages` | How feature paths are resolved from the configured layer paths. |
| `state_management` | `getx`, `none` | `getx` | Presentation controller/page style. |
| `network` | `dio`, `abstract` | `dio` | Remote data source style and generated data dependencies. |
| `local_storage` | `secure_storage`, `abstract` | `secure_storage` | Local auth credential storage style. |
| `dependency_injection` | `manual`, `injectable` | `manual` | Manual DI builder files or injectable/get_it setup files and annotations. |
| `use_asset_generator` | `true`, `false` | `true` | Whether presentation gets `asset_generator_kit.yaml` and the asset generator dependency. |
| `use_either_failure` | `true`, `false` | `false` | Whether generated repositories, repository implementations, and use cases return `Future<Either<Failure, T>>`. |
| `models.use_freezed` | `true`, `false` | `true` | Whether entities/DTOs use Freezed. |
| `models.use_json_serializable` | `true`, `false` | `true` | Whether DTOs include JSON serialization parts/factories. |
| `paths.domain` | path | `domain/lib` | Domain layer feature root. |
| `paths.data` | path | `data/lib/features` | Data layer feature root. |
| `paths.presentation` | path | `presentation/lib` | Presentation layer root. |
| `paths.di` | path | `di/lib` | Dependency injection layer root. |

The config parser also recognizes `local_storage: shared_preferences`, but the current templates only generate concrete storage code for `secure_storage`; use `abstract` when you want to wire your own storage implementation.

CLI overrides are intentionally small and only affect the current command. They do not rewrite `clean_architect.yaml`.

## Generated Project Shape

The default architecture is a multi-package Flutter/Dart workspace shape:

```txt
my_app/
  domain/
    pubspec.yaml
    lib/
      features/
        base_feature/
          entities/
          repositories/
          usecases/

  data/
    pubspec.yaml
    lib/
      features/
        base_feature/
          remote/
            models/
          local/
            models/
          repositories/

  di/
    pubspec.yaml
    lib/

  presentation/
    pubspec.yaml
    analysis_options.yaml
    asset_generator_kit.yaml
    assets/
      images/
      icons/
    lib/
      main.dart
      widgets/
      pages/
      utils/
      controllers/
      constants/
```

Every layer gets its own `pubspec.yaml`:

- `domain` is a pure Dart package for entities, repository contracts, and use cases.
- `data` is a Dart/Flutter package for DTOs, API services, local sources, mappers, and repository implementations.
- `di` is a Dart package that connects `domain` and `data` dependencies.
- `presentation` is a runnable Flutter package with `main.dart`, Flutter dependencies, and UI folders.

After generation, run Flutter setup inside `presentation` when you want a complete Flutter platform project:

```sh
cd presentation
flutter create .
flutter pub get
```

Run `dart pub get` in the other layer packages as needed.

## Structure Modes

### Default Layered Packages

```yaml
clean_architect:
  structure: layered_packages
  paths:
    domain: domain/lib
    data: data/lib/features
    presentation: presentation/lib
    di: di/lib
```

`clean_architect create auth` creates:

```txt
domain/lib/features/auth/...
data/lib/features/auth/...
di/lib/auth_di.dart
presentation/lib/controllers/auth_controller.dart
presentation/lib/pages/login_page.dart
presentation/lib/widgets/login_view_item.dart
```

### Custom Layer Paths

You can point the layers to existing packages or app folders:

```yaml
clean_architect:
  structure: layered_packages
  paths:
    domain: packages/domain/lib/modules
    data: packages/data/lib/modules
    presentation: apps/customer_app/lib
    di: packages/di/lib
```

Then `clean_architect create feature profile` creates feature files under those configured roots.

### Feature First

`feature_first` is available for projects that still want feature-based grouping while keeping the same layer packages:

```yaml
clean_architect:
  structure: feature_first
  paths:
    domain: domain/lib
    data: data/lib/features
    presentation: presentation/lib
    di: di/lib
```

Current path resolution places domain files under `domain/lib/features/<feature>` and data files under `data/lib/features/<feature>`. Presentation files stay in shared presentation folders: `pages`, `controllers`, and `widgets`.

## `create architecture`

```sh
clean_architect create architecture
```

Generates the layer packages and default folders only. It does not generate auth code.

Default placeholder feature name:

```txt
domain/lib/features/base_feature
data/lib/features/base_feature
```

Use this when you want the clean architecture project skeleton first, then add features later.

## `create feature <name>`

```sh
clean_architect create feature orders
```

Generates a generic feature module.

Domain:

```txt
domain/lib/features/orders/entities/orders_entity.dart
domain/lib/features/orders/repositories/orders_repository.dart
domain/lib/features/orders/usecases/get_orders_list_use_case.dart
```

Data:

```txt
data/lib/features/orders/remote/models/orders_dto.dart
data/lib/features/orders/remote/orders_api_service.dart
data/lib/features/orders/local/models/.gitkeep
data/lib/features/orders/local/orders_local_data_source.dart
data/lib/features/orders/mappers/orders_mapper.dart
data/lib/features/orders/repositories/orders_repository_impl.dart
```

Presentation, unless `--skip-presentation` is used:

```txt
presentation/lib/controllers/orders_controller.dart
presentation/lib/pages/orders_page.dart
presentation/lib/widgets/orders_view_item.dart
```

The generic feature is intentionally minimal: entity, DTO, mapper, repository contract, repository implementation, list use case, local source, Retrofit API service, controller, page, and view item.

## `create auth`

```sh
clean_architect create auth
```

Generates a concrete auth starter feature.

Domain:

```txt
domain/lib/features/auth/entities/auth_token_entity.dart
domain/lib/features/auth/entities/auth_credentials_entity.dart
domain/lib/features/auth/repositories/auth_repository.dart
domain/lib/features/auth/usecases/login_use_case.dart
domain/lib/features/auth/usecases/logout_use_case.dart
domain/lib/features/auth/usecases/save_auth_credentials_use_case.dart
domain/lib/features/auth/usecases/get_auth_credentials_use_case.dart
domain/lib/features/auth/usecases/clear_auth_credentials_use_case.dart
```

Data:

```txt
data/lib/features/auth/remote/models/auth_token_dto.dart
data/lib/features/auth/remote/models/login_request_dto.dart
data/lib/features/auth/remote/auth_api_service.dart
data/lib/features/auth/local/models/.gitkeep
data/lib/features/auth/local/auth_local_data_source.dart
data/lib/features/auth/mappers/auth_token_mapper.dart
data/lib/features/auth/repositories/auth_repository_impl.dart
```

Presentation, unless `--skip-presentation` is used:

```txt
presentation/lib/controllers/auth_controller.dart
presentation/lib/pages/login_page.dart
presentation/lib/widgets/login_view_item.dart
```

The generated remote API service uses Dio + Retrofit style:

```dart
@lazySingleton
@RestApi(baseUrl: '')
abstract class AuthApiService {
  @factoryMethod
  factory AuthApiService(@Named("auth_dio") Dio dio) = _AuthApiService;

  @POST('/authorization/token/')
  Future<AuthTokenDto> login(@Body() Map<String, dynamic> body);
}
```

The generated auth controller uses `GetIt.instance.get<LoginUseCase>()`, and the GetX page registers the controller in `initState` with `Get.put(AuthController())`.

## Operation Commands

Operation commands add a new function to an existing feature. They generate the required entity/model/usecase support files and patch the existing source, repository, repository implementation, and controller files.

### Remote Function

```sh
clean_architect create remote-function loadDetails --feature orders
```

Aliases: `remote-function`, `remote-method`.

Adds:

```txt
domain/lib/features/orders/entities/load_details_entity.dart
domain/lib/features/orders/usecases/load_details_use_case.dart
data/lib/features/orders/remote/models/load_details_dto.dart
data/lib/features/orders/mappers/load_details_mapper.dart
```

Patches:

```txt
data/lib/features/orders/remote/orders_api_service.dart
domain/lib/features/orders/repositories/orders_repository.dart
data/lib/features/orders/repositories/orders_repository_impl.dart
presentation/lib/controllers/orders_controller.dart
```

### Local Function

```sh
clean_architect create local-function readDraft --feature orders
```

Aliases: `local-function`, `local-method`.

Adds:

```txt
domain/lib/features/orders/entities/read_draft_entity.dart
domain/lib/features/orders/usecases/read_draft_use_case.dart
data/lib/features/orders/local/boxes/read_draft_box.dart
data/lib/features/orders/mappers/read_draft_mapper.dart
```

Patches the local source, repository contract, repository implementation, and controller.

### Cached Function

```sh
clean_architect create cached-function syncDetails --feature orders
```

Aliases: `cached-function`, `cached-method`.

Adds remote and local support together:

```txt
domain/lib/features/orders/entities/sync_details_entity.dart
domain/lib/features/orders/usecases/sync_details_remote_use_case.dart
domain/lib/features/orders/usecases/sync_details_cache_use_case.dart
data/lib/features/orders/remote/models/sync_details_dto.dart
data/lib/features/orders/local/boxes/sync_details_box.dart
data/lib/features/orders/mappers/sync_details_mapper.dart
data/lib/features/orders/mappers/sync_details_box_mapper.dart
```

Patches remote source, local source, repository contract, repository implementation, and adds two controller functions: one for remote and one for cache.

## Dependency Injection Modes

### Manual

```yaml
dependency_injection: manual
```

Manual mode generates simple DI builder files, for example:

```txt
di/lib/auth_di.dart
di/lib/orders_di.dart
```

Use this when you want explicit constructors and simple dependency wiring you can edit by hand.

### Injectable

```yaml
dependency_injection: injectable
```

Injectable mode adds injectable/get_it dependencies and generates injector entry files:

```txt
domain/lib/injector.dart
data/lib/injector.dart
di/lib/di.dart
```

Generated classes receive injectable annotations where supported. After generation, run build runner in the generated packages that contain injectable/freezed/json_serializable code.

## Either / Failure Return Type

```yaml
use_either_failure: true
```

When enabled, generated repository contracts, repository implementations, and use cases use:

```dart
Future<Either<Failure, T>>
```

instead of:

```dart
Future<T>
```

The generator also creates `domain/lib/failures/failure.dart` where needed and adds `dartz` to generated layer pubspecs. You can override the value for one command with `--use-either-failure` or `--no-use-either-failure`.

## Model Modes

### Freezed + JSON Serializable

```yaml
models:
  use_freezed: true
  use_json_serializable: true
```

Entities and DTOs use Freezed. DTOs also include JSON serialization parts when JSON serialization is enabled.

Typical follow-up command in generated packages:

```sh
dart run build_runner build --delete-conflicting-outputs
```

### Plain Dart Fallback

```yaml
models:
  use_freezed: false
  use_json_serializable: false
```

Entities and DTOs are generated as simple Dart classes.

## State Management

### GetX

```yaml
state_management: getx
```

Presentation controllers extend `GetxController`, pages use `Get.put(...)`, `Get.find(...)`, and reactive values where needed.

### None

```yaml
state_management: none
```

Presentation files are generated without GetX page wiring. This is useful when you want to connect Bloc, Riverpod, Provider, or another state system manually.

## Network

### Dio

```yaml
network: dio
```

Generated remote services use Dio + Retrofit imports and annotations. The data package receives the relevant dependencies.

### Abstract

```yaml
network: abstract
```

Use this when you want the generated repositories and source boundaries but plan to implement networking yourself.

## Local Storage

### Secure Storage

```yaml
local_storage: secure_storage
```

Auth local source uses `flutter_secure_storage` for credential persistence.

### Abstract

```yaml
local_storage: abstract
```

Auth local source contains TODO methods so you can wire Hive, shared preferences, a database, encrypted storage, or another persistence mechanism yourself.

## Presentation Package

The generated presentation package includes:

```txt
presentation/lib/main.dart
presentation/lib/widgets/
presentation/lib/pages/
presentation/lib/utils/
presentation/lib/controllers/
presentation/lib/constants/
presentation/assets/images/
presentation/assets/icons/
```

When `use_asset_generator: true`, it also includes:

```txt
presentation/asset_generator_kit.yaml
```

and adds `assetgeneratorkit` to `presentation/pubspec.yaml`.

## Safety

By default, existing files are not overwritten.

Preview generated files:

```sh
clean_architect create auth --dry-run
```

Overwrite intentionally:

```sh
clean_architect create auth --overwrite
```

or:

```sh
clean_architect create auth --force
```

## Doctor

```sh
clean_architect doctor
```

`doctor` loads `clean_architect.yaml`, checks whether configured paths exist, and prints dependency reminders for selected options such as Dio, GetX, and secure storage.

## Publishing / Development Notes

When working on this package locally:

```sh
dart format lib test bin
dart analyze
dart test
dart pub publish --dry-run
```

Run `dart pub publish --dry-run` before publishing to verify pub.dev metadata and package contents.
